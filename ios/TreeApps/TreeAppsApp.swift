import SwiftUI

@main
struct TreeAppsApp: App {
    @StateObject private var shell = ShellModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(shell)
                .onOpenURL { shell.open($0) }
        }
    }
}
