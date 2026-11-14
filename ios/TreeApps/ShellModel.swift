import Combine
import Foundation
import LinkPresentation
import UIKit
import WebKit

/// A thin shell around the WikiTree Tree Apps (https://www.wikitree.com/apps/).
///
/// It loads the real Tree Apps page in a WKWebView, hides the site's header, Tree App/ID bar
/// and footer (shared/shell.js), and drives the slim native bar in ContentView. This mirrors
/// MainActivity.kt in the Android app.
final class ShellModel: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    struct TreeApp: Identifiable, Hashable {
        let key: String
        let title: String
        var id: String { key }
    }

    struct SheetURL: Identifiable {
        let url: URL
        var id: String { url.absoluteString }
    }

    @Published var personId: String
    @Published var viewKey: String
    @Published var loggedIn = false
    @Published var apps: [TreeApp]
    @Published var showBars = false
    /// Whether the current Tree App's own controls are showing. They start hidden, per app.
    @Published var showControls = false
    /// Whether the current Tree App has controls the shell knows how to hide.
    @Published var hasControls = false
    @Published var loading = false
    @Published var failed = false
    /// A page shown in a browser sheet over the tree (profiles, sources, help pages).
    @Published var sheet: SheetURL?
    /// False while the start screen is up after a fresh launch: nothing has been loaded yet.
    @Published var started = false

    let webView: WKWebView
    /// Saved and recent people, kept on the phone.
    let people = PeopleStore()

    private let defaultView: String
    private var urlObserver: AnyCancellable?
    /// Set while heading back to the tree from a site page, so a failed return can't loop.
    private var returning = false
    /// The #name=...&view=... last asked for by a fresh load, applied again once the page has
    /// finished loading, as on Android: while it starts up, the Apps login can leave the site's
    /// default app and person instead of the ones asked for.
    private var pendingHash: String?
    private static let siteHost = "www.wikitree.com"
    private static let appsURL = "https://www.wikitree.com/apps/"

    override init() {
        let defaults = UserDefaults.standard
        personId = defaults.string(forKey: "id") ?? ""
        viewKey = defaults.string(forKey: "view") ?? ""

        // shared/views.json: the Tree App list used until the page has loaded its own.
        var known: [TreeApp] = []
        var fallbackView = "fanchart"
        if let url = Bundle.main.url(forResource: "views", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            fallbackView = json["defaultView"] as? String ?? fallbackView
            for item in json["views"] as? [[String: Any]] ?? [] {
                if let key = item["key"] as? String, let title = item["title"] as? String {
                    known.append(TreeApp(key: key, title: title))
                }
            }
        }
        apps = known
        defaultView = fallbackView

        // Inject the hiding script before the page draws, so the site bars never flash on screen.
        let config = WKWebViewConfiguration()
        if let url = Bundle.main.url(forResource: "shell", withExtension: "js"),
           let js = try? String(contentsOf: url, encoding: .utf8) {
            config.userContentController.addUserScript(
                WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        }
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()

        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        #if DEBUG
        if #available(iOS 16.4, *) { webView.isInspectable = true }
        #endif

        // Fires for hash changes too, which is how the Tree Apps switch person and app.
        urlObserver = webView.publisher(for: \.url).sink { [weak self] url in
            if let url { self?.readHash(url) }
        }
        // A fresh launch (also after an update) shows the start screen and loads nothing until
        // something is chosen there. The very first run has nothing to offer, so it just loads.
        if personId.isEmpty { start() }
    }

    /// Leave the start screen for the last person and app.
    func start() {
        started = true
        load(startURL())
    }

    /// "Home" in the menu: back to the start screen, leaving the Tree App as it is underneath.
    func goHome() {
        started = false
    }

    /// "Continue" on the start screen: back to the Tree App if it is loaded, else load it.
    func resume() {
        if let url = webView.url, Self.isTreeApps(url) { started = true } else { start() }
    }

    var appTitle: String {
        apps.first { $0.key == viewKey }?.title ?? "Tree App"
    }

    // MARK: Bar actions

    /// Show `id` in Tree App `view`, switching in place when the Tree Apps page is already open.
    func show(id: String, view: String) {
        let id = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else {
            viewKey = view
            save()
            return
        }
        started = true
        let v = view.isEmpty ? defaultView : view
        let hash = "#name=\(Self.encode(id))&view=\(Self.encode(v))"
        if let url = webView.url, Self.isTreeApps(url) {
            // The Tree Apps page listens for hash changes and redraws without a reload.
            webView.evaluateJavaScript("location.hash = \(Self.quote(hash))")
        } else if let url = URL(string: Self.appsURL + Self.encode(id) + hash) {
            load(url)
        }
    }

    /// Show a person picked from outside the page (a home-screen shortcut), even while the page
    /// is still starting up: a fresh load then remembers the person and app as its pending hash.
    func jump(id: String, view: String) {
        started = true
        if loading || webView.url == nil {
            let v = view.isEmpty ? (viewKey.isEmpty ? defaultView : viewKey) : view
            let hash = "#name=\(Self.encode(id))&view=\(Self.encode(v))"
            if let url = URL(string: Self.appsURL + Self.encode(id) + hash) { load(url) }
        } else {
            show(id: id, view: view.isEmpty ? viewKey : view)
        }
    }

    /// Capture what is on screen as a picture and offer it to the share sheet, with a link to
    /// the same chart.
    func shareChart() {
        webView.takeSnapshot(with: nil) { [weak self] image, _ in
            guard let self, let image else { return }
            let title = [self.appTitle, self.personId].filter { !$0.isEmpty }.joined(separator: ": ")
            let items: [Any] = [ChartImage(image: image, title: "WikiTree " + title), self.startURL()]
            let sheet = UIActivityViewController(activityItems: items, applicationActivities: nil)
            guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
                  var top = scene.windows.first(where: \.isKeyWindow)?.rootViewController else { return }
            while let next = top.presentedViewController { top = next }
            // iPad shows the share sheet as a popover, which needs an anchor.
            sheet.popoverPresentationController?.sourceView = top.view
            sheet.popoverPresentationController?.sourceRect =
                CGRect(x: top.view.bounds.maxX - 30, y: top.view.safeAreaInsets.top + 22, width: 1, height: 1)
            top.present(sheet, animated: true)
        }
    }

    func open(_ url: URL) {
        // A profile link (/wiki/Windsor-1): show that person in the current Tree App.
        if let id = Self.profileId(url) {
            jump(id: id, view: "")
            return
        }
        guard Self.isTreeApps(url) else {
            // Some other wikitree.com page that iOS handed over: show it over the tree.
            if url.host == Self.siteHost { sheet = SheetURL(url: url) }
            return
        }
        started = true
        if let current = webView.url, Self.isTreeApps(current), let fragment = url.fragment {
            // The Tree Apps page switches person and app on a hash change, whatever its path.
            webView.evaluateJavaScript("location.hash = \(Self.quote("#" + fragment))")
        } else {
            load(url)
        }
    }

    /// Load a Tree Apps address, remembering its #hash to apply again once the page has loaded.
    private func load(_ url: URL) {
        pendingHash = url.fragment.map { "#" + $0 }
        webView.load(URLRequest(url: url))
    }

    func reload() {
        failed = false
        started = true
        if webView.url == nil { load(startURL()) } else { webView.reload() }
    }

    func toggleLogin() {
        if loggedIn {
            webView.evaluateJavaScript("window.__wtShellLogout && __wtShellLogout()") { [weak self] _, _ in
                self?.refreshState()
            }
        } else {
            webView.evaluateJavaScript("window.__wtShellLogin ? __wtShellLogin() : false") { [weak self] ok, _ in
                guard let self, (ok as? Bool) != true else { return }
                self.load(self.startURL())
            }
        }
    }

    func setControls(_ show: Bool) {
        showControls = show
        UserDefaults.standard.set(show, forKey: "controls_" + viewKey)
        applyControls()
    }

    private func applyControls() {
        webView.evaluateJavaScript("window.__wtShellSetControls && __wtShellSetControls(\(showControls))")
    }

    /// The apps build their controls a moment after the page or app changes, so look again then.
    private func refreshSoon() {
        for delay in [1.5, 4.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.refreshState() }
        }
    }

    func toggleBars() {
        showBars.toggle()
        webView.evaluateJavaScript("window.__wtShellSetBars && __wtShellSetBars(\(showBars))")
    }

    func openProfile() {
        if let url = URL(string: "https://www.wikitree.com/wiki/" + Self.encode(personId)) {
            sheet = SheetURL(url: url)
        }
    }

    // MARK: State from the page

    private func readHash(_ url: URL) {
        guard Self.isTreeApps(url), let fragment = url.fragment else { return }
        for pair in fragment.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2, let value = parts[1].removingPercentEncoding, !value.isEmpty else { continue }
            if parts[0] == "name" { personId = value }
            if parts[0] == "view", viewKey != value {
                viewKey = value
                showControls = UserDefaults.standard.bool(forKey: "controls_" + value)
                applyControls()
                refreshSoon()
            }
        }
        save()
    }

    private func refreshState() {
        webView.evaluateJavaScript("window.__wtShellState ? __wtShellState() : null") { [weak self] result, _ in
            guard let self, let text = result as? String, let data = text.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            if let id = json["id"] as? String, !id.isEmpty { self.personId = id }
            if let view = json["view"] as? String, !view.isEmpty { self.viewKey = view }
            self.loggedIn = json["loggedIn"] as? Bool ?? false
            self.hasControls = json["hasControls"] as? Bool ?? false
            if let list = json["views"] as? [[String]], !list.isEmpty {
                self.apps = list.compactMap { $0.count == 2 ? TreeApp(key: $0[0], title: $0[1]) : nil }
            }
            self.save()
        }
    }

    private func save() {
        UserDefaults.standard.set(personId, forKey: "id")
        UserDefaults.standard.set(viewKey, forKey: "view")
        people.visit(personId, view: viewKey)
    }

    private func startURL() -> URL {
        if personId.isEmpty { return URL(string: Self.appsURL)! }
        let v = viewKey.isEmpty ? defaultView : viewKey
        let id = Self.encode(personId)
        return URL(string: "\(Self.appsURL)\(id)#name=\(id)&view=\(Self.encode(v))") ?? URL(string: Self.appsURL)!
    }

    // MARK: WKNavigationDelegate

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url, action.targetFrame?.isMainFrame != false else {
            decisionHandler(.allow)
            return
        }
        guard url.scheme == "http" || url.scheme == "https" else {
            // mailto:, tel:, etc.
            if url.scheme != "about" && url.scheme != "blob" && url.scheme != "data" {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
            return
        }
        // Tree Apps pages always stay in the app. So do redirects and form posts: the Apps login
        // goes to api.wikitree.com and back, and may pass through the WikiTree site login page.
        // Only a link tapped on a Tree App page opens in the browser sheet, so closing the sheet
        // returns to the tree exactly as it was.
        let fromTreeApp = webView.url.map(Self.isTreeApps) ?? false
        if action.navigationType == .linkActivated, fromTreeApp, !Self.isTreeApps(url) {
            sheet = SheetURL(url: url)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        loading = true
        failed = false
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loading = false
        if let url = webView.url, Self.shouldReturnToTree(from: url) {
            // After logging in, the site lands on its own pages (e.g. the Navigation Home Page).
            // Go back to the tree instead; the Tree Apps page then completes the Apps login itself.
            if !returning {
                returning = true
                load(startURL())
                return
            }
        } else if let url = webView.url, Self.isTreeApps(url) {
            returning = false
            if let hash = pendingHash {
                pendingHash = nil
                // Only when the person or app differs: Tree Apps add their own settings to the hash
                // (Family Calendar adds &month=), and setting it back would draw the app twice.
                webView.evaluateJavaScript("""
                    (function (want) {
                        function get(h, k) { var m = h.match(new RegExp("[#&]" + k + "=([^&]*)")); return m ? decodeURIComponent(m[1]) : ""; }
                        if (get(location.hash, "name") !== get(want, "name") || get(location.hash, "view") !== get(want, "view")) location.hash = want;
                    })(\(Self.quote(hash)))
                    """)
            }
        }
        webView.evaluateJavaScript("window.__wtShellSetBars && __wtShellSetBars(\(showBars))")
        showControls = UserDefaults.standard.bool(forKey: "controls_" + viewKey)
        applyControls()
        refreshState()
        refreshSoon()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        loading = false
        if (error as NSError).code != NSURLErrorCancelled { failed = true }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loading = false
    }

    // MARK: WKUIDelegate

    /// Links that ask for a new window (target="_blank", window.open) open in the browser sheet.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = action.request.url, url.scheme == "http" || url.scheme == "https" {
            if Self.isTreeApps(url) {
                webView.load(URLRequest(url: url))
            } else {
                sheet = SheetURL(url: url)
            }
        }
        return nil
    }

    // MARK: Helpers

    /// The WikiTree ID in a profile link such as https://www.wikitree.com/wiki/Windsor-1, or nil.
    /// A colon means a Help:, Space: or Category: page, not a person.
    private static func profileId(_ url: URL) -> String? {
        let parts = url.pathComponents
        guard url.host == siteHost, parts.count == 3, parts[1] == "wiki",
              parts[2].range(of: #"^[^:/]+-\d+$"#, options: .regularExpression) != nil else { return nil }
        return parts[2]
    }

    private static func isTreeApps(_ url: URL) -> Bool {
        url.host == siteHost && url.path.hasPrefix("/apps")
    }

    /// True for a WikiTree site page that is neither a Tree App nor part of logging in.
    private static func shouldReturnToTree(from url: URL) -> Bool {
        guard url.host == siteHost, !isTreeApps(url) else { return false }
        let text = url.absoluteString.lowercased()
        return !text.contains("login") && !text.contains("password")
    }

    private static func encode(_ text: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return text.addingPercentEncoding(withAllowedCharacters: allowed) ?? text
    }

    private static func quote(_ text: String) -> String {
        let data = try? JSONSerialization.data(withJSONObject: [text])
        let array = data.flatMap { String(data: $0, encoding: .utf8) } ?? "[\"\"]"
        return String(array.dropFirst().dropLast())
    }
}

/// A chart picture for the share sheet, with a title for apps that show one (Mail's subject,
/// the preview at the top of the sheet).
private final class ChartImage: NSObject, UIActivityItemSource {
    let image: UIImage
    let title: String

    init(image: UIImage, title: String) {
        self.image = image
        self.title = title
    }

    func activityViewControllerPlaceholderItem(_ controller: UIActivityViewController) -> Any { image }

    func activityViewController(_ controller: UIActivityViewController,
                                itemForActivityType activityType: UIActivity.ActivityType?) -> Any? { image }

    func activityViewController(_ controller: UIActivityViewController,
                                subjectForActivityType activityType: UIActivity.ActivityType?) -> String { title }

    /// The top of the share sheet: the chart itself and its title, not a preview of the link.
    func activityViewControllerLinkMetadata(_ controller: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = title
        metadata.imageProvider = NSItemProvider(object: image)
        metadata.iconProvider = NSItemProvider(object: image)
        return metadata
    }
}
