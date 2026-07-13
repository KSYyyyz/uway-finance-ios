import SwiftUI

struct PageBrief: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct SyncStatusLabel: View {
    let state: AppSession.SyncState

    var body: some View {
        HStack(spacing: 5) {
            switch state {
            case .idle:
                Image(systemName: "icloud")
                Text("等待同步")
            case .syncing:
                ProgressView().controlSize(.mini)
                Text("同步中")
            case .synced(let date):
                Image(systemName: "checkmark.circle.fill")
                Text("已同步 \(date.formatted(date: .omitted, time: .shortened))")
            case .failed:
                Image(systemName: "icloud.slash.fill")
                Text("同步失败")
            }
        }
        .font(.caption)
        .foregroundStyle(state.isFailure ? AppTheme.danger : .secondary)
    }
}

private extension AppSession.SyncState {
    var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }
}
