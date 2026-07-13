import Combine
import Foundation

@MainActor
final class AppContainer: ObservableObject {
    let session: AppSession
    let importAnalysisAPI: any ImportAnalysisAPI
    let documentAPI: any DocumentAPI

    init(
        financeAPI: any FinanceAPI,
        importAnalysisAPI: any ImportAnalysisAPI,
        documentAPI: any DocumentAPI
    ) {
        self.session = AppSession(api: financeAPI)
        self.importAnalysisAPI = importAnalysisAPI
        self.documentAPI = documentAPI
    }

    static func live(bundle: Bundle = .main) -> AppContainer {
        let configuration = AppConfiguration(bundle: bundle)
        let transport = HTTPTransport(baseURL: configuration.apiBaseURL)
        return AppContainer(
            financeAPI: LiveFinanceAPI(transport: transport),
            importAnalysisAPI: LiveImportAnalysisAPI(transport: transport),
            documentAPI: ReservedDocumentAPI()
        )
    }
}

struct AppConfiguration {
    let apiBaseURL: URL

    init(bundle: Bundle) {
        let rawValue = bundle.object(forInfoDictionaryKey: "UWAY_API_BASE_URL") as? String
        guard let rawValue, let url = URL(string: rawValue), url.scheme == "https" else {
            preconditionFailure("UWAY_API_BASE_URL must be a valid HTTPS URL")
        }
        self.apiBaseURL = url
    }
}
