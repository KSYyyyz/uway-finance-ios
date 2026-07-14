import SwiftUI

enum AppTab: Hashable { case workbench, ledger, pending, close, profile }

struct MainTabView: View {
    @EnvironmentObject private var session: AppSession
    @State private var selection: AppTab = .workbench
    @State private var showsStateConflictResolution = false

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { WorkbenchView() }
                .tabItem { Label("工作台", systemImage: "house.fill") }
                .tag(AppTab.workbench)

            NavigationStack { LedgerView() }
                .tabItem { Label("账目", systemImage: "list.bullet.rectangle") }
                .tag(AppTab.ledger)

            NavigationStack { PendingView() }
                .tabItem { Label("待处理", systemImage: "tray.full.fill") }
                .badge(session.state.records.pendingItems.count)
                .tag(AppTab.pending)

            NavigationStack { MonthCloseView() }
                .tabItem { Label("月结", systemImage: "checkmark.circle") }
                .tag(AppTab.close)

            NavigationStack { ProfileView() }
                .tabItem { Label("我的", systemImage: "person") }
                .tag(AppTab.profile)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            switch session.syncState {
            case .failed(let message):
                SyncRecoveryBanner(message: message) {
                    Task { await session.recoverSync() }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            case .conflict(let message):
                StateConflictBanner(message: message) {
                    showsStateConflictResolution = true
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            default:
                EmptyView()
            }
        }
        .animation(MotionToken.normal, value: session.syncState)
        .confirmationDialog(
            "其他设备已更新，需要核对",
            isPresented: $showsStateConflictResolution,
            titleVisibility: .visible
        ) {
            Button("保留本机修改并重试", role: .destructive) {
                Task { await session.resolveStateConflictAndRetry() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("继续后会读取服务器最新版本号，再提交本机未同步内容；其他设备的内容不会自动合并。")
        }
    }
}
