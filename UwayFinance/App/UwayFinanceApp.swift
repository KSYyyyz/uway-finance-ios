import SwiftUI

@main
@MainActor
struct UwayFinanceApp: App {
    @StateObject private var container = AppContainer.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(container.session)
                .environment(\.importAnalysisAPI, container.importAnalysisAPI)
                .environment(\.documentAPI, container.documentAPI)
                .tint(Color("BrandGreen"))
        }
    }
}
