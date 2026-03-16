import AppKit
import SwiftUI

final class HikvisionViewerAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct HikvisionViewerApp: App {
    @NSApplicationDelegateAdaptor(HikvisionViewerAppDelegate.self) private var appDelegate
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .background(MainWindowLifecycleView())
                .frame(minWidth: 900, minHeight: 620)
        }
        .defaultSize(width: 1160, height: 760)

        Window("Settings", id: "settings") {
            SettingsView(viewModel: viewModel)
                .frame(width: 520, height: 680)
        }
    }
}
