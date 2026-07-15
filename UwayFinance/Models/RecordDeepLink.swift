import Foundation

enum RecordDeepLinkOrigin: Hashable, Sendable {
    case workbench
    case ledger
    case pending(filter: String)
    case classification(state: String)
}

struct RecordDeepLinkRoute: Identifiable, Hashable, Sendable {
    let recordID: String
    let origin: RecordDeepLinkOrigin
    let canEdit: Bool

    var id: String { "\(recordID):\(origin)" }
}

enum RecordDeepLinkFailure: Identifiable, Equatable, Sendable {
    case notFound(recordID: String)
    case forbidden(recordID: String)
    case deleted(recordID: String)

    var id: String {
        switch self {
        case .notFound(let recordID): "not-found:\(recordID)"
        case .forbidden(let recordID): "forbidden:\(recordID)"
        case .deleted(let recordID): "deleted:\(recordID)"
        }
    }

    var title: String {
        switch self {
        case .notFound: "未找到经营事项"
        case .forbidden: "无权查看经营事项"
        case .deleted: "经营事项已删除"
        }
    }

    var message: String {
        switch self {
        case .notFound:
            "当前同步账本中没有这条经营事项。它可能尚未同步，请刷新后重试。"
        case .forbidden:
            "当前账套权限不允许查看这条经营事项，复核筛选和未提交草稿已保留。"
        case .deleted:
            "这条经营事项已不在当前账本中，可能已被其他设备删除。返回后原筛选和草稿仍会保留。"
        }
    }
}

enum RecordDeepLinkResolution: Equatable, Sendable {
    case destination(RecordDeepLinkRoute)
    case failure(RecordDeepLinkFailure)
}

enum RecordDeepLinkResolver {
    static func resolve(
        recordID: String,
        availableRecordIDs: Set<String>,
        canRead: Bool,
        canEdit: Bool,
        origin: RecordDeepLinkOrigin
    ) -> RecordDeepLinkResolution {
        guard canRead else { return .failure(.forbidden(recordID: recordID)) }
        guard availableRecordIDs.contains(recordID) else {
            return .failure(.notFound(recordID: recordID))
        }
        return .destination(RecordDeepLinkRoute(recordID: recordID, origin: origin, canEdit: canEdit))
    }

    static func missingRecordFailure(recordID: String, wasPreviouslyResolved: Bool) -> RecordDeepLinkFailure {
        wasPreviouslyResolved ? .deleted(recordID: recordID) : .notFound(recordID: recordID)
    }
}
