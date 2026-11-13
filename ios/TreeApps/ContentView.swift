import SafariServices
import SwiftUI
import WebKit

private let wtGreen = Color(red: 0x25 / 255, green: 0x42 / 255, blue: 0x2D / 255)
private let wtGold = Color(red: 0xF2 / 255, green: 0xC1 / 255, blue: 0x4E / 255)
private let wtTan = Color(red: 0xF7 / 255, green: 0xF6 / 255, blue: 0xF0 / 255)

struct ContentView: View {
    @EnvironmentObject private var shell: ShellModel
    @State private var askingPerson = false
    @State private var personDraft = ""
    @State private var autoRotate = Rotation.auto
    @State private var showHint = false

    var body: some View {
        VStack(spacing: 0) {
            bar
            if shell.loading {
                ProgressView().progressViewStyle(.linear).tint(wtGreen)
            }
            ZStack(alignment: .top) {
                WebViewHolder(webView: shell.webView)
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
                if shell.failed {
                    VStack(spacing: 12) {
                        Text("Couldn't load WikiTree. Check your connection.")
                            .multilineTextAlignment(.center)
                        Button("Reload") { shell.reload() }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(wtTan)
                }
            }
        }
        .background(wtGreen.ignoresSafeArea(edges: .top))
        .background(wtTan.ignoresSafeArea())
        .alert("Person", isPresented: $askingPerson) {
            TextField("WikiTree ID, e.g. Windsor-1", text: $personDraft)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Go") { shell.show(id: personDraft, view: shell.viewKey) }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $shell.sheet) { item in
            SafariSheet(url: item.url).ignoresSafeArea()
        }
        .preferredColorScheme(.light)
        .onAppear { Rotation.apply(for: shell.viewKey) }
        .onChange(of: shell.hasControls) { has in
            // Explain the hidden controls the first few times they are hidden.
            let shown = UserDefaults.standard.integer(forKey: "controlsHintCount")
            guard has, !shell.showControls, shown < 3 else { return }
            UserDefaults.standard.set(shown + 1, forKey: "controlsHintCount")
            withAnimation { showHint = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { withAnimation { showHint = false } }
        }
        .onChange(of: shell.viewKey) { key in Rotation.apply(for: key) }
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
            .accessibilityLabel(shell.showControls ? "Hide this app's controls" : "Show this app's controls")

            Button(action: askPerson) {
                Text(shell.personId.isEmpty ? "Person" : shell.personId)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: 170, maxHeight: .infinity)
                    .fixedSize(horizontal: true, vertical: false)
            }

            Menu {
                Button(shell.loggedIn ? "Log out of Apps" : "Apps login") { shell.toggleLogin() }
                Button("Reload") { shell.reload() }
                if !shell.personId.isEmpty {
                    Button("Open profile") { shell.openProfile() }
                }
                if let url = shell.webView.url {
                    Button("Open this page in Safari") { UIApplication.shared.open(url) }
                }
                Button(shell.showBars ? "Hide WikiTree page bars" : "Show WikiTree page bars") {
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
        // Swipe down on the bar to show the app's controls, up to hide them.
        .simultaneousGesture(DragGesture(minimumDistance: 12).onEnded { drag in
            guard shell.hasControls, abs(drag.translation.height) > abs(drag.translation.width) else { return }
            showHint = false
            shell.setControls(drag.translation.height > 0)
        })
    }

    private func askPerson() {
        personDraft = shell.personId
        askingPerson = true
    }
}

private struct WebViewHolder: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

private struct SafariSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredBarTintColor = UIColor(wtGreen)
        controller.preferredControlTintColor = .white
        return controller
    }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
