import Combine
import Foundation
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
    @Published var loading = false
    @Published var failed = false
    /// A page shown in a browser sheet over the tree (profiles, sources, help pages).
    @Published var sheet: SheetURL?

    let webView: WKWebView

    private let defaultView: String
    private var urlObserver: AnyCancellable?
    /// Set while heading back to the tree from a site page, so a failed return can't loop.
    private var returning = false
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
            for item in json["views"] as? [[String: String]] ?? [] {
                if let key = item["key"], let title = item["title"] {
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

        // Fires for hash changes too, which is how the Tree Apps switch person and app.
        urlObserver = webView.publisher(for: \.url).sink { [weak self] url in
            if let url { self?.readHash(url) }
        }
        webView.load(URLRequest(url: startURL()))
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
        let v = view.isEmpty ? defaultView : view
        let hash = "#name=\(Self.encode(id))&view=\(Self.encode(v))"
        if let url = webView.url, Self.isTreeApps(url) {
            // The Tree Apps page listens for hash changes and redraws without a reload.
            webView.evaluateJavaScript("location.hash = \(Self.quote(hash))")
        } else if let url = URL(string: Self.appsURL + Self.encode(id) + hash) {
            webView.load(URLRequest(url: url))
        }
    }

    func open(_ url: URL) {
        if Self.isTreeApps(url) { webView.load(URLRequest(url: url)) }
    }

    func reload() {
        failed = false
        if webView.url == nil { webView.load(URLRequest(url: startURL())) } else { webView.reload() }
    }

    func toggleLogin() {
        if loggedIn {
            webView.evaluateJavaScript("window.__wtShellLogout && __wtShellLogout()") { [weak self] _, _ in
                self?.refreshState()
            }
        } else {
            webView.evaluateJavaScript("window.__wtShellLogin ? __wtShellLogin() : false") { [weak self] ok, _ in
                guard let self, (ok as? Bool) != true else { return }
                self.webView.load(URLRequest(url: self.startURL()))
            }
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
            if parts[0] == "view" { viewKey = value }
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
            if let list = json["views"] as? [[String]], !list.isEmpty {
                self.apps = list.compactMap { $0.count == 2 ? TreeApp(key: $0[0], title: $0[1]) : nil }
            }
            self.save()
        }
    }

    private func save() {
        UserDefaults.standard.set(personId, forKey: "id")
        UserDefaults.standard.set(viewKey, forKey: "view")
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
                webView.load(URLRequest(url: startURL()))
                return
            }
        } else if let url = webView.url, Self.isTreeApps(url) {
            returning = false
        }
        webView.evaluateJavaScript("window.__wtShellSetBars && __wtShellSetBars(\(showBars))")
        refreshState()
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
