import SwiftUI

@main
@MainActor
struct UwayFinanceApp: App {
    @StateObject private var container = AppContainer.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(container.session)
                .environmentObject(container.businessRecordEvidenceCoverageStore)
                .environment(\.importAnalysisAPI, container.importAnalysisAPI)
                .environment(\.documentAPI, container.documentAPI)
                .environment(\.businessRecordEvidenceAPI, container.businessRecordEvidenceAPI)
                .environment(\.classificationReviewAPI, container.classificationReviewAPI)
                .environment(\.classificationPreferenceAPI, container.classificationPreferenceAPI)
                .tint(Color("BrandGreen"))
        }
    }
}
