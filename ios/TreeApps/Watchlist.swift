import Foundation
import UserNotifications
import WebKit
import WidgetKit

/// The logged-in member's WikiTree watchlist. It feeds the Anniversaries list, widget and
/// notification, and the name suggestions while typing.
///
/// It is fetched with the WikiTree login already in the web view (its cookies), a page at a
/// time, and refreshed once a week or by hand; a refresh fetches only the people who have changed. Mirrors Watchlist.kt on Android.
@MainActor
final class WatchlistStore: ObservableObject {
    @Published private(set) var people: [Relative] = []
    @Published private(set) var fetchedAt: Date? = WatchlistFile.fetchedAt
    @Published private(set) var loading = false
    /// Why the last refresh did not work, if it did not.
    @Published private(set) var note: String?
    @Published private(set) var notify = UserDefaults.standard.bool(forKey: "birthdayNotify")

    private var lowered: [String] = []

    private nonisolated static let api = "https://www.wikitree.com/api.php"
    private nonisolated static let week: TimeInterval = 7 * 24 * 60 * 60
    private nonisolated static let fields = "Name,Touched,FirstName,RealName,LastNameAtBirth,LastNameCurrent,BirthDate,DeathDate,BirthLocation"
    private nonisolated static let indexPage = 5000
    private nonisolated static let page = 2000
    /// How many people one getPeople call is asked for.
    private nonisolated static let keys = 100
    /// With more changes than this, fetching the whole list again is quicker.
    private nonisolated static let maxChanged = 500
    private nonisolated static let maxPeople = 20_000
    private nonisolated static let pause: UInt64 = 1_500_000_000
    private nonisolated static let daysAhead = 30

    private enum Failure: Error { case loggedOut, failed }

    init() {
        // Read the stored list off the main thread, so the start screen does not wait for it.
        Task {
            let stored = await Task.detached { WatchlistFile.read() }.value
            self.set(stored)
            self.scheduleNotifications()
            // A list stored before death dates were kept is fetched again straight away, so the
            // widget and the start screen get deaths without waiting for the weekly refresh.
            if WatchlistFile.isOldFormat { self.refresh(quiet: true) }
        }
    }

    var isLoaded: Bool { fetchedAt != nil }
    var isStale: Bool {
        WatchlistFile.isOldFormat || (fetchedAt.map { Date().timeIntervalSince($0) > Self.week } ?? false)
    }
    var today: [Anniversary] { WatchlistFile.anniversaries(on: Date(), among: people) }

    private func set(_ list: [Relative]) {
        people = list
        lowered = list.map { $0.name.lowercased() }
    }

    /// People with a name word starting with every word typed, e.g. "geo bea" finds George Beacall.
    func suggest(_ text: String, limit: Int = 6) -> [Relative] {
        func words(_ s: String) -> [Substring] { s.split { $0.isWhitespace || $0 == "(" || $0 == ")" } }
        let typed = words(text.lowercased())
        guard !typed.isEmpty else { return [] }
        var found: [Relative] = []
        for (i, name) in lowered.enumerated() {
            let parts = words(name)
            if typed.allSatisfy({ t in parts.contains { $0.hasPrefix(t) } }) {
                found.append(people[i])
                if found.count == limit { break }
            }
        }
        return found
    }

    /// Fetch the whole watchlist again. `quiet` keeps a failure to itself (the weekly refresh).
    func refresh(quiet: Bool = false) {
        guard !loading else { return }
        loading = true
        note = nil
        Task {
            do {
                // The WikiTree login lives in the web view's cookies for the site, which also serves the API.
                // Just after launch the cookie store can answer empty until the web view is up, so
                // look a few times before taking it as logged out.
                var cookies: [HTTPCookie] = []
                for attempt in 0..<5 {
                    if attempt > 0 { try await Task.sleep(nanoseconds: 2_000_000_000) }
                    cookies = await WKWebsiteDataStore.default().httpCookieStore.allCookies()
                        .filter { "www.wikitree.com".hasSuffix($0.domain.trimmingCharacters(in: CharacterSet(charactersIn: "."))) }
                    if !cookies.isEmpty { break }
                }
                guard !cookies.isEmpty else { throw Failure.loggedOut }
                let header = HTTPCookie.requestHeaderFields(with: cookies)["Cookie"] ?? ""
                let list = try await Self.fetchAll(cookie: header, stored: people)
                try await Task.detached { try WatchlistFile.write(list) }.value
                WatchlistFile.fetchedAt = Date()
                fetchedAt = WatchlistFile.fetchedAt
                set(list)
            } catch {
                if !quiet {
                    note = (error as? Failure) == .loggedOut
                        ? "Log in to WikiTree in a Tree App first, then tap here to load your watchlist."
                        : "The watchlist could not be loaded. Check the connection and tap to try again."
                }
            }
            loading = false
            WidgetCenter.shared.reloadAllTimelines()
            scheduleNotifications()
        }
    }

    /// Bring the stored list up to date. First only IDs and last-changed times are fetched, a few
    /// thousand at a time; then details for just the people who are new or have changed. The
    /// first time, or when a great many have changed, the whole list is fetched with details.
    private nonisolated static func fetchAll(cookie: String, stored: [Relative]) async throws -> [Relative] {
        let session = URLSession(configuration: .ephemeral)
        let old = Dictionary(stored.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var order: [String] = []
        var touched: [String: String] = [:]
        var offset = 0
        while offset < maxPeople {
            let page = try await watchlistPage(session, cookie, fields: "Name,Touched", limit: indexPage, offset: offset)
            for p in page {
                guard let id = p["Name"] as? String, !id.isEmpty, touched[id] == nil else { continue }
                order.append(id)
                touched[id] = p["Touched"] as? String ?? ""
            }
            if page.count < indexPage { break }
            offset += indexPage
            try await Task.sleep(nanoseconds: pause) // the API limits how fast it may be called
        }
        // A list stored before death dates were kept is fetched again in full.
        let changed = WatchlistFile.isOldFormat ? order : order.filter { touched[$0]!.isEmpty || old[$0]?.touched != touched[$0] }
        var fresh: [String: Relative] = [:]
        if changed.count > maxChanged {
            offset = 0
            while offset < maxPeople {
                try await Task.sleep(nanoseconds: pause)
                let page = try await watchlistPage(session, cookie, fields: fields, limit: Self.page, offset: offset)
                for p in page { if let r = relative(p) { fresh[r.id] = r } }
                if page.count < Self.page { break }
                offset += Self.page
            }
        } else {
            for start in stride(from: 0, to: changed.count, by: keys) {
                try await Task.sleep(nanoseconds: pause)
                let ids = changed[start..<min(start + keys, changed.count)].joined(separator: ",")
                let json = try await call(session, cookie, [
                    URLQueryItem(name: "action", value: "getPeople"),
                    URLQueryItem(name: "fields", value: fields),
                    URLQueryItem(name: "keys", value: ids),
                ])
                guard let people = json["people"] as? [String: Any] else { throw Failure.failed }
                for case let p as [String: Any] in people.values { if let r = relative(p) { fresh[r.id] = r } }
            }
        }
        // People no longer on the watchlist drop out; unchanged ones keep what was stored.
        return order.compactMap { fresh[$0] ?? old[$0] }
    }

    /// One page of the watchlist.
    private nonisolated static func watchlistPage(_ session: URLSession, _ cookie: String, fields: String,
                                                  limit: Int, offset: Int) async throws -> [[String: Any]] {
        let json = try await call(session, cookie, [
            URLQueryItem(name: "action", value: "getWatchlist"),
            URLQueryItem(name: "getPerson", value: "1"),
            URLQueryItem(name: "getSpace", value: "0"),
            URLQueryItem(name: "fields", value: fields),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
        ])
        // Without a login the API answers with a status and no list, or an empty list and
        // a count of false rather than a number.
        guard let list = json["watchlist"] as? [[String: Any]] else {
            throw offset == 0 ? Failure.loggedOut : Failure.failed
        }
        if offset == 0, list.isEmpty, (json["watchlistCount"] as? Bool) == false { throw Failure.loggedOut }
        return list
    }

    private nonisolated static func call(_ session: URLSession, _ cookie: String,
                                         _ items: [URLQueryItem]) async throws -> [String: Any] {
        var parts = URLComponents(string: api)!
        parts.queryItems = [URLQueryItem(name: "appId", value: "TreeAppsMobile")] + items
        var request = URLRequest(url: parts.url!)
        request.httpShouldHandleCookies = false
        request.setValue(cookie, forHTTPHeaderField: "Cookie")
        request.timeoutInterval = 60
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let json = (try JSONSerialization.jsonObject(with: data) as? [[String: Any]])?.first
        else { throw Failure.failed }
        return json
    }

    private nonisolated static func relative(_ p: [String: Any]) -> Relative? {
        guard let id = p["Name"] as? String, !id.isEmpty, let found = PeopleStore.describe(p) else { return nil }
        let birth = p["BirthDate"] as? String ?? "", death = p["DeathDate"] as? String ?? ""
        return Relative(id: id, name: found.name, birth: birth.count == 10 ? birth : "", dates: found.dates,
                        touched: p["Touched"] as? String ?? "", place: p["BirthLocation"] as? String ?? "",
                        death: death.count == 10 ? death : "")
    }

    /// Forget the list, e.g. after logging out.
    func clear() {
        WatchlistFile.clear()
        fetchedAt = nil
        note = nil
        set([])
        WidgetCenter.shared.reloadAllTimelines()
        scheduleNotifications()
    }

    // MARK: Daily notification

    /// Turn the morning notification on (asking for permission the first time) or off.
    func setNotify(_ on: Bool) {
        guard on else { return store(false) }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { granted, _ in
            Task { @MainActor in
                self.store(granted)
                if !granted { self.note = "Notifications are switched off for Tree Apps in the Settings app." }
            }
        }
    }

    private func store(_ on: Bool) {
        notify = on
        UserDefaults.standard.set(on, forKey: "birthdayNotify")
        scheduleNotifications()
    }

    /// The phone delivers these itself, so the mornings ahead are lined up from the stored list
    /// each time the app is opened: one notification at 08:00 on each day that has an anniversary.
    private func scheduleNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard notify, !people.isEmpty else { return }
        let calendar = Calendar.current
        let now = Date()
        for ahead in 0..<Self.daysAhead {
            guard let day = calendar.date(byAdding: .day, value: ahead, to: now) else { continue }
            var at = calendar.dateComponents([.year, .month, .day], from: day)
            at.hour = 8
            guard let when = calendar.date(from: at), when > now else { continue }
            let list = WatchlistFile.anniversaries(on: day, among: people)
            guard !list.isEmpty else { continue }
            let content = UNMutableNotificationContent()
            content.title = "Anniversaries: \(WatchlistFile.summary(list))"
            let names = list.prefix(3).map { "\($0.person.name) (\($0.kind == .birth ? "b." : "d.") \($0.year))" }
                .joined(separator: ", ")
            content.body = list.count > 3 ? "\(names) and \(list.count - 3) more" : names
            center.add(UNNotificationRequest(
                identifier: "birthdays-\(at.year ?? 0)-\(at.month ?? 0)-\(at.day ?? 0)", content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: at, repeats: false)))
        }
    }
}
