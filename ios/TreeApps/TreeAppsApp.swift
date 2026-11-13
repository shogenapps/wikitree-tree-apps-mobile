import SwiftUI
import UIKit

@main
struct TreeAppsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var shell = ShellModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(shell)
                .onOpenURL { shell.open($0) }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        Rotation.mask
    }
}

/// Wide charts (landscape = true in shared/views.json) turn the phone to landscape and lock
/// there while they are open. iPads are left alone, and the ⋮ menu can switch this off.
enum Rotation {
    static let autoKey = "autoRotate"
    private(set) static var mask: UIInterfaceOrientationMask = .allButUpsideDown

    static let isPhone = UIDevice.current.userInterfaceIdiom == .phone

    static var auto: Bool {
        get { UserDefaults.standard.object(forKey: autoKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: autoKey) }
    }

    private static let landscapeViews: Set<String> = {
        guard let url = Bundle.main.url(forResource: "views", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let views = json["views"] as? [[String: Any]] else { return [] }
        return Set(views.filter { $0["landscape"] as? Bool == true }.compactMap { $0["key"] as? String })
    }()

    static func apply(for viewKey: String) {
        let lock = isPhone && auto && landscapeViews.contains(viewKey)
        let wanted: UIInterfaceOrientationMask = lock ? .landscape : .allButUpsideDown
        guard wanted != mask else { return }
        mask = wanted
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: wanted)) { _ in }
            scene.windows.forEach { $0.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations() }
        }
    }
}
