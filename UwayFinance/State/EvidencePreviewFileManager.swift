import Foundation

enum EvidencePreviewFileManager {
    private static let prefix = "uway-evidence-"

    static func write(_ content: BusinessRecordEvidenceContent) throws -> URL {
        let safeName = content.fileName
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)\(content.evidenceId)-\(safeName)")
        try content.data.write(to: url, options: [.atomic])
        return url
    }

    static func remove(_ url: URL?) {
        guard let url, url.lastPathComponent.hasPrefix(prefix) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    static func clearAll() {
        let directory = FileManager.default.temporaryDirectory
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        for file in files where file.lastPathComponent.hasPrefix(prefix) {
            try? FileManager.default.removeItem(at: file)
        }
    }
}
