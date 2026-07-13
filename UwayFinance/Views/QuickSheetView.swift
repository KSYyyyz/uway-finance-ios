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
            ReservedIntegrationView(
                title: "导入流水",
                symbol: "square.and.arrow.down",
                description: "主线分析接口已经连接；文件选择、逐行标准化和公司归属证据确认界面将在下一阶段接入，分析结果不会直接写正式账目。",
                endpoints: ["POST /api/import-analysis", "POST /api/import-analysis/:analysisId/decision"]
            )
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
