import SwiftUI

@main
struct HikvisionViewerApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 900, minHeight: 620)
        }
        .defaultSize(width: 1160, height: 760)

        Window("Settings", id: "settings") {
            SettingsView(viewModel: viewModel)
                .frame(width: 520, height: 680)
        }
    }
}
