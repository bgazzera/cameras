import SwiftUI

@main
struct HikvisionViewerMobileApp: App {
    @StateObject private var viewModel = MobileAppViewModel()

    var body: some Scene {
        WindowGroup {
            MobileContentView(viewModel: viewModel)
        }
    }
}
