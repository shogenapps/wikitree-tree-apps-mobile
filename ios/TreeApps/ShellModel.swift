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
        /// Read the profile's biography aloud as soon as it opens.
        var listen = false
        var id: String { url.absoluteString + (listen ? "#listen" : "") }
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
    /// The address whose load failed, so Retry goes back to where the user was.
    private var failedURL: URL?
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
        // Show the shell's tan (dark in dark mode) until the page draws, not a white flash.
        webView.isOpaque = false
        webView.backgroundColor = .wtTan
        #if DEBUG
        if #available(iOS 16.4, *) { webView.isInspectable = true }
        #endif

        // Fires for hash changes too, which is how the Tree Apps switch person and app.
        urlObserver = webView.publisher(for: \.url).sink { [weak self] url in
            if let url { self?.readHash(url) }
        }
        // A launch (the very first one too) shows the start screen and loads nothing until
        // something is chosen there. Loading the Tree Apps page with nobody chosen would show
        // WikiTree's own login page to someone who is not logged in.
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
        if !failed, let url = webView.url, Self.isTreeApps(url) {
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

    /// A picture of the whole chart for the share sheet, with a link to the same chart.
    func shareChart() {
        captureWholeChart { [weak self] image in
            guard let self else { return }
            self.present([ChartImage(image: image, title: "WikiTree " + self.chartTitle), self.startURL()])
        }
    }

    /// Turn the whole chart into a one-page PDF (title, chart, link back) and offer it to the
    /// share sheet, which has Print, Save to Files and AirDrop for a PDF.
    func printChart() {
        captureWholeChart { [weak self] image in
            guard let self else { return }
            let title = "WikiTree " + self.chartTitle
            let name = title.replacingOccurrences(of: ":", with: "")
                .replacingOccurrences(of: "/", with: "-")
            let file = FileManager.default.temporaryDirectory.appendingPathComponent(name + ".pdf")
            do {
                try ChartPDF.data(image: image, title: title, link: self.startURL().absoluteString)
                    .write(to: file, options: .atomic)
            } catch { return }
            self.present([file])
        }
    }

    /// "Fan Chart: Beacall-6", for the share sheet and the PDF.
    private var chartTitle: String {
        [appTitle, personId].filter { !$0.isEmpty }.joined(separator: ": ")
    }

    private func present(_ items: [Any]) {
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
        started = true
        if failed {
            // After a failed load the web view still shows the page before it (or nothing),
            // so load the address that failed. "No connection" stays up until a load succeeds.
            load(failedURL ?? webView.url ?? startURL())
        } else if webView.url == nil {
            load(startURL())
        } else {
            webView.reload()
        }
    }

    /// "Log out of WikiTree": the Tree Apps logout (which also forgets saved data), then the
    /// WikiTree cookies go, so the site is logged out too; then the page loads afresh.
    func logOut() {
        webView.evaluateJavaScript("window.__wtShellLogout && __wtShellLogout()") { [weak self] _, _ in
            // Give the Tree Apps' own logout call a moment before its cookies go.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                let store = WKWebsiteDataStore.default().httpCookieStore
                store.getAllCookies { cookies in
                    let ours = cookies.filter { $0.domain.hasSuffix("wikitree.com") }
                    let group = DispatchGroup()
                    for cookie in ours {
                        group.enter()
                        store.delete(cookie) { group.leave() }
                    }
                    group.notify(queue: .main) {
                        guard let self else { return }
                        self.people.findMe()
                        self.load(self.startURL())
                    }
                }
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

    func openProfile(listen: Bool = false) {
        if let url = URL(string: "https://www.wikitree.com/wiki/" + Self.encode(personId)) {
            sheet = SheetURL(url: url, listen: listen)
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
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        failed = false
        failedURL = nil
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
        let error = error as NSError
        // Cancelled loads (a new one started) and loads stopped by the shell's own link
        // handling (WebKit error 102) are not failures.
        if error.code == NSURLErrorCancelled { return }
        if error.domain == "WebKitErrorDomain" && error.code == 102 { return }
        failedURL = error.userInfo[NSURLErrorFailingURLErrorKey] as? URL ?? failedURL
        failed = true
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loading = false
        // The connection dropped part way through loading the page.
        let error = error as NSError
        let lost = [NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost, NSURLErrorTimedOut,
                    NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost, NSURLErrorDNSLookupFailed]
        if error.domain == NSURLErrorDomain && lost.contains(error.code) {
            failedURL = error.userInfo[NSURLErrorFailingURLErrorKey] as? URL ?? webView.url
            failed = true
        }
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

/// A one-page PDF of a chart: its title above, the picture in the middle and the link to the
/// same chart below. The page is the chart's own shape, so nothing is cropped; printing scales
/// it to the paper.
enum ChartPDF {
    static func data(image: UIImage, title: String, link: String) -> Data {
        let margin: CGFloat = 24
        let titleFont = UIFont.systemFont(ofSize: 16, weight: .semibold)
        let linkFont = UIFont.systemFont(ofSize: 9)
        let header = titleFont.lineHeight + 12
        let footer = linkFont.lineHeight + 12
        let size = image.size
        let page = CGRect(x: 0, y: 0, width: size.width + margin * 2,
                          height: size.height + margin * 2 + header + footer)
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [kCGPDFContextTitle as String: title, kCGPDFContextCreator as String: "WikiTree Tree Apps"]
        return UIGraphicsPDFRenderer(bounds: page, format: format).pdfData { context in
            context.beginPage()
            let width = page.width - margin * 2
            (title as NSString).draw(
                in: CGRect(x: margin, y: margin, width: width, height: titleFont.lineHeight),
                withAttributes: [.font: titleFont, .foregroundColor: UIColor.black])
            image.draw(in: CGRect(x: margin, y: margin + header, width: size.width, height: size.height))
            let url = URL(string: link)
            let attributes: [NSAttributedString.Key: Any] = [.font: linkFont, .foregroundColor: UIColor.darkGray]
            (link as NSString).draw(
                in: CGRect(x: margin, y: page.height - margin - linkFont.lineHeight, width: width, height: linkFont.lineHeight),
                withAttributes: attributes)
            // Make the link tappable in the PDF too.
            if let url {
                context.setURL(url, for: CGRect(x: margin, y: page.height - margin - linkFont.lineHeight,
                                                 width: width, height: linkFont.lineHeight))
            }
        }
    }
}

// MARK: - A picture of the whole chart

extension ShellModel {
    /// The whole chart as a picture, without the app's controls (see ChartCapture), handed to
    /// `done`. Nothing happens if not even the screen could be had.
    func captureWholeChart(_ done: @escaping (UIImage) -> Void) {
        webView.takeSnapshot(with: nil) { [weak self] screen, _ in
            guard let self, let screen else { return }
            ChartCapture(webView: self.webView, screen: screen, done: done).start()
        }
    }
}

/// A picture of the whole chart, not just the part on screen, for "Share this chart" and
/// "Print or save as PDF".
///
/// The page gets ready first (shell.js `__wtShellCapture`): the app's controls are hidden and it
/// says how big the web view needs to be to hold all of the chart, or all of a list that scrolls.
/// The web view is made that size behind a still picture of the screen (so nothing jumps about),
/// the chart is laid out in it, a snapshot is taken, and everything is put back. If the page
/// cannot do this (an older page, or something fails) it is the screen as it was.
private final class ChartCapture {
    private let webView: WKWebView
    /// What is on screen, used as the cover and as the answer if the whole chart can't be had.
    private let screen: UIImage
    private let done: (UIImage) -> Void
    private let oldFrame: CGRect
    private var cover: UIImageView?
    private var finished = false
    /// Kept alive by itself until it has finished.
    private var me: ChartCapture?

    /// A long list is drawn smaller rather than run out of memory.
    private static let maxPixels: CGFloat = 16_000_000
    private static let layoutDelay = 0.5
    private static let drawDelay = 0.3

    init(webView: WKWebView, screen: UIImage, done: @escaping (UIImage) -> Void) {
        self.webView = webView
        self.screen = screen
        self.done = done
        oldFrame = webView.frame
    }

    func start() {
        me = self
        // A still picture of the screen over the web view while it is resized out of sight.
        // It takes the taps too, so nothing on the page is touched meanwhile.
        if let window = webView.window {
            let view = UIImageView(image: screen)
            view.frame = webView.convert(webView.bounds, to: window)
            view.isUserInteractionEnabled = true
            window.addSubview(view)
            cover = view
        }
        // If anything hangs, the screen picture is shared after a while all the same.
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in self?.finish(nil) }
        ask("begin") { [self] size in
            if let size { grow(size, pass: 0) } else { finish(nil) }
        }
    }

    /// Make the web view `size` (CSS pixels, which are points here), let the page lay out, then
    /// fit the chart to it.
    private func grow(_ size: CGSize, pass: Int) {
        guard !finished else { return }
        webView.frame = CGRect(origin: oldFrame.origin, size: size)
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.layoutDelay) { [self] in
            ask("fit") { [self] need in
                guard let need else { return finish(nil) }
                if pass < 3, abs(need.width - size.width) > 2 || abs(need.height - size.height) > 2 {
                    // A list that grew taller when it got wider (or the like): grow again.
                    grow(need, pass: pass + 1)
                } else {
                    // Let the page draw the chart where it was moved to.
                    DispatchQueue.main.asyncAfter(deadline: .now() + Self.drawDelay) { [self] in draw() }
                }
            }
        }
    }

    private func draw() {
        guard !finished else { return }
        let size = webView.bounds.size
        let config = WKSnapshotConfiguration()
        config.rect = webView.bounds
        config.afterScreenUpdates = true
        let scale = webView.window?.screen.scale ?? UIScreen.main.scale
        let pixels = size.width * size.height * scale * scale
        if pixels > Self.maxPixels {
            config.snapshotWidth = NSNumber(value: Double(size.width * (Self.maxPixels / pixels).squareRoot()))
        }
        webView.takeSnapshot(with: config) { [self] image, _ in finish(image) }
    }

    /// Hand over the picture (or the screen), then put the web view and the page back.
    private func finish(_ image: UIImage?) {
        guard !finished else { return }
        finished = true
        webView.frame = oldFrame
        done(image ?? screen)
        // The page puts its scroll positions back once the view is its own size again.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.layoutDelay) { [self] in
            webView.evaluateJavaScript("window.__wtShellCapture && __wtShellCapture('end')")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [self] in
                cover?.removeFromSuperview()
                me = nil
            }
        }
    }

    private func ask(_ step: String, answer: @escaping (CGSize?) -> Void) {
        webView.evaluateJavaScript("window.__wtShellCapture ? __wtShellCapture('\(step)') : ''") { result, _ in
            guard let text = result as? String, let data = text.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let w = json["w"] as? Double, let h = json["h"] as? Double, w > 0, h > 0
            else { return answer(nil) }
            answer(CGSize(width: w, height: h))
        }
    }
}
