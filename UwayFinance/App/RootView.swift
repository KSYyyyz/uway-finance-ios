import SwiftUI

struct RootView: View {
    @EnvironmentObject private var session: AppSession

    var body: some View {
        Group {
            switch session.phase {
            case .starting:
                ProgressView("正在连接安全账本…")
            case .signedOut:
                LoginView()
            case .signedIn:
                MainTabView()
            }
        }
        .task { await session.start() }
        .animation(.snappy, value: session.phase)
    }
}

