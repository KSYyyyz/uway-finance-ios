import Combine
import Foundation

@MainActor
final class AppContainer: ObservableObject {
    let session: AppSession
    let importAnalysisAPI: any ImportAnalysisAPI
    let documentAPI: any DocumentAPI
    let businessRecordEvidenceAPI: any BusinessRecordEvidenceAPI
    let classificationReviewAPI: any ClassificationReviewAPI
    let classificationPreferenceAPI: any ClassificationPreferenceAPI

    init(
        financeAPI: any FinanceAPI,
        importAnalysisAPI: any ImportAnalysisAPI,
        documentAPI: any DocumentAPI,
        businessRecordEvidenceAPI: any BusinessRecordEvidenceAPI,
        classificationReviewAPI: any ClassificationReviewAPI,
        classificationPreferenceAPI: any ClassificationPreferenceAPI
    ) {
        self.session = AppSession(api: financeAPI)
        self.importAnalysisAPI = importAnalysisAPI
        self.documentAPI = documentAPI
        self.businessRecordEvidenceAPI = businessRecordEvidenceAPI
        self.classificationReviewAPI = classificationReviewAPI
        self.classificationPreferenceAPI = classificationPreferenceAPI
    }

    static func live(bundle: Bundle = .main) -> AppContainer {
        let configuration = AppConfiguration(bundle: bundle)
        let transport = HTTPTransport(baseURL: configuration.apiBaseURL)
        return AppContainer(
            financeAPI: LiveFinanceAPI(transport: transport),
            importAnalysisAPI: LiveImportAnalysisAPI(transport: transport),
            documentAPI: ReservedDocumentAPI(),
            businessRecordEvidenceAPI: LiveBusinessRecordEvidenceAPI(transport: transport),
            classificationReviewAPI: LiveClassificationReviewAPI(transport: transport),
            classificationPreferenceAPI: LiveClassificationPreferenceAPI(transport: transport)
        )
    }
}

struct AppConfiguration {
    let apiBaseURL: URL

    init(bundle: Bundle) {
        let scheme = bundle.object(forInfoDictionaryKey: "UWAY_API_SCHEME") as? String
        let host = bundle.object(forInfoDictionaryKey: "UWAY_API_HOST") as? String
        self.init(scheme: scheme, host: host)
    }

    init(scheme: String?, host: String?) {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host

        guard scheme == "https", let host, !host.isEmpty, let url = components.url else {
            preconditionFailure("UWAY_API_SCHEME and UWAY_API_HOST must form a valid HTTPS URL")
        }
        self.apiBaseURL = url
    }
}
