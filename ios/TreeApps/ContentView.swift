import SafariServices
import SwiftUI
import WebKit

/// The shell's colours. The green bar is the same in light and dark; the rest follows the phone's
/// dark mode setting (Settings > Display & Brightness).
let wtGreen = Color(red: 0x25 / 255, green: 0x42 / 255, blue: 0x2D / 255)
let wtGold = Color(red: 0xF2 / 255, green: 0xC1 / 255, blue: 0x4E / 255)
/// The page behind everything: WikiTree's tan, or a near black in dark mode.
let wtTan = Color(UIColor.wtTan)
/// Green text, stars, links and buttons: WikiTree green, or a light green that reads on dark.
let wtAccent = Color.adaptive(light: 0x25422D, dark: 0x8CC79B)
/// Behind white text on a filled button.
let wtButton = Color.adaptive(light: 0x25422D, dark: 0x2F6B43)

extension UIColor {
    static let wtTan = adaptive(light: 0xF7F6F0, dark: 0x141714)

    /// One colour in light mode and another in dark mode, from 0xRRGGBB values.
    static func adaptive(light: UInt32, dark: UInt32) -> UIColor {
        func ui(_ rgb: UInt32) -> UIColor {
            UIColor(red: CGFloat(rgb >> 16 & 0xFF) / 255, green: CGFloat(rgb >> 8 & 0xFF) / 255,
                    blue: CGFloat(rgb & 0xFF) / 255, alpha: 1)
        }
        return UIColor { $0.userInterfaceStyle == .dark ? ui(dark) : ui(light) }
    }
}

extension Color {
    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor.adaptive(light: light, dark: dark))
    }
}

struct ContentView: View {
    @EnvironmentObject private var shell: ShellModel
    @StateObject private var watchlist = WatchlistStore()
    @State private var showingPeople = false
    @State private var showingLogin = false
    @State private var autoRotate = Rotation.auto
    @State private var showHint = false
    // Regular both ways: an iPad window at least about two thirds wide (split view follows it).
    @Environment(\.horizontalSizeClass) private var widthClass
    @Environment(\.verticalSizeClass) private var heightClass

    var body: some View {
        VStack(spacing: 0) {
            if shell.started { bar }
            if shell.loading {
                ProgressView().progressViewStyle(.linear).tint(wtAccent)
            }
            ZStack(alignment: .top) {
                WebViewHolder(webView: shell.webView)
                if !shell.started {
                    // The start screen after a fresh launch: nothing loads until a choice is made.
                    PeopleView(
                        store: shell.people,
                        watchlist: watchlist,
                        currentId: shell.personId,
                        currentView: shell.viewKey,
                        appTitle: { key in shell.apps.first { $0.key == key }?.title },
                        onPick: { id, view in shell.show(id: id, view: view.isEmpty ? shell.viewKey : view) },
                        apps: shell.apps.map { ($0.key, $0.title) },
                        start: PeopleView.Start(
                            apps: shell.apps.map { ($0.key, $0.title) },
                            onApp: { key in
                                shell.show(id: shell.personId.isEmpty ? shell.people.me?.id ?? "" : shell.personId, view: key)
                            }
                        )
                    )
                }
                if showHint {
                    Label("This app's controls are hidden. Tap the sliders button or swipe down on the green bar to show them.",
                          systemImage: "slider.horizontal.3")
                        .font(.footnote)
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 10))
                        .padding(8)
                        .transition(.opacity)
                        .onTapGesture { showHint = false }
                }
                if shell.failed { OfflineView(retry: shell.reload) }
            }
        }
        .background(wtGreen.ignoresSafeArea(edges: .top))
        .background(wtTan.ignoresSafeArea())
        .sheet(isPresented: $showingPeople) {
            PeopleView(
                store: shell.people,
                watchlist: watchlist,
                currentId: shell.personId,
                currentView: shell.viewKey,
                appTitle: { key in shell.apps.first { $0.key == key }?.title },
                onPick: { id, view in shell.show(id: id, view: view.isEmpty ? shell.viewKey : view) },
                apps: shell.apps.map { ($0.key, $0.title) }
            )
        }
        .sheet(isPresented: $showingLogin, onDismiss: { shell.reload() }) { LoginView() }
        .onAppear(perform: runQuickAction)
        .onReceive(NotificationCenter.default.publisher(for: QuickAction.chosen)) { _ in runQuickAction() }
        .sheet(item: $shell.sheet) { item in
            PageSheet(url: item.url, listen: item.listen)
        }
        .onAppear { Rotation.apply(for: shell.started ? shell.viewKey : "") }
        // The start screen is never locked sideways, even when the last chart was a wide one.
        .onChange(of: shell.started) { on in Rotation.apply(for: on ? shell.viewKey : "") }
        .onChange(of: shell.hasControls) { has in
            // Explain the hidden controls the first few times they are hidden.
            let shown = UserDefaults.standard.integer(forKey: "controlsHintCount")
            guard has, !shell.showControls, shown < 3 else { return }
            UserDefaults.standard.set(shown + 1, forKey: "controlsHintCount")
            withAnimation { showHint = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { withAnimation { showHint = false } }
        }
        .onChange(of: shell.viewKey) { key in if shell.started { Rotation.apply(for: key) } }
    }

    private func barIcon(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(label)
    }

    /// The slim bar that replaces the site header and the Tree App / ID form.
    private var bar: some View {
        HStack(spacing: 0) {
            Menu {
                Picker("Tree App", selection: Binding(
                    get: { shell.viewKey },
                    set: { key in
                        if shell.personId.isEmpty {
                            shell.show(id: "", view: key)
                            askPerson()
                        } else {
                            shell.show(id: shell.personId, view: key)
                        }
                    }
                )) {
                    ForEach(shell.apps) { app in
                        Text(app.title).tag(app.key)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(shell.appTitle).lineLimit(1)
                    Image(systemName: "chevron.down").font(.caption2)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
            }

            // On an iPad the bar has room for Share, Print, Open in browser and Saved people, which
            // phones keep in the ⋮ menu.
            if widthClass == .regular && heightClass == .regular {
                barIcon("square.and.arrow.up", "Share this chart") { shell.shareChart() }
                barIcon("printer", "Print or save as PDF") { shell.printChart() }
                barIcon("safari", "Open this page in browser") { shell.openInBrowser() }
                barIcon("star", "Saved and recent people") { askPerson() }
            }

            Button {
                showHint = false
                shell.setControls(!shell.showControls)
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(shell.showControls ? wtGold : .white)
                    .padding(.horizontal, 12)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .opacity(shell.hasControls ? 1 : 0.35)
            .disabled(!shell.hasControls)
            .accessibilityLabel(shell.showControls ? String(localized: "Hide this app's controls") : String(localized: "Show this app's controls"))

            Button(action: askPerson) {
                Text(shell.personId.isEmpty ? String(localized: "Person") : shell.personId)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: 170, maxHeight: .infinity)
                    .fixedSize(horizontal: true, vertical: false)
            }

            Menu {
                if !shell.personId.isEmpty {
                    Button { shell.goHome() } label: { Label("Home", systemImage: "house") }
                }
                if shell.loggedIn {
                    Button("Log out of WikiTree") {
                        // The watchlist belongs to the member who is leaving, so it goes too.
                        watchlist.clear()
                        shell.logOut()
                    }
                } else {
                    // The same native form as the start screen's button.
                    Button("Log in to WikiTree") { showingLogin = true }
                }
                Button("Reload") { shell.reload() }
                Button { shell.shareChart() } label: { Label("Share this chart", systemImage: "square.and.arrow.up") }
                Button { shell.printChart() } label: { Label("Print or save as PDF", systemImage: "printer") }
                Button { shell.openInBrowser() } label: {
                    Label("Open this page in browser", systemImage: "safari")
                }
                Button { askPerson() } label: { Label("Saved and recent people", systemImage: "star") }
                if !shell.personId.isEmpty {
                    Button("Open profile") { shell.openProfile() }
                    Button { shell.openProfile(listen: true) } label: {
                        Label("Listen to biography", systemImage: "speaker.wave.2")
                    }
                }
                Button(shell.showBars ? String(localized: "Hide WikiTree page bars") : String(localized: "Show WikiTree page bars")) {
                    shell.toggleBars()
                }
                if Rotation.isPhone {
                    Toggle("Landscape for wide charts", isOn: Binding(
                        get: { autoRotate },
                        set: { on in
                            autoRotate = on
                            Rotation.auto = on
                            Rotation.apply(for: shell.viewKey)
                        }
                    ))
                }
            } label: {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .padding(.horizontal, 14)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("More")
        }
        .font(.subheadline)
        .foregroundColor(.white)
        .frame(height: 44)
        .background(wtGreen.ignoresSafeArea(edges: [.top, .horizontal]))
        // Swipe down on the bar to show the app's controls, up to hide them. High priority so a
        // swipe that starts on a button (Person, the app menu) doesn't also press it.
        .highPriorityGesture(DragGesture(minimumDistance: 12).onEnded { drag in
            guard shell.hasControls, abs(drag.translation.height) > abs(drag.translation.width) else { return }
            showHint = false
            shell.setControls(drag.translation.height > 0)
        })
    }

    private func askPerson() {
        showingPeople = true
    }

    /// Act on a home-screen quick action: open the chosen person, or the People screen.
    private func runQuickAction() {
        if let link = QuickAction.pendingLink {
            QuickAction.pendingLink = nil
            showingPeople = false
            shell.open(link)
        }
        guard let item = QuickAction.pending else { return }
        QuickAction.pending = nil
        if item.type == QuickAction.person, let id = item.userInfo?["id"] as? String {
            showingPeople = false
            shell.jump(id: id, view: item.userInfo?["view"] as? String ?? "")
        } else {
            if !shell.started { shell.start() }
            askPerson()
        }
    }
}

private struct WebViewHolder: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

/// A page in a sheet over the app (a profile, a source, a help page); closing it returns to where
/// the app was. wikitree.com pages open in the app's own web view, which shares the member's
/// WikiTree login; other sites open in a Safari sheet.
struct PageSheet: View {
    let url: URL
    /// Read the profile's biography aloud as soon as it opens.
    var listen = false
    var body: some View {
        if url.host?.hasSuffix("wikitree.com") == true {
            WikiTreeSheet(url: url, listen: listen)
        } else {
            SafariSheet(url: url).ignoresSafeArea()
        }
    }
}

/// A wikitree.com page in a web view that uses the app's cookies, so the member is logged in as
/// they are in the Tree Apps (a Safari sheet keeps a login of its own). Links leaving
/// wikitree.com open in Safari. On a profile, a speaker button reads the biography aloud, with a
/// bar at the bottom to pause or stop; closing the sheet stops it.
private struct WikiTreeSheet: View {
    let url: URL
    var listen = false
    @Environment(\.dismiss) private var dismiss
    @StateObject private var page = WikiTreePage()
    @StateObject private var reader = BioReader()

    var body: some View {
        NavigationStack {
            WebViewHolder(webView: page.webView)
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) {
                    if page.loading { ProgressView().progressViewStyle(.linear).tint(wtGold) }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) { BioPlayerBar(reader: reader) }
                .navigationTitle(page.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(wtGreen, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                    ToolbarItemGroup(placement: .primaryAction) {
                        if let id = Biography.profileId(page.url ?? url) {
                            Button { reader.start(id) } label: { Image(systemName: "speaker.wave.2") }
                                .accessibilityLabel("Listen to the biography")
                        }
                        Button { page.webView.goBack() } label: { Image(systemName: "chevron.backward") }
                            .disabled(!page.canGoBack)
                            .accessibilityLabel("Back")
                        Button { UIApplication.shared.open(page.webView.url ?? url) } label: { Image(systemName: "safari") }
                            .accessibilityLabel("Open in Safari")
                    }
                }
        }
        .tint(.white)
        .onAppear {
            if page.webView.url == nil {
                page.webView.load(URLRequest(url: url))
                if listen, let id = Biography.profileId(url) { reader.start(id) }
            }
        }
        .onDisappear { reader.stop() }
        // Leaving the app stops the reading for good, rather than pausing it until the app returns.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in reader.stop() }
    }
}

private final class WikiTreePage: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    let webView: WKWebView
    @Published var title = ""
    @Published var canGoBack = false
    @Published var loading = false
    @Published var url: URL?
    private var watching: [NSKeyValueObservation] = []

    override init() {
        // The default data store is the one the Tree Apps web view uses: same cookies, same login.
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        watching = [
            webView.observe(\.title) { [weak self] view, _ in
                DispatchQueue.main.async { self?.title = view.title ?? "" }
            },
            webView.observe(\.canGoBack) { [weak self] view, _ in
                DispatchQueue.main.async { self?.canGoBack = view.canGoBack }
            },
            webView.observe(\.isLoading) { [weak self] view, _ in
                DispatchQueue.main.async { self?.loading = view.isLoading }
            },
            webView.observe(\.url) { [weak self] view, _ in
                DispatchQueue.main.async { self?.url = view.url }
            },
        ]
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url else { return decisionHandler(.allow) }
        let web = url.scheme == "http" || url.scheme == "https"
        // Tapped links to other sites, and mailto: and the like, go to the system.
        if !web && url.scheme != "about" && url.scheme != "blob" && url.scheme != "data"
            || web && action.navigationType == .linkActivated && url.host?.hasSuffix("wikitree.com") != true {
            UIApplication.shared.open(url)
            return decisionHandler(.cancel)
        }
        decisionHandler(.allow)
    }

    /// Links that ask for a new window open in this one.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if action.targetFrame == nil { webView.load(action.request) }
        return nil
    }
}

/// A web page from another site in a Safari sheet over the app.
struct SafariSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredBarTintColor = UIColor(wtGreen)
        controller.preferredControlTintColor = .white
        return controller
    }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

/// Shown over the web view when WikiTree can't be reached (no connection, a timeout, a DNS
/// failure). Retry loads again the page that failed; the screen stays until a load succeeds.
struct OfflineView: View {
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 52, weight: .regular))
                .foregroundStyle(wtAccent)
                .accessibilityHidden(true)
            Text("No connection")
                .font(.title2.weight(.semibold))
                .padding(.top, 16)
            Text("Tree Apps couldn't reach WikiTree. Check your Wi-Fi or mobile data, then try again.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
                .padding(.top, 8)
            Button(action: retry) {
                Text("Retry")
                    .fontWeight(.semibold)
                    .frame(minWidth: 140)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(wtButton)
            .padding(.top, 24)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(wtTan)
    }
}
