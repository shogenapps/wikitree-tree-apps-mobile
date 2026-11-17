import Foundation

/// One person from the watchlist. `birth` and `death` are "YYYY-MM-DD" as WikiTree gives them, or "".
struct Relative: Identifiable, Equatable {
    let id: String
    let name: String
    let birth: String
    let dates: String
    /// When WikiTree last changed the profile, to spot what needs fetching again.
    var touched = ""
    /// Birthplace, shown with name suggestions.
    var place = ""
    var death = ""

    var birthYear: Int { Int(birth.prefix(4)) ?? 0 }
    var deathYear: Int { Int(death.prefix(4)) ?? 0 }
}

/// A birth or a death on the watchlist that falls on a given day of the year.
struct Anniversary: Identifiable, Equatable {
    enum Kind { case birth, death }
    let person: Relative
    let kind: Kind
    let year: Int

    var id: String { "\(kind == .birth ? "b" : "d")-\(person.id)" }

    /// Whole years since, counted from `day`'s year.
    func years(on day: Date = Date()) -> Int { Calendar.current.component(.year, from: day) - year }

    /// A round number of years (every 25th), worth picking out.
    func isMilestone(on day: Date = Date()) -> Bool { let y = years(on: day); return y > 0 && y % 25 == 0 }

    /// "born 1841 · 185 years ago" or "died 1902 · 124 years ago"
    func detail(on day: Date = Date()) -> String {
        let y = years(on: day)
        let event = kind == .birth ? String(localized: "born \(String(year))") : String(localized: "died \(String(year))")
        guard y > 0 else { return event }
        return event + " · " + String(localized: "\(y) years ago")
    }
}

/// The stored watchlist, shared by the app and its home-screen widget through an App Group.
/// It is a text file on the phone only: one person per line, tab-separated. Mirrors Watchlist.kt
/// on Android.
enum WatchlistFile {
    static let group = "group.org.wikitree.treeapps"
    private static let fetchedKey = "watchlistFetchedAt"

    static var defaults: UserDefaults { UserDefaults(suiteName: group) ?? .standard }

    /// The App Group folder, or the app's own folder if the group is not set up (the widget then
    /// has nothing to show, but the app still works).
    static var url: URL {
        let folder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("watchlist.tsv")
    }

    /// When the list was last fetched, or nil if never.
    static var fetchedAt: Date? {
        get { defaults.object(forKey: fetchedKey) as? Date }
        set { defaults.set(newValue, forKey: fetchedKey) }
    }

    static func read() -> [Relative] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard parts.count >= 4, !parts[0].isEmpty else { return nil }
            return Relative(id: String(parts[0]), name: String(parts[1]), birth: String(parts[2]), dates: String(parts[3]),
                            touched: parts.count > 4 ? String(parts[4]) : "", place: parts.count > 5 ? String(parts[5]) : "",
                            death: parts.count > 6 ? String(parts[6]) : "")
        }
    }

    static func write(_ people: [Relative]) throws {
        func clean(_ s: String) -> String { s.replacingOccurrences(of: "\t", with: " ").replacingOccurrences(of: "\n", with: " ") }
        let text = people.map { [$0.id, $0.name, $0.birth, $0.dates, $0.touched, $0.place, $0.death].map(clean).joined(separator: "\t") }
            .joined(separator: "\n")
        try text.write(to: url, atomically: true, encoding: .utf8)
        defaults.set(format, forKey: formatKey)
    }

    /// The file's layout. Version 2 added death dates; an older file is fetched again in full.
    private static let format = 2
    private static let formatKey = "watchlistFormat"
    static var isOldFormat: Bool { fetchedAt != nil && defaults.integer(forKey: formatKey) < format }

    static func clear() {
        try? FileManager.default.removeItem(at: url)
        fetchedAt = nil
    }

    /// Births and deaths that fall on `day`, oldest first, a birth before a death in the same year.
    static func anniversaries(on day: Date, among people: [Relative]) -> [Anniversary] {
        let parts = Calendar.current.dateComponents([.month, .day], from: day)
        let monthDay = String(format: "-%02d-%02d", parts.month ?? 0, parts.day ?? 0)
        func on(_ date: String) -> Bool { date.count == 10 && date.hasSuffix(monthDay) }
        var found: [Anniversary] = []
        for p in people {
            if on(p.birth), p.birthYear > 0 { found.append(Anniversary(person: p, kind: .birth, year: p.birthYear)) }
            if on(p.death), p.deathYear > 0 { found.append(Anniversary(person: p, kind: .death, year: p.deathYear)) }
        }
        return found.sorted { ($0.year, $0.kind == .birth ? 0 : 1) < ($1.year, $1.kind == .birth ? 0 : 1) }
    }

    /// The first `count` to show when not all fit: oldest first, but with at least one birth and
    /// one death when the day has both, so deaths are not all hidden behind "and N more".
    static func pick(_ list: [Anniversary], _ count: Int) -> [Anniversary] {
        guard count > 0, list.count > count else { return list }
        var shown = Array(list.prefix(count))
        for kind in [Anniversary.Kind.birth, .death] where !shown.contains(where: { $0.kind == kind }) {
            guard count > 1, let first = list.first(where: { $0.kind == kind }) else { continue }
            shown[count - 1] = first
        }
        return shown.sorted { ($0.year, $0.kind == .birth ? 0 : 1) < ($1.year, $1.kind == .birth ? 0 : 1) }
    }

    /// "9 today", short enough for the small widget.
    static func shortSummary(_ list: [Anniversary]) -> String { String(localized: "\(list.count) today") }

    /// "3 births · 2 deaths"
    static func summary(_ list: [Anniversary]) -> String {
        let births = list.filter { $0.kind == .birth }.count, deaths = list.count - births
        var parts: [String] = []
        if births > 0 { parts.append(String(localized: "\(births) births")) }
        if deaths > 0 { parts.append(String(localized: "\(deaths) deaths")) }
        return parts.joined(separator: " · ")
    }

    /// "November 15"
    static func dayLabel(_ day: Date) -> String {
        let format = DateFormatter()
        format.setLocalizedDateFormatFromTemplate("dMMMM")
        return format.string(from: day)
    }
}
