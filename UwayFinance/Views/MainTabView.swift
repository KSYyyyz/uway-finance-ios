import SwiftUI

enum AppTab: Hashable { case workbench, ledger, pending, close, profile }

struct MainTabView: View {
    @EnvironmentObject private var session: AppSession
    @State private var selection: AppTab = .workbench

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
    }
}

