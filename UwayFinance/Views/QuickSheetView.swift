import SwiftUI

struct QuickSheetView: View {
    let destination: QuickSheet

    var body: some View {
        switch destination {
        case .newRecord:
            NewRecordView()
        case .receipt:
            ReservedIntegrationView(
                title: "拍票据",
                symbol: "camera",
                description: "相机与附件上传入口已经预留；后端启用文档与OCR接口后即可接入。",
                endpoints: ["POST /api/documents", "POST /api/documents/:id/upload", "POST /api/documents/:id/ocr"]
            )
        case .importFile:
            RecordImportView()
        }
    }
}

struct ReservedIntegrationView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let symbol: String
    let description: String
    let endpoints: [String]

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                ContentUnavailableView(title, systemImage: symbol, description: Text(description))
                VStack(alignment: .leading, spacing: 8) {
                    Text("预留接口").font(.headline)
                    ForEach(endpoints, id: \.self) { endpoint in
                        Text(endpoint).font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .appCard()
                Spacer()
            }
            .padding()
            .background(AppTheme.pageBackground)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭", systemImage: "xmark") { dismiss() }
                }
            }
        }
    }
}
