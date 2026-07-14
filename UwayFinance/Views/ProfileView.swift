import Foundation
import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var session: AppSession
    @State private var privacyMode = false
    @State private var notificationsEnabled = false

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 5) {
                    PageBrief(title: "账户与安全", subtitle: "公司、同步和本机隐私设置")
                    Text(session.user?.username ?? "未登录")
                        .font(.headline)
                }
                .padding(.vertical, 6)
            }

            Section("本机保护") {
                Toggle(isOn: $privacyMode) { Label("金额隐私模式", systemImage: "eye.slash") }
                Toggle(isOn: $notificationsEnabled) { Label("经营事项提醒", systemImage: "bell") }
                LabeledContent("Face ID", value: "协议已预留")
            }

            Section("服务连接") {
                LabeledContent("阿里云服务") { ServerStatusLabel(state: session.serverState) }
                LabeledContent("账本同步") { SyncStatusLabel(state: session.syncState) }
                if case .available(let contract) = session.serverState {
                    LabeledContent("服务应用版本", value: contract.serverVersion)
                    LabeledContent("财务数据库版本", value: contract.financeSchemaDisplay)
                    LabeledContent("API 契约版本", value: contract.apiContractDisplay)
                    LabeledContent("当前同步模式", value: contract.capabilities.syncMode.displayName)
                    LabeledContent(
                        "V2 资源接口",
                        value: contract.capabilities.financeResourceAPI ? "已开放" : "尚未开放"
                    )
                    LabeledContent("导入分析", value: contract.capabilities.importAnalysis.statusDisplay)
                }
                LabeledContent("OCR与附件", value: "等待后端")
                Button("检查服务与同步", systemImage: "arrow.clockwise") {
                    Task {
                        await session.checkServer()
                        guard case .available = session.serverState else { return }
                        await session.recoverSync()
                    }
                }
            }

            Section("关于") {
                LabeledContent("客户端版本", value: appVersion)
            }

            Section {
                Button("退出登录", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                    Task { await session.logout() }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationBarHidden(true)
    }
}
