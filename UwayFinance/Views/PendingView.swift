import SwiftUI

private enum PendingFilter: String, CaseIterable, Identifiable {
    case all, high, settlement, material
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: "全部"
        case .high: "高风险"
        case .settlement: "收付款"
        case .material: "材料"
        }
    }
}

struct PendingView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.classificationReviewAPI) private var classificationReviewAPI
    @State private var filter: PendingFilter = .all
    @State private var resolvedTrigger = 0
    @State private var recordRoute: RecordDeepLinkRoute?
    @State private var deepLinkFailure: RecordDeepLinkFailure?

    private var allItems: [PendingItem] { session.state.records.pendingItems }
    private var visibleItems: [PendingItem] {
        allItems.filter { item in
            switch filter {
            case .all: true
            case .high: item.severity == .high
            case .settlement: item.kind == .settlement || item.kind == .reconciliation
            case .material: item.kind == .material
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            fixedSummary
            Divider()
            List {
                if visibleItems.isEmpty {
                    ContentUnavailableView("当前没有这一类待办", systemImage: "checkmark.circle")
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(visibleItems) { item in
                        PendingRow(item: item) {
                            openRecord(item)
                        } resolve: {
                            withAnimation(MotionToken.normal) { session.resolve(item) }
                            resolvedTrigger += 1
                        }
                        .listRowInsets(EdgeInsets(top: 7, leading: 16, bottom: 7, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .appScrollIndicatorsHidden()
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .refreshable { try? await session.refresh() }
        }
        .background(AppTheme.pageBackground)
        .navigationBarHidden(true)
        .navigationDestination(item: $recordRoute) { route in
            RecordDetailView(route: route)
        }
        .alert(item: $deepLinkFailure) { failure in
            Alert(
                title: Text(failure.title),
                message: Text(failure.message),
                dismissButton: .default(Text("知道了"))
            )
        }
        .sensoryFeedback(.success, trigger: resolvedTrigger)
    }

    private func openRecord(_ item: PendingItem) {
        let canEdit: Bool = {
            guard case .available(let contract) = session.serverState else { return false }
            return contract.capabilities.legacyState.writable
        }()
        let resolution = RecordDeepLinkResolver.resolve(
            recordID: item.recordId,
            availableRecordIDs: Set(session.state.records.map(\.id)),
            canRead: true,
            canEdit: canEdit,
            origin: .pending(filter: filter.rawValue)
        )
        switch resolution {
        case .destination(let route): recordRoute = route
        case .failure(let failure): deepLinkFailure = failure
        }
    }

    private var fixedSummary: some View {
        VStack(spacing: 12) {
            PageBrief(
                title: "待处理经营事项",
                subtitle: "\(allItems.count)项待办，其中\(allItems.filter { $0.severity == .high }.count)项会影响现金或月结"
            )
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("当前待处理").font(.caption).foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(allItems.count)").font(.largeTitle.weight(.semibold)).contentTransition(.numericText())
                        Text("项").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .leading, spacing: 7) {
                    Label("高风险 \(allItems.filter { $0.severity == .high }.count)", systemImage: "circle.fill")
                        .foregroundStyle(AppTheme.danger)
                    Label("需关注 \(allItems.filter { $0.severity == .medium }.count)", systemImage: "circle.fill")
                        .foregroundStyle(AppTheme.warning)
                }
                .font(.caption)
            }
            .foregroundStyle(.white)
            .padding()
            .background(Color("BrandGreen"), in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))

            Picker("待办筛选", selection: $filter) {
                ForEach(PendingFilter.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)

            NavigationLink {
                ClassificationReviewView(api: classificationReviewAPI)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.bubble")
                        .foregroundStyle(AppTheme.brand)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("分类复核工作台").font(.subheadline.weight(.semibold))
                        Text("AI 建议、人工确认、更正与拒绝").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                }
                .padding(12)
                .background(AppTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: AppTheme.compactRadius))
            }
            .buttonStyle(.plain)
            .accessibilityHint("打开经营事项分类复核队列")
        }
        .padding()
        .background(AppTheme.pageBackground)
    }
}

private struct PendingRow: View {
    let item: PendingItem
    let openRecord: () -> Void
    let resolve: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(item.severity == .high ? "高" : "中")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(item.severity == .high ? AppTheme.danger : AppTheme.warning)
                    .padding(7)
                    .background((item.severity == .high ? AppTheme.danger : AppTheme.warning).opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title).font(.headline)
                    Text(item.detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    openRecord()
                } label: {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                        .padding(8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("查看对应经营事项")
                .accessibilityHint("保留当前筛选条件并打开账目详情")
            }
            Text(item.action)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 9))
            HStack {
                Spacer()
                Button("标记已处理", systemImage: "checkmark") { resolve() }
                    .buttonStyle(.bordered)
            }
        }
        .appCard()
    }
}
