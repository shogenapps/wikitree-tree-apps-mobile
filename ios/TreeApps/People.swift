import SwiftUI
import UIKit
import WebKit

/// One person in the saved or recent list. `view` is the Tree App they were last shown in.
struct Person: Codable, Identifiable, Equatable {
    var id: String
    var name = ""
    var dates = ""
    var view = ""
    var time = Date()
    /// Set on search matches only: why WikiTree counts this person as notable.
    var notable: Notable? = nil

    func isSame(_ other: String) -> Bool { id.caseInsensitiveCompare(other) == .orderedSame }
}

/// A notable person: a "... Notables" category, a Notables Sticker or a Notability template.
/// `tag` is a short line such as "Shropshire Notables" or "Entertainment · California";
/// `about` is the Notability template's text, if it has one.
struct Notable: Codable, Equatable {
    var tag: String
    var about: String
    /// For ordering: 2 with a Notability template or a Notables category, 1 with a sticker only.
    var rank = 1

    /// Read from a searchPerson match fetched with Categories and Templates. A template's params
    /// come back as an object, or as an empty array when it has none.
    static func from(_ p: [String: Any]) -> Notable? {
        let categories = (p["Categories"] as? [String] ?? [])
            .map { $0.replacingOccurrences(of: "_", with: " ") }
            .filter { $0.hasSuffix(" Notables") || $0 == "Notables" }
        let templates = p["Templates"] as? [[String: Any]] ?? []
        func params(_ name: String) -> [String: String]? {
            guard let t = templates.first(where: { ($0["name"] as? String)?.caseInsensitiveCompare(name) == .orderedSame })
            else { return nil }
            return (t["params"] as? [String: Any] ?? [:]).compactMapValues { $0 as? String }
        }
        let notability = params("Notability")
        let sticker = params("Notables Sticker") ?? params("Notables")
        guard !categories.isEmpty || notability != nil || sticker != nil else { return nil }
        let about = plain(notability?["text"] ?? "")
        let theme = [notability?["theme"], notability?["location"]]
            .compactMap { $0.map(plain) }.filter { !$0.isEmpty }
        // The sticker's first unnamed param is the category it shows, e.g. "England, Notables".
        let stickerTag = sticker?.first(where: { $0.value.isEmpty && $0.key.hasSuffix("Notables") })?.key
        // Local categories ("Shropshire Notables") say more than country ones ("England, Notables",
        // with a comma), so they go first.
        let named = Array(Set(categories + [stickerTag].compactMap { $0 }))
            .sorted { ($0.contains(",") ? 1 : 0, $0) < ($1.contains(",") ? 1 : 0, $1) }
            .map { $0.replacingOccurrences(of: ",", with: "") }
        let tag = !theme.isEmpty ? theme.joined(separator: " · ")
            : named.isEmpty ? String(localized: "Notable") : named.prefix(2).joined(separator: ", ")
        return Notable(tag: tag, about: about, rank: notability != nil || !categories.isEmpty ? 2 : 1)
    }

    /// Wiki text to plain text: links keep their label, bold/italic quotes and templates go.
    static func plain(_ wiki: String) -> String {
        var s = wiki
        for (pattern, with) in [(#"\[\[[^\]|]*\|([^\]]*)\]\]"#, "$1"), (#"\[\[([^\]]*)\]\]"#, "$1"),
                                (#"\[https?://\S+ ([^\]]*)\]"#, "$1"), (#"\{\{[^}]*\}\}"#, ""),
                                (#"<[^>]+>"#, ""), (#"'{2,}"#, ""), (#"\s+"#, " ")] {
            s = s.replacingOccurrences(of: pattern, with: with, options: .regularExpression)
        }
        for (entity, char) in [("&quot;", "\""), ("&#34;", "\""), ("&#39;", "'"), ("&apos;", "'"),
                               ("&lt;", "<"), ("&gt;", ">"), ("&nbsp;", " "), ("&amp;", "&")] {
            s = s.replacingOccurrences(of: entity, with: char)
        }
        return s.trimmingCharacters(in: .whitespaces)
    }
}

/// Saved (starred) and recently viewed people, kept on the phone only. Names and dates come from
/// the public WikiTree API, looked up once per person and cached. Mirrors People.kt on Android.
final class PeopleStore: ObservableObject {
    @Published private(set) var saved: [Person]
    @Published private(set) var recent: [Person]
    /// The member logged in to WikiTree in the app, read from the site's login cookie.
    @Published private(set) var me: Person?
    /// Whether `findMe` has looked yet: until then, nobody logged in means "not known yet".
    @Published private(set) var meChecked = false

    private let defaults = UserDefaults.standard
    private var looking = Set<String>()
    private static let maxRecent = 25

    init() {
        saved = Self.read("peopleSaved")
        recent = Self.read("peopleRecent")
        updateShortcuts()
    }

    func isSaved(_ id: String) -> Bool { saved.contains { $0.isSame(id) } }

    /// Find who is logged in from WikiTree's cookies (shared with the web view): the member's ID
    /// from the Tree Apps login (WikiTreeAPI_userName) or the site's remember-me cookie, and a site
    /// session (wikitree_wtb__session) beside it. With no site session, profiles would show
    /// logged out, so nobody is shown and the start screen offers to log in.
    /// `afterLogin`: just after the login sheet closes. On a slow connection the Tree Apps part of
    /// the login can still be finishing then, and the cookie with the member's ID arrives a few
    /// seconds later; with a site session already there, keep looking for it for up to 20 seconds.
    func findMe(afterLogin: Bool = false) {
        Task { @MainActor in
            var cookies: [HTTPCookie] = []
            var site = false
            var id = ""
            for attempt in 0..<(afterLogin ? 20 : 5) {
                cookies = await WKWebsiteDataStore.default().httpCookieStore.allCookies()
                let wikitree = cookies.filter { $0.domain.hasSuffix("wikitree.com") && !$0.value.isEmpty }
                site = wikitree.contains { $0.name.hasSuffix("wtb__session") || $0.name.hasSuffix("wtb_UserName") }
                id = (site ? wikitree.first { $0.name == "WikiTreeAPI_userName" || $0.name.hasSuffix("wtb_UserName") } : nil)?
                    .value.removingPercentEncoding?.replacingOccurrences(of: " ", with: "_") ?? ""
                // Just after launch the cookie store can answer empty for a moment.
                let waiting = cookies.isEmpty || (afterLogin && site && id.isEmpty)
                if !waiting || attempt == (afterLogin ? 19 : 4) { break }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            meChecked = true
            guard id.range(of: #"^\S+-\d+$"#, options: .regularExpression) != nil else {
                me = nil
                return
            }
            if me?.isSame(id) != true { me = Person(id: id, name: cachedName(id), dates: cachedDates(id)) }
            lookUp(id)
        }
    }

    /// Note that `id` was shown in Tree App `view`.
    func visit(_ id: String, view: String) {
        guard !id.isEmpty, !view.isEmpty else { return }
        let index = recent.firstIndex { $0.isSame(id) }
        if index == 0, recent[0].view == view { return }
        var person = index.map { recent.remove(at: $0) } ?? Person(id: id, name: cachedName(id), dates: cachedDates(id))
        person.view = view
        person.time = Date()
        recent.insert(person, at: 0)
        recent = Array(recent.prefix(Self.maxRecent))
        // Keep a saved person's last app current too, so tapping them reopens where they were.
        if let i = saved.firstIndex(where: { $0.isSame(id) }) { saved[i].view = view }
        persist()
        lookUp(id)
    }

    func toggleSaved(_ id: String, view: String) {
        if let i = saved.firstIndex(where: { $0.isSame(id) }) {
            saved.remove(at: i)
        } else {
            saved.insert(Person(id: id, name: cachedName(id), dates: cachedDates(id), view: view), at: 0)
            lookUp(id)
        }
        persist()
    }

    func removeSaved(at offsets: IndexSet) {
        saved.remove(atOffsets: offsets)
        persist()
    }

    func removeRecent(_ id: String) {
        recent.removeAll { $0.isSame(id) }
        persist()
    }

    func clearRecent() {
        recent = []
        persist()
    }

    /// The Tree Apps used most recently, newest first, from the apps the recent people were shown in.
    func recentApps(_ limit: Int = 3) -> [String] {
        var seen = Set<String>()
        return Array(recent.map(\.view).filter { !$0.isEmpty && seen.insert($0).inserted }.prefix(limit))
    }

    // MARK: Storage

    private static func read(_ key: String) -> [Person] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([Person].self, from: data)) ?? []
    }

    private func persist() {
        defaults.set(try? JSONEncoder().encode(saved), forKey: "peopleSaved")
        defaults.set(try? JSONEncoder().encode(recent), forKey: "peopleRecent")
        updateShortcuts()
    }

    // MARK: Home-screen shortcuts

    /// Long-press shortcuts on the app icon: saved people first, then recent ones, each opening in
    /// the Tree App they were last shown in, plus one to change person.
    private func updateShortcuts() {
        var seen = Set<String>()
        let picks = (saved + recent).filter { seen.insert($0.id.lowercased()).inserted }.prefix(3)
        var items = picks.map { p in
            UIApplicationShortcutItem(
                type: QuickAction.person,
                localizedTitle: p.name.isEmpty ? p.id : p.name,
                localizedSubtitle: p.name.isEmpty ? nil : p.id,
                icon: UIApplicationShortcutIcon(systemImageName: "person.fill"),
                userInfo: ["id": p.id as NSString, "view": p.view as NSString])
        }
        items.append(UIApplicationShortcutItem(
            type: QuickAction.people, localizedTitle: String(localized: "Change person"), localizedSubtitle: nil,
            icon: UIApplicationShortcutIcon(systemImageName: "magnifyingglass"), userInfo: nil))
        UIApplication.shared.shortcutItems = items
    }

    // MARK: Names from the WikiTree API

    private func cachedName(_ id: String) -> String { defaults.string(forKey: "name_" + id) ?? "" }
    private func cachedDates(_ id: String) -> String { defaults.string(forKey: "dates_" + id) ?? "" }

    /// Fetch the person's name and years once. Private profiles may not say.
    private func lookUp(_ id: String) {
        guard defaults.object(forKey: "name_" + id) == nil, looking.insert(id).inserted else { return }
        var parts = URLComponents(string: "https://api.wikitree.com/api.php")!
        parts.queryItems = [
            URLQueryItem(name: "action", value: "getProfile"),
            URLQueryItem(name: "appId", value: "TreeAppsMobile"),
            URLQueryItem(name: "fields", value: "Name,FirstName,RealName,LastNameAtBirth,LastNameCurrent,BirthDate,DeathDate,BirthDecade,DeathDecade"),
            URLQueryItem(name: "key", value: id),
        ]
        guard let url = parts.url else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            let found = data.flatMap(Self.describe)
            DispatchQueue.main.async {
                guard let self else { return }
                self.looking.remove(id)
                guard let found else { return }
                self.defaults.set(found.name, forKey: "name_" + id)
                self.defaults.set(found.dates, forKey: "dates_" + id)
                for i in self.saved.indices where self.saved[i].isSame(id) {
                    self.saved[i].name = found.name
                    self.saved[i].dates = found.dates
                }
                if self.me?.isSame(id) == true {
                    self.me?.name = found.name
                    self.me?.dates = found.dates
                }
                for i in self.recent.indices where self.recent[i].isSame(id) {
                    self.recent[i].name = found.name
                    self.recent[i].dates = found.dates
                }
                self.persist()
            }
        }.resume()
    }

    static let searchLimit = 10
    /// Matches fetched per search: notables among them are all shown, the rest only up to `searchLimit`.
    static let searchFetch = 50

    /// Search WikiTree by name, with birth and death years and places if given (see NameSearch):
    /// the last word of the name is the last name, anything before it the first name. `done` gets the people (their dates include the birthplace) and the total number of
    /// matches, or nil if the search failed. Notable people among the first `searchFetch` matches
    /// come first, then up to `searchLimit` others, each in WikiTree's order. Categories and
    /// Templates come in the same call to tell notables apart.
    func search(_ text: String, done: @escaping ([Person]?, Int) -> Void) {
        let query = NameSearch(text)
        var parts = URLComponents(string: "https://api.wikitree.com/api.php")!
        parts.queryItems = [
            URLQueryItem(name: "action", value: "searchPerson"),
            URLQueryItem(name: "appId", value: "TreeAppsMobile"),
            URLQueryItem(name: "fields", value: "Name,FirstName,RealName,LastNameAtBirth,LastNameCurrent,BirthDate,DeathDate,BirthLocation,Categories,Templates"),
            URLQueryItem(name: "limit", value: String(Self.searchFetch)),
            URLQueryItem(name: "LastName", value: query.last),
            URLQueryItem(name: "FirstName", value: query.first),
        ] + query.queryItems
        guard let url = parts.url else { return done(nil, 0) }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            var people: [Person]?
            var total = 0
            if let data, let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               let result = list.first {
                total = result["total"] as? Int ?? 0
                people = (result["matches"] as? [[String: Any]] ?? []).compactMap { p in
                    guard let id = p["Name"] as? String, !id.isEmpty, let found = Self.describe(p) else { return nil }
                    let detail = [found.dates, p["BirthLocation"] as? String ?? ""].filter { !$0.isEmpty }
                    return Person(id: id, name: found.name, dates: detail.joined(separator: "  ·  "),
                                  notable: Notable.from(p))
                }
                people = people.map { list in
                    let notables = list.filter { $0.notable != nil }
                    // Stable: within each rank WikiTree's own order stands.
                    let ranked = notables.enumerated().sorted { a, b in
                        a.element.notable!.rank != b.element.notable!.rank
                            ? a.element.notable!.rank > b.element.notable!.rank : a.offset < b.offset
                    }.map(\.element)
                    return ranked + list.filter { $0.notable == nil }.prefix(Self.searchLimit)
                }
            }
            DispatchQueue.main.async { done(people, total) }
        }.resume()
    }

    /// "Donald Cameron" and "1841–1878" from a getProfile result.
    private static func describe(_ data: Data) -> (name: String, dates: String)? {
        guard let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let p = list.first?["profile"] as? [String: Any] else { return nil }
        return describe(p)
    }

    static func describe(_ p: [String: Any]) -> (name: String, dates: String)? {
        func text(_ key: String) -> String { p[key] as? String ?? "" }
        let first = text("RealName").isEmpty ? text("FirstName") : text("RealName")
        let birthName = text("LastNameAtBirth"), current = text("LastNameCurrent")
        let last = !current.isEmpty && !birthName.isEmpty && current != birthName
            ? "(\(birthName)) \(current)" : (birthName.isEmpty ? current : birthName)
        let name = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }
        func year(_ date: String, _ decade: String) -> String {
            let y = String(text(date).prefix(4))
            if y.count == 4, y != "0000" { return y }
            let d = text(decade)
            return d == "unknown" ? "" : d
        }
        let born = year("BirthDate", "BirthDecade"), died = year("DeathDate", "DeathDecade")
        return (name, born.isEmpty && died.isEmpty ? "" : "\(born)–\(died)")
    }
}

/// Home-screen quick actions (long-press the app icon). The scene delegate stores the chosen one
/// here and ContentView acts on it, whether the app was running or not.
enum QuickAction {
    static let person = "org.wikitree.treeapps.person"
    static let people = "org.wikitree.treeapps.people"
    static let chosen = Notification.Name("QuickActionChosen")
    static var pending: UIApplicationShortcutItem? {
        didSet { if pending != nil { NotificationCenter.default.post(name: chosen, object: nil) } }
    }
    /// A wikitree.com link tapped in another app (a universal link), waiting to be opened.
    static var pendingLink: URL? {
        didSet { if pendingLink != nil { NotificationCenter.default.post(name: chosen, object: nil) } }
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        if let item = options.shortcutItem { QuickAction.pending = item }
        if let link = options.userActivities.compactMap(Self.link).first { QuickAction.pendingLink = link }
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        if let link = Self.link(userActivity) { QuickAction.pendingLink = link }
    }

    private static func link(_ activity: NSUserActivity) -> URL? {
        activity.activityType == NSUserActivityTypeBrowsingWeb ? activity.webpageURL : nil
    }

    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        QuickAction.pending = shortcutItem
        completionHandler(true)
    }
}

/// The People screen: type a WikiTree ID, or pick a saved or recent person. Tap the star to save
/// or unsave, swipe a row to remove it.
///
/// With `start` set it is the start screen shown when the app is opened afresh: it adds the
/// member who is logged in, anniversaries and the list of Tree Apps, and has no Done. Its sections fold
/// away under their headings, and stay as they were left.
struct PeopleView: View {
    struct Start {
        let apps: [(key: String, title: String)]
        let onApp: (String) -> Void
    }

    @ObservedObject var store: PeopleStore
    /// The member's watchlist, for anniversaries and name suggestions.
    @ObservedObject var watchlist: WatchlistStore
    let currentId: String
    let currentView: String
    let appTitle: (String) -> String?
    let onPick: (String, String) -> Void
    /// Every Tree App, for the long-press menu's "Open in" items.
    var apps: [(key: String, title: String)] = []
    var start: Start?

    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @State private var genieQuestion = ""
    @State private var matches: [Person] = []
    @State private var searchNote: String?
    @State private var searchRun = 0
    @State private var suggestions: [Relative] = []
    @StateObject private var voice = VoiceListener()
    @State private var allBirthdays = false
    /// A profile on www.wikitree.com, shown in a sheet with the member's WikiTree login.
    @State private var profile: ShellModel.SheetURL?
    @State private var loggingIn = false
    // Which start-screen sections are open. Anniversaries start folded: few people want them every time.
    @AppStorage("openMe") private var openMe = true
    @AppStorage("openBorn") private var openBorn = false
    @AppStorage("openSaved") private var openSaved = true
    @AppStorage("openRecent") private var openRecent = true
    @AppStorage("openApps") private var openApps = true
    /// Whom the start screen's Tree Apps list is for: the last person shown, else the member.
    private var appsFor: String { currentId.isEmpty ? store.me?.id ?? "" : currentId }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("Name or WikiTree ID", text: $draft)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                            .onSubmit(go)
                        VoiceButton(listener: voice, start: listen)
                        Button("Find", action: go)
                            .buttonStyle(.borderedProminent)
                            .tint(wtButton)
                            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    if voice.listening {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(voice.heard.isEmpty ? String(localized: "Listening… say a name, such as “John Smith, born 1850 in Yorkshire”.") : voice.heard)
                                .foregroundStyle(voice.heard.isEmpty ? .secondary : .primary)
                            Text("\(VoiceLanguage.currentTitle). Touch and hold the microphone to change it.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } else if let note = voice.note {
                        Text(note).font(.footnote).foregroundStyle(.secondary)
                    }
                    if start != nil, Wbe.shared.isEnabled {
                        // Genie, WBE's assistant: a question, or a search in Genie's own words.
                        HStack {
                            Text("🧞").font(.title2).accessibilityHidden(true)
                            TextField("Ask Genie anything", text: $genieQuestion)
                                .submitLabel(.send)
                                .onSubmit(askGenie)
                            Button("Ask", action: askGenie)
                                .buttonStyle(.borderedProminent)
                                .tint(wtButton)
                                .accessibilityLabel("Ask Genie, the WikiTree Browser Extension's assistant")
                        }
                    }
                    if !currentId.isEmpty, start == nil {
                        Button {
                            store.toggleSaved(currentId, view: currentView)
                        } label: {
                            Label(store.isSaved(currentId) ? String(localized: "Unsave \(currentId)") : String(localized: "Save \(currentId)"),
                                  systemImage: store.isSaved(currentId) ? "star.fill" : "star")
                                .foregroundStyle(wtAccent)
                        }
                    }
                }
                if start != nil, let me = store.me {
                    Section {
                        if openMe { row(me, match: true) }
                    } header: {
                        heading(String(localized: "Logged in as"), open: $openMe)
                    }
                } else if start != nil, store.meChecked {
                    // The site ends a login now and then; logging in again is one tap away, and
                    // the phone's password manager can fill the form.
                    Section {
                        Button { loggingIn = true } label: {
                            Text("Log in to WikiTree")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(wtButton)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }
                if !suggestions.isEmpty {
                    Section("From your watchlist") {
                        ForEach(suggestions) { s in
                            row(Person(id: s.id, name: s.name,
                                       dates: [s.dates, s.place].filter { !$0.isEmpty }.joined(separator: "  ·  ")),
                                match: true)
                        }
                    }
                }
                if !matches.isEmpty || searchNote != nil {
                    Section("Matches") {
                        ForEach(matches) { p in
                            row(p, match: true)
                                .listRowBackground(p.notable == nil ? nil : Self.notableTint)
                        }
                        if let searchNote { Text(searchNote).foregroundStyle(.secondary) }
                    }
                }
                if start != nil { birthdays }
                Section {
                    if fold(openSaved) {
                        if store.saved.isEmpty {
                            Text("Tap the star next to a person to keep them here.").foregroundStyle(.secondary)
                        }
                        ForEach(store.saved) { row($0) }
                            .onDelete { store.removeSaved(at: $0) }
                    }
                } header: {
                    heading(String(localized: "Saved"), count: store.saved.count, open: $openSaved)
                }
                // A saved person is already listed under Saved, so they are not repeated here.
                let recent = store.recent.filter { !store.isSaved($0.id) }
                Section {
                    if fold(openRecent) {
                        if recent.isEmpty {
                            Text("People you look at appear here.").foregroundStyle(.secondary)
                        }
                        ForEach(recent) { row($0, inRecent: true) }
                            .onDelete { offsets in offsets.map { recent[$0].id }.forEach(store.removeRecent) }
                    }
                } header: {
                    HStack {
                        heading(String(localized: "Recent"), count: recent.count, open: $openRecent)
                        Spacer()
                        if fold(openRecent), !store.recent.isEmpty {
                            Button("Clear") { store.clearRecent() }.font(.footnote)
                        }
                    }
                }
                // The Tree Apps list needs someone to show: the last person, else the member.
                if let start, !appsFor.isEmpty {
                    Section {
                        ForEach(openApps ? start.apps : [], id: \.key) { app in
                            Button {
                                start.onApp(app.key)
                            } label: {
                                HStack {
                                    Text(app.title).foregroundStyle(.primary)
                                    Spacer()
                                    if app.key == currentView { Image(systemName: "checkmark") }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        heading(String(localized: "Tree Apps for \(appsFor)"), open: $openApps)
                    }
                }
            }
            .navigationTitle(start == nil ? String(localized: "People") : String(localized: "WikiTree Tree Apps"))
            .navigationBarTitleDisplayMode(.inline)
            // The start screen has the shell's green bar at the top, so the clock stays readable.
            .toolbarBackground(wtGreen, for: .navigationBar)
            .toolbarBackground(start == nil ? .automatic : .visible, for: .navigationBar)
            .toolbarColorScheme(start == nil ? nil : .dark, for: .navigationBar)
            .toolbar {
                if start == nil {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                }
            }
        }
        .tint(wtAccent)
        .sheet(item: $profile, onDismiss: { if start != nil { store.findMe() } }) { PageSheet(url: $0.url, listen: $0.listen, genie: $0.genie) }
        .sheet(isPresented: $loggingIn, onDismiss: { store.findMe(afterLogin: true) }) { LoginView() }
        .onChange(of: draft) { text in
            // Suggest people from the watchlist while typing, as wikitree.com does.
            let typed = text.trimmingCharacters(in: .whitespaces)
            let name = NameSearch(typed).name
            suggestions = name.count >= 2 ? watchlist.suggest(name) : []
            searchRun += 1
            matches = []
            searchNote = nil
        }
        .onAppear {
            // Once a week the watchlist is fetched again, quietly, if it has been loaded before.
            if start != nil, watchlist.isStale { watchlist.refresh(quiet: true) }
            if start != nil { store.findMe() }
        }
        .onDisappear { voice.stop() }
    }

    /// The People screen (no `start`) has nothing to fold: every section is always open there.
    private func fold(_ open: Bool) -> Bool { start == nil || open }

    /// A section heading. On the start screen a triangle shows whether the section is open and a
    /// tap folds or unfolds it; folded, it says how many it holds.
    @ViewBuilder private func heading(_ title: String, count: Int? = nil, open: Binding<Bool>) -> some View {
        if start == nil {
            Text(title)
        } else {
            Button {
                withAnimation { open.wrappedValue.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: open.wrappedValue ? "arrowtriangle.down.fill" : "arrowtriangle.right.fill")
                        .font(.system(size: 9))
                    Text(open.wrappedValue || count == nil || count == 0 ? title : "\(title) (\(count!))")
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(open.wrappedValue ? String(localized: "Open") : String(localized: "Folded"))
        }
    }

    /// Start screen: who on the watchlist was born or died on this day, then the watchlist and
    /// notification lines.
    @ViewBuilder private var birthdays: some View {
        Section {
            if openBorn {
                if watchlist.isLoaded {
                    let list = watchlist.today
                    // A long list would push Saved and Recent off the screen, so it starts short.
                    let shown = allBirthdays || list.count <= 4 ? list : WatchlistFile.pick(list, 3)
                    if list.isEmpty {
                        Text("Nobody on your watchlist was born or died on this day.").foregroundStyle(.secondary)
                    }
                    ForEach(shown) {
                        row(Person(id: $0.person.id, name: $0.person.name, dates: $0.detail()), match: true, kind: $0.kind)
                    }
                    if shown.count < list.count {
                        Button("Show all \(list.count)") { allBirthdays = true }.font(.footnote)
                    }
                }
                Button(watchlistStatus) { watchlist.refresh() }
                    .font(.footnote)
                    .disabled(watchlist.loading)
                if watchlist.isLoaded {
                    Button(watchlist.notify ? String(localized: "Daily anniversaries notification: on. Tap to turn off.")
                           : String(localized: "Daily anniversaries notification: off. Tap to turn on.")) {
                        watchlist.setNotify(!watchlist.notify)
                    }
                    .font(.footnote)
                }
            }
        } header: {
            heading(String(localized: "Anniversaries, \(WatchlistFile.dayLabel(Date()))"),
                    count: watchlist.isLoaded ? watchlist.today.count : nil, open: $openBorn)
        }
    }

    private var watchlistStatus: String {
        if watchlist.loading { return String(localized: "Loading your watchlist. A long list takes a minute or two…") }
        if let note = watchlist.note { return note }
        guard let at = watchlist.fetchedAt else {
            return String(localized: "Tap to load your WikiTree watchlist, for anniversaries and name suggestions.")
        }
        let count = NumberFormatter.localizedString(from: NSNumber(value: watchlist.people.count), number: .decimal)
        return String(localized: "Watchlist: \(count) people, updated \(at.formatted(date: .abbreviated, time: .omitted)). Tap to refresh.")
    }

    /// Notable search matches: a warm orange that reads on white and on the tinted row (a lighter
    /// orange in dark mode).
    static let notableColor = Color.adaptive(light: 0xA85500, dark: 0xF0A44E)
    /// Behind notable rows: the same light warm beige as on Android (orange at 9% over white), or a
    /// dark brown in dark mode.
    static let notableTint = Color.adaptive(light: 0xF8EEE3, dark: 0x3A2B1A)

    /// `kind` marks a row of the Anniversaries section: "b." or "d." in place of the person icon.
    private func row(_ p: Person, match: Bool = false, kind: Anniversary.Kind? = nil, inRecent: Bool = false) -> some View {
        HStack {
            // The person's profile on www.wikitree.com, in a sheet with the member's login.
            Button {
                let id = p.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? p.id
                if let url = URL(string: "https://www.wikitree.com/wiki/" + id) { profile = .init(url: url) }
            } label: {
                ZStack {
                    Circle().fill(kind == .death ? Color(red: 0xDD / 255, green: 0xDB / 255, blue: 0xD3 / 255)
                                  : Color(red: 0x25 / 255, green: 0x42 / 255, blue: 0x2D / 255))
                    if let kind {
                        Text(kind == .birth ? String(localized: "b.") : String(localized: "d."))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(kind == .birth ? Color(red: 0xF2 / 255, green: 0xC1 / 255, blue: 0x4E / 255)
                                             : Color(red: 0x4A / 255, green: 0x4A / 255, blue: 0x4A / 255))
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(red: 0xF2 / 255, green: 0xC1 / 255, blue: 0x4E / 255))
                    }
                }
                .frame(width: 28, height: 28)
                .padding(.trailing, 4)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Open the WikiTree profile of \(p.name.isEmpty ? p.id : p.name)")
            Button {
                dismiss()
                onPick(p.id, match ? currentView : p.view)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.name.isEmpty ? p.id : p.name).foregroundStyle(.primary)
                    Text([p.name.isEmpty ? nil : p.id, p.dates.isEmpty ? nil : p.dates, match ? nil : appTitle(p.view)]
                        .compactMap { $0 }.joined(separator: "  ·  "))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    if let notable = p.notable {
                        HStack(spacing: 4) {
                            Image(systemName: "rosette")
                            Text(notable.tag)
                        }
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Self.notableColor)
                            .lineLimit(1)
                        if !notable.about.isEmpty {
                            Text(notable.about)
                                .font(.footnote)
                                .foregroundStyle(.primary)
                                .lineLimit(4)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button {
                store.toggleSaved(p.id, view: match ? currentView : p.view)
            } label: {
                Image(systemName: store.isSaved(p.id) ? "star.fill" : "star")
                    .padding(.vertical, 6)
                    .padding(.leading, 12)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(store.isSaved(p.id) ? String(localized: "Unsave \(p.id)") : String(localized: "Save \(p.id)"))
        }
        // Long-press: a card about the person, then what can be done with them.
        .contextMenu {
            menu(p, match: match, inRecent: inRecent)
        } preview: {
            card(p)
        }
    }

    private static func profileURL(_ id: String) -> URL? {
        URL(string: "https://www.wikitree.com/wiki/" + (id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id))
    }

    private func title(_ key: String) -> String {
        apps.first { $0.key == key }?.title ?? appTitle(key) ?? key
    }

    /// The long-press menu: the latest Tree Apps and all of them, the profile, its biography read
    /// aloud, save, share, copy.
    @ViewBuilder private func menu(_ p: Person, match: Bool, inRecent: Bool) -> some View {
        let open: (String) -> Void = { key in
            dismiss()
            onPick(p.id, key)
        }
        Section {
            ForEach(store.recentApps(), id: \.self) { key in
                Button { open(key) } label: { Label(title(key), systemImage: "arrow.up.forward.app") }
            }
            if !apps.isEmpty {
                Menu {
                    ForEach(apps, id: \.key) { app in
                        Button(app.title) { open(app.key) }
                    }
                } label: {
                    Label("All Tree Apps", systemImage: "square.grid.2x2")
                }
            }
        }
        Section {
            Button {
                if let url = Self.profileURL(p.id) { profile = .init(url: url) }
            } label: {
                Label("WikiTree profile", systemImage: "person.crop.circle")
            }
            Button {
                if let url = Self.profileURL(p.id) { profile = .init(url: url, listen: true) }
            } label: {
                Label("Read biography", systemImage: "speaker.wave.2")
            }
            Button {
                store.toggleSaved(p.id, view: match ? currentView : p.view)
            } label: {
                Label(store.isSaved(p.id) ? String(localized: "Unsave") : String(localized: "Save"), systemImage: store.isSaved(p.id) ? "star.slash" : "star")
            }
            if let url = Self.profileURL(p.id) {
                ShareLink(item: url, subject: Text(p.name.isEmpty ? p.id : p.name),
                          message: Text(p.name.isEmpty ? p.id : String(localized: "\(p.name) (\(p.id)) on WikiTree"))) {
                    Label("Share profile link", systemImage: "square.and.arrow.up")
                }
            }
            Button {
                UIPasteboard.general.string = p.id
            } label: {
                Label("Copy WikiTree ID", systemImage: "doc.on.doc")
            }
        }
        if inRecent {
            Button(role: .destructive) {
                store.removeRecent(p.id)
            } label: {
                Label("Remove from Recent", systemImage: "clock.badge.xmark")
            }
        }
    }

    /// The long-press preview: who this is, without opening anything.
    private func card(_ p: Person) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(Color(red: 0x25 / 255, green: 0x42 / 255, blue: 0x2D / 255))
                Image(systemName: "person.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color(red: 0xF2 / 255, green: 0xC1 / 255, blue: 0x4E / 255))
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(p.name.isEmpty ? p.id : p.name).font(.headline)
                if !p.name.isEmpty { Text(p.id).font(.subheadline).foregroundStyle(.secondary) }
                if !p.dates.isEmpty { Text(p.dates).font(.subheadline).foregroundStyle(.secondary) }
                if let notable = p.notable {
                    Label(notable.tag, systemImage: "rosette")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Self.notableColor)
                    if !notable.about.isEmpty { Text(notable.about).font(.subheadline).lineLimit(6) }
                }
            }
        }
        .padding(16)
        .frame(width: 320, alignment: .leading)
        .background(Color(.systemBackground))
    }

    /// Names in the member's own tree, which voice search is steered towards.
    private var treeNames: NameSounds {
        let mine = store.saved + store.recent + [store.me].compactMap { $0 }
        return NameSounds(names: watchlist.people.map(\.name) + mine.map(\.name))
    }

    /// Birthplaces of the people on the watchlist, for putting right a place the phone misheard.
    private var treePlaces: NameSounds { NameSounds(names: watchlist.people.map(\.place), loose: true) }

    /// Listen for a name and put what was heard in the search box, for checking before Find.
    private func listen() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        let names = treeNames
        let places = treePlaces
        voice.start(hints: names.hints() + places.hints(30)) { heard in
            // Of the recognizer's guesses, the one with most names from the tree; else its best.
            let searches = heard.map { text -> NameSearch in
                var q = names.correct(NameSearch(text))
                q.bornPlace = places.correctPlace(q.bornPlace)
                q.diedPlace = places.correctPlace(q.diedPlace)
                return q
            }
            let best = searches.enumerated().max { a, b in
                let sa = names.score(a.element), sb = names.score(b.element)
                return sa != sb ? sa < sb : a.offset > b.offset
            }?.element
            if let best, !best.isEmpty { draft = best.text }
            else { voice.note = String(localized: "No name was heard in “\(heard.first ?? "")”. Try again, or type it.") }
        }
    }

    /// Open Genie over the start screen, on the profile of the person the Tree Apps list is for
    /// (so Genie knows who "him" or "her" is), or WikiTree's home page with nobody.
    private func askGenie() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        let question = genieQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        genieQuestion = ""
        profile = ShellModel.SheetURL(url: Genie.page(for: appsFor), genie: question)
    }

    /// Open a typed WikiTree ID ("Windsor-1"), or look a name up and list the matches.
    private func go() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if text.range(of: #"^\S+-\d+$"#, options: .regularExpression) != nil {
            dismiss()
            onPick(text, currentView)
            return
        }
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        searchRun += 1
        let run = searchRun
        guard !NameSearch(text).isEmpty else {
            searchNote = String(localized: "Add a name to search for, such as “John Smith, born 1850”.")
            return
        }
        suggestions = []
        matches = []
        searchNote = String(localized: "Searching WikiTree…")
        search(run, text, NameSearch(text), placeDropped: false)
    }

    /// Look `query` up and list the matches. A place is easily misheard or spelled another way, so
    /// when nobody matches with it, the search is tried once more without it, and says so.
    private func search(_ run: Int, _ text: String, _ query: NameSearch, placeDropped: Bool) {
        store.search(query.text) { found, total in
            guard run == searchRun else { return }
            if let found, found.isEmpty, !query.bornPlace.isEmpty || !query.diedPlace.isEmpty {
                var anywhere = query
                anywhere.bornPlace = ""
                anywhere.diedPlace = ""
                return search(run, text, anywhere, placeDropped: true)
            }
            matches = found ?? []
            if found == nil {
                searchNote = String(localized: "The search did not work. Check the connection and try again.")
            } else if matches.isEmpty {
                searchNote = query.hasMore || placeDropped
                    ? String(localized: "Nobody found for “\(text)”. Try without the year or place.")
                    : String(localized: "Nobody found for “\(text)”. Try a first name and a last name.")
            } else if placeDropped {
                searchNote = String(localized: "Nobody matched that place, so these matches are from any place.")
            } else if total > matches.count {
                searchNote = String(localized: "Showing \(matches.count) of \(total). Add a first name to narrow it down.")
            } else {
                searchNote = nil
            }
        }
    }
}

// MARK: Logging in to WikiTree

/// A native WikiTree login: email and password (the phone's password manager can fill them), sent
/// to WikiTree's own login forms by a web view nobody sees. It shares the app's cookies, so the
/// member ends up logged in to the www.wikitree.com site and to the Tree Apps, as if they had used
/// the web pages. The password is not kept.
struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var login = WikiTreeLogin()
    @State private var email = ""
    @State private var password = ""
    @State private var webPage: ShellModel.SheetURL?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .onSubmit(go)
                } footer: {
                    Text("Your email and password go only to WikiTree. The app does not keep them.")
                }
                if let error = login.error {
                    Section { Text(error).foregroundStyle(.red) }
                }
                Section {
                    Button(action: go) {
                        HStack {
                            Text(login.busy ? String(localized: "Logging in…") : String(localized: "Log in")).fontWeight(.semibold)
                            Spacer()
                            if login.busy { ProgressView() }
                        }
                    }
                    .disabled(login.busy || email.isEmpty || password.isEmpty)
                    Button("Forgot your password? Use the WikiTree page") {
                        webPage = .init(url: URL(string: "https://www.wikitree.com/index.php?title=Special:Userlogin")!)
                    }
                    .font(.footnote)
                }
            }
            .navigationTitle("Log in to WikiTree")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(wtGreen, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .tint(wtAccent)
        .sheet(item: $webPage, onDismiss: { dismiss() }) { PageSheet(url: $0.url) }
    }

    private func go() {
        guard !login.busy, !email.isEmpty, !password.isEmpty else { return }
        login.logIn(email: email.trimmingCharacters(in: .whitespaces), password: password) { ok in
            password = ""
            if ok { dismiss() }
        }
    }
}

/// Posts the login to www.wikitree.com (the site, with "remember me"), then to the API's
/// clientLogin (the Tree Apps), in a web view that is on screen but invisible, so the site's own
/// pages and scripts run as usual and the cookies land in the app's store.
@MainActor final class WikiTreeLogin: NSObject, ObservableObject, WKNavigationDelegate {
    @Published private(set) var busy = false
    @Published private(set) var error: String?

    private var web: WKWebView?
    private var step = 0
    private var tries = 0
    private var email = ""
    private var password = ""
    private var done: ((Bool) -> Void)?

    func logIn(email: String, password: String, done: @escaping (Bool) -> Void) {
        busy = true
        error = nil
        self.email = email
        self.password = password
        self.done = done
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let web = WKWebView(frame: CGRect(x: 0, y: 0, width: 1, height: 1), configuration: config)
        web.alpha = 0.01
        web.isUserInteractionEnabled = false
        web.navigationDelegate = self
        // Off screen it could be paused, so it sits, unseen, in the key window.
        UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first?.addSubview(web)
        self.web = web
        // WikiTree's own login page, filled in and sent as a person would; that also takes care
        // of anything the site checks first (its firewall's challenge, a session cookie).
        step = 0
        tries = 0
        web.load(URLRequest(url: URL(string: "https://www.wikitree.com/index.php?title=Special:Userlogin")!))
        // A login that hangs gives up after a minute. WikiTree can be slow (pages taking 25s or
        // more), and it may have logged the member in even though its last page has not finished
        // loading, so the cookies are checked before calling it a failure.
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
            guard let self, self.web === web, self.busy else { return }
            Task { @MainActor in
                let inApps = await self.cookie("WikiTreeAPI_userName")
                let inSite = await self.cookie("_UserName")
                let ok = inApps || inSite || self.step >= 2
                self.finish(ok, ok ? nil : String(localized: "WikiTree did not answer. Check the connection and try again."))
            }
        }
    }

    private func post(_ web: WKWebView, _ address: String, _ fields: [String: String]) {
        var request = URLRequest(url: URL(string: address)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        request.httpBody = fields.map { key, value in
            key + "=" + (value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")
        }.joined(separator: "&").data(using: .utf8)
        web.load(request)
    }

    private func cookie(_ suffix: String) async -> Bool {
        await WKWebsiteDataStore.default().httpCookieStore.allCookies()
            .contains { $0.domain.hasSuffix("wikitree.com") && $0.name.hasSuffix(suffix) && !$0.value.isEmpty }
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in await self.pageDone(webView) }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in self.failed(webView, error) }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                             withError error: Error) {
        Task { @MainActor in self.failed(webView, error) }
    }

    private func failed(_ webView: WKWebView, _ error: Error) {
        // A page replaced by the next one (a redirect done by script) is not a failure.
        guard webView === web, (error as NSError).code != NSURLErrorCancelled else { return }
        // Once the site has taken the login, a hitch in the Tree Apps part still leaves the
        // member logged in; the Tree Apps page logs them in there when it next opens.
        if step >= 2 { finish(true, nil) } else {
            finish(false, String(localized: "The login did not go through. Check the connection and try again."))
        }
    }

    private func pageDone(_ webView: WKWebView) async {
        guard webView === web, busy else { return }
        if step == 0 {
            let values = (try? JSONSerialization.data(withJSONObject: [email, password]))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
            let result = try? await webView.evaluateJavaScript("(function(a){var e=document.querySelector('input[name=wpEmail]');var p=document.querySelector('input[name=wpPassword]')||document.querySelector('input[type=password]');var f=(e&&e.form)||(p&&p.form);if(!e||!p||!f){if(document.querySelector('#watchlistSuggestionForm, form[name=watchlistSuggestionForm]'))return 'already';return 'noform '+document.title+' | forms: '+[].map.call(document.forms,function(x){return (x.id||x.name||'?')+'['+[].map.call(x.elements,function(i){return i.name}).join(',')+']'}).join(' ');}e.value=a[0];p.value=a[1];var r=document.getElementById('wpRemember');if(r)r.checked=true;var b=document.getElementById('wpLoginattempt');if(b)b.click();else f.submit();return 'ok';})(" + values + ")") as? String
            if result == "ok" {
                step = 1
            } else if result == "already" {
                // The site already counts the member as logged in; only the Tree Apps part may be missing.
                if await cookie("WikiTreeAPI_userName") { finish(true, nil) } else { apiLogin(webView) }
            } else {
                // Not the login form yet (a firewall check reloads the page by itself).
                tries += 1
                if tries >= 3 { finish(false, String(localized: "The WikiTree login page did not open. Try the WikiTree page below.")) }
            }
            return
        }
        if step == 1 {
            // Logged in once the login form is gone; otherwise WikiTree says why on the page
            // (wrong password, unknown email, ...), or the page title shows where it ended up.
            let said = (try? await webView.evaluateJavaScript("(function(){if(document.querySelector('input[name=wpPassword]')){var m=document.querySelector('.errorbox, .error, .alert-danger, .warningbox');var t=m?m.innerText.trim():'';return 'fail:'+(t?t:'('+document.title+')');}return 'ok';})()") as? String) ?? ""
            guard said == "ok" else {
                finish(false, "WikiTree did not log you in. " + said.replacingOccurrences(of: "fail:", with: ""))
                return
            }
            apiLogin(webView)
        } else if step == 2, webView.url?.host == "www.wikitree.com" {
            // The Tree Apps page finishes the login by itself; give it a few seconds.
            step = 3
            for _ in 0..<10 {
                if await cookie("WikiTreeAPI_userName") { break }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            finish(true, nil)
        }
    }

    /// The Tree Apps login, which comes back to the Tree Apps page to finish.
    private func apiLogin(_ webView: WKWebView) {
        step = 2
        post(webView, "https://api.wikitree.com/api.php",
             ["action": "clientLogin", "doLogin": "1", "returnURL": "https://www.wikitree.com/apps/",
              "wpEmail": email, "wpPassword": password])
    }

    private func finish(_ ok: Bool, _ message: String?) {
        guard busy else { return }
        busy = false
        error = message
        email = ""
        password = ""
        web?.stopLoading()
        web?.removeFromSuperview()
        web = nil
        let done = self.done
        self.done = nil
        done?(ok)
    }
}
