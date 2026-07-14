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
        .accessibilityElement(children: .contain)
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

struct ServerStatusLabel: View {
    let state: AppSession.ServerState

    var body: some View {
        HStack(spacing: 5) {
            switch state {
            case .checking:
                ProgressView().controlSize(.mini)
                Text("检查中")
            case .available(let contract):
                Image(systemName: "checkmark.circle.fill")
                Text("服务正常 · v\(contract.serverVersion)")
            case .unavailable:
                Image(systemName: "exclamationmark.triangle.fill")
                Text("暂时无法连接")
            }
        }
        .font(.caption)
        .foregroundStyle(state.isUnavailable ? AppTheme.danger : .secondary)
    }
}

struct SyncRecoveryBanner: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "icloud.slash.fill")
                .foregroundStyle(AppTheme.danger)
            Text(message)
                .font(.caption)
                .lineLimit(2)
            Spacer(minLength: 8)
            Button("重试", action: retry)
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) { Divider() }
        .accessibilityElement(children: .combine)
    }
}

private extension AppSession.SyncState {
    var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }
}

private extension AppSession.ServerState {
    var isUnavailable: Bool {
        if case .unavailable = self { return true }
        return false
    }
}
