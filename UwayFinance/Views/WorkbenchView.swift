import SwiftUI

struct WorkbenchView: View {
    @EnvironmentObject private var session: AppSession
    @State private var sheet: QuickSheet?

    private var settledRecords: [BusinessRecord] {
        session.state.records.filter { $0.settlementStatus == .settled }
    }

    private var cashBalance: Double {
        settledRecords.reduce(0) { $0 + ($1.direction == .income ? $1.amount : -$1.amount) }
    }

    private var currentMonthRecords: [BusinessRecord] {
        let month = String(FinanceFormat.dateString(from: Date()).prefix(7))
        return session.state.records.filter { $0.date.hasPrefix(month) }
    }

    private var canEditRecords: Bool {
        guard case .available(let contract) = session.serverState else { return false }
        return contract.capabilities.legacyState.writable
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                header
                NavigationLink {
                    ForecastView()
                } label: {
                    fundsCard
                }
                .buttonStyle(.plain)
                workbenchTasks
                recentActivity
            }
            .padding()
        }
        .appScrollIndicatorsHidden()
        .background(AppTheme.pageBackground)
        .refreshable {
            try? await session.refresh()
        }
        .sheet(item: $sheet) { QuickSheetView(destination: $0) }
        .navigationBarHidden(true)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("杭州恒之舟科技有限公司")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("今天先处理什么")
                    .font(.title2.weight(.semibold))
                SyncStatusLabel(state: session.syncState)
            }
            Spacer()
            QuickActionMenu(sheet: $sheet)
        }
    }

    private var fundsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("资金概况", systemImage: "creditcard")
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            Text(FinanceFormat.currency(cashBalance))
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
            HStack(spacing: 20) {
                metric("本月收入", value: currentMonthRecords.filter { $0.direction == .income }.reduce(0) { $0 + $1.amount })
                metric("本月支出", value: currentMonthRecords.filter { $0.direction == .expense }.reduce(0) { $0 + $1.amount })
            }
            Text("查看7/30/90天资金预测")
                .font(.caption)
                .foregroundStyle(AppTheme.brand)
        }
        .appCard()
        .accessibilityElement(children: .combine)
    }

    private func metric(_ title: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(FinanceFormat.currency(value)).font(.subheadline.weight(.semibold)).monospacedDigit()
        }
    }

    private var workbenchTasks: some View {
        let items = session.state.records.pendingItems
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("待处理").font(.headline)
                Text("\(items.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(AppTheme.brand, in: Capsule())
                Spacer()
            }
            if items.isEmpty {
                Label("当前没有需要优先处理的事项", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.brand)
            } else {
                ForEach(items.prefix(3)) { item in
                    NavigationLink {
                        RecordDetailView(route: RecordDeepLinkRoute(
                            recordID: item.recordId,
                            origin: .workbench,
                            canEdit: canEditRecords
                        ))
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: item.severity == .high ? "exclamationmark.circle.fill" : "clock.fill")
                                .foregroundStyle(item.severity == .high ? AppTheme.danger : AppTheme.warning)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title).font(.subheadline.weight(.semibold))
                                Text(item.detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("直接打开对应经营事项")
                }
            }
        }
        .appCard()
    }

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("最近动态")
                .font(.headline)
                .padding(.bottom, 8)
            if session.state.records.isEmpty {
                ContentUnavailableView("还没有账目", systemImage: "tray", description: Text("点击右上角加号记一笔"))
                    .frame(minHeight: 170)
            } else {
                ForEach(session.state.records.sorted { $0.date > $1.date }.prefix(4)) { record in
                    NavigationLink {
                        RecordDetailView(route: RecordDeepLinkRoute(
                            recordID: record.id,
                            origin: .workbench,
                            canEdit: canEditRecords
                        ))
                    } label: {
                        RecordRow(record: record)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    if record.id != session.state.records.sorted(by: { $0.date > $1.date }).prefix(4).last?.id {
                        Divider()
                    }
                }
            }
        }
        .appCard()
    }
}
