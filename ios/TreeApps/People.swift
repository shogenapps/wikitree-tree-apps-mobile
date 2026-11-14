import SwiftUI
import UIKit

/// One person in the saved or recent list. `view` is the Tree App they were last shown in.
struct Person: Codable, Identifiable, Equatable {
    var id: String
    var name = ""
    var dates = ""
    var view = ""
    var time = Date()

    func isSame(_ other: String) -> Bool { id.caseInsensitiveCompare(other) == .orderedSame }
}

/// Saved (starred) and recently viewed people, kept on the phone only. Names and dates come from
/// the public WikiTree API, looked up once per person and cached. Mirrors People.kt on Android.
final class PeopleStore: ObservableObject {
    @Published private(set) var saved: [Person]
    @Published private(set) var recent: [Person]

    private let defaults = UserDefaults.standard
    private var looking = Set<String>()
    private static let maxRecent = 25

    init() {
        saved = Self.read("peopleSaved")
        recent = Self.read("peopleRecent")
        updateShortcuts()
    }

    func isSaved(_ id: String) -> Bool { saved.contains { $0.isSame(id) } }

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

    func removeRecent(at offsets: IndexSet) {
        recent.remove(atOffsets: offsets)
        persist()
    }

    func clearRecent() {
        recent = []
        persist()
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
            type: QuickAction.people, localizedTitle: "Change person", localizedSubtitle: nil,
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
                for i in self.recent.indices where self.recent[i].isSame(id) {
                    self.recent[i].name = found.name
                    self.recent[i].dates = found.dates
                }
                self.persist()
            }
        }.resume()
    }

    static let searchLimit = 10

    /// Search WikiTree by name: the last word is the last name, anything before it the first
    /// name. `done` gets up to `searchLimit` people (their dates include the birthplace) and the
    /// total number of matches, or nil if the search failed.
    func search(_ text: String, done: @escaping ([Person]?, Int) -> Void) {
        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        var parts = URLComponents(string: "https://api.wikitree.com/api.php")!
        parts.queryItems = [
            URLQueryItem(name: "action", value: "searchPerson"),
            URLQueryItem(name: "appId", value: "TreeAppsMobile"),
            URLQueryItem(name: "fields", value: "Name,FirstName,RealName,LastNameAtBirth,LastNameCurrent,BirthDate,DeathDate,BirthLocation"),
            URLQueryItem(name: "limit", value: String(Self.searchLimit)),
            URLQueryItem(name: "LastName", value: words.last ?? ""),
            URLQueryItem(name: "FirstName", value: words.dropLast().joined(separator: " ")),
        ]
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
                    return Person(id: id, name: found.name, dates: detail.joined(separator: "  ·  "))
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

    private static func describe(_ p: [String: Any]) -> (name: String, dates: String)? {
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
/// With `start` set it is the start screen shown when the app is opened afresh: it adds a
/// "Continue" button for the last app and person and the list of Tree Apps, and has no Done.
struct PeopleView: View {
    struct Start {
        let continueTitle: String
        let apps: [(key: String, title: String)]
        let onContinue: () -> Void
        let onApp: (String) -> Void
    }

    @ObservedObject var store: PeopleStore
    let currentId: String
    let currentView: String
    let appTitle: (String) -> String?
    let onPick: (String, String) -> Void
    var start: Start?

    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @State private var matches: [Person] = []
    @State private var searchNote: String?
    @State private var searchRun = 0

    var body: some View {
        NavigationStack {
            List {
                if let start {
                    Section {
                        Button(action: start.onContinue) {
                            Text(start.continueTitle)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }
                Section {
                    HStack {
                        TextField("Name or WikiTree ID", text: $draft)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                            .onSubmit(go)
                        Button("Find", action: go)
                            .buttonStyle(.borderedProminent)
                            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    if !currentId.isEmpty, start == nil {
                        Button {
                            store.toggleSaved(currentId, view: currentView)
                        } label: {
                            Label(store.isSaved(currentId) ? "Unsave \(currentId)" : "Save \(currentId)",
                                  systemImage: store.isSaved(currentId) ? "star.fill" : "star")
                                .foregroundStyle(Color(red: 0x25 / 255, green: 0x42 / 255, blue: 0x2D / 255))
                        }
                    }
                }
                if !matches.isEmpty || searchNote != nil {
                    Section("Matches") {
                        ForEach(matches) { row($0, match: true) }
                        if let searchNote { Text(searchNote).foregroundStyle(.secondary) }
                    }
                }
                Section("Saved") {
                    if store.saved.isEmpty {
                        Text("Tap the star next to a person to keep them here.").foregroundStyle(.secondary)
                    }
                    ForEach(store.saved) { row($0) }
                        .onDelete { store.removeSaved(at: $0) }
                }
                Section {
                    if store.recent.isEmpty {
                        Text("People you look at appear here.").foregroundStyle(.secondary)
                    }
                    ForEach(store.recent) { row($0) }
                        .onDelete { store.removeRecent(at: $0) }
                } header: {
                    HStack {
                        Text("Recent")
                        Spacer()
                        if !store.recent.isEmpty {
                            Button("Clear") { store.clearRecent() }.font(.footnote)
                        }
                    }
                }
                if let start {
                    Section("Tree Apps for \(currentId)") {
                        ForEach(start.apps, id: \.key) { app in
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
                    }
                }
            }
            .navigationTitle(start == nil ? "People" : "Tree Apps")
            .navigationBarTitleDisplayMode(.inline)
            // The start screen has the shell's green bar at the top, so the clock stays readable.
            .toolbarBackground(Color(red: 0x25 / 255, green: 0x42 / 255, blue: 0x2D / 255), for: .navigationBar)
            .toolbarBackground(start == nil ? .automatic : .visible, for: .navigationBar)
            .toolbarColorScheme(start == nil ? nil : .dark, for: .navigationBar)
            .toolbar {
                if start == nil {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                }
            }
        }
        .tint(Color(red: 0x25 / 255, green: 0x42 / 255, blue: 0x2D / 255))
    }

    private func row(_ p: Person, match: Bool = false) -> some View {
        HStack {
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
                        .lineLimit(1)
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
            .accessibilityLabel(store.isSaved(p.id) ? "Unsave \(p.id)" : "Save \(p.id)")
        }
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
        matches = []
        searchNote = "Searching WikiTree…"
        store.search(text) { found, total in
            guard run == searchRun else { return }
            matches = found ?? []
            if found == nil {
                searchNote = "The search did not work. Check the connection and try again."
            } else if matches.isEmpty {
                searchNote = "Nobody found for “\(text)”. Try a first name and a last name."
            } else if total > matches.count {
                searchNote = "Showing \(matches.count) of \(total). Add a first name to narrow it down."
            } else {
                searchNote = nil
            }
        }
    }
}
