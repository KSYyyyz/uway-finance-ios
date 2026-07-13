import SwiftUI

enum QuickSheet: String, Identifiable {
    case newRecord, receipt, importFile
    var id: String { rawValue }
}

struct QuickActionMenu: View {
    @Binding var sheet: QuickSheet?

    var body: some View {
        Menu {
            Button("记一笔", systemImage: "square.and.pencil") { sheet = .newRecord }
            Button("拍票据", systemImage: "camera") { sheet = .receipt }
            Button("导入流水", systemImage: "square.and.arrow.down") { sheet = .importFile }
        } label: {
            Image(systemName: "plus")
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.circle)
        .controlSize(.large)
        .accessibilityLabel("快捷新增")
    }
}

