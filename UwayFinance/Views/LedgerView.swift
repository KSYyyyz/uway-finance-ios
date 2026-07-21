import SwiftUI

private enum LedgerFilter: String, CaseIterable, Identifiable {
    case all, unsettled, materials, unmatched
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: "全部"
        case .unsettled: "待收付"
        case .materials: "缺材料"
        case .unmatched: "未核对"
        }
    }
}

private enum LedgerPeriod: String, CaseIterable, Identifiable {
    case all, month, lastMonth, year
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: "全部时间"
        case .month: "本月"
        case .lastMonth: "上月"
        case .year: "本年"
        }
    }
}

struct LedgerView: View {
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var evidenceCoverageStore: BusinessRecordEvidenceCoverageStore
    @Environment(\.businessRecordEvidenceAPI) private var evidenceAPI
    @State private var filter: LedgerFilter = .all
    @State private var period: LedgerPeriod = .all
    @State private var query = ""
    @State private var searchVisible = false
    @State private var sheet: QuickSheet?
    @State private var evidenceRoute: LedgerEvidenceRoute?

    private var filteredRecords: [BusinessRecord] {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let currentMonth = String(FinanceFormat.dateString(from: now).prefix(7))
        let previousDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        let previousMonth = String(FinanceFormat.dateString(from: previousDate).prefix(7))
        let currentYear = String(FinanceFormat.dateString(from: now).prefix(4))

        return session.state.records.filter { record in
            let matchesPeriod: Bool = switch period {
            case .all: true
            case .month: record.date.hasPrefix(currentMonth)
            case .lastMonth: record.date.hasPrefix(previousMonth)
            case .year: record.date.hasPrefix(currentYear)
            }
            let matchesFilter: Bool = switch filter {
            case .all: true
            case .unsettled: record.settlementStatus == .unsettled
            case .materials:
                if let evidence = evidenceCoverageStore.coverage(for: record.id),
                   evidence.requirementState != nil {
                    evidence.isRequiredMissing
                } else {
                    record.invoiceStatus == .pending || record.contractStatus == .missing || record.supportingDocumentStatus == .pending
                }
            case .unmatched: record.settlementStatus == .settled && record.bankReference == nil
            }
            let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let haystack = "\(record.counterparty) \(record.project) \(record.description) \(record.amount)".lowercased()
            return matchesPeriod && matchesFilter && (normalized.isEmpty || haystack.contains(normalized))
        }
        .businessDateDescendingStable
    }

    private var income: Double { filteredRecords.filter { $0.direction == .income }.reduce(0) { $0 + $1.amount } }
    private var expense: Double { filteredRecords.filter { $0.direction == .expense }.reduce(0) { $0 + $1.amount } }

    private var canEditRecords: Bool {
        guard case .available(let contract) = session.serverState else { return false }
        return contract.capabilities.legacyState.writable
    }

    var body: some View {
        VStack(spacing: 0) {
            fixedControls
            Divider()
            ledgerScroll
        }
        .background(AppTheme.pageBackground)
        .navigationBarHidden(true)
        .sheet(item: $sheet) { QuickSheetView(destination: $0) }
        .sheet(item: $evidenceRoute) { route in
            NavigationStack {
                ScrollView {
                    BusinessRecordEvidenceView(
                        api: evidenceAPI,
                        recordExternalId: route.recordID,
                        maximumBytes: 10_000_000,
                        autoPreviewFirstSupported: true
                    )
                    .padding()
                }
                .appScrollIndicatorsHidden()
                .navigationTitle(route.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("关闭") { evidenceRoute = nil }
                    }
                }
            }
        }
        .task(id: evidenceLoadTaskID) {
            guard documentUploadAvailable else {
                evidenceCoverageStore.clear()
                return
            }
            await evidenceCoverageStore.load(userID: session.user?.id)
        }
    }

    private var fixedControls: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                PageBrief(title: "收支与凭证状态", subtitle: "按日期查总账、收付款和凭证状态")
                Button {
                    withAnimation(MotionToken.fast) { searchVisible.toggle() }
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(.borderless)
                .controlSize(.large)
                .accessibilityLabel("搜索账目")
                QuickActionMenu(sheet: $sheet)
            }

            if searchVisible {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("搜索对方、项目、事项或金额", text: $query)
                        .textInputAutocapitalization(.never)
                    Button("关闭", systemImage: "xmark.circle.fill") {
                        query = ""
                        withAnimation(MotionToken.fast) { searchVisible = false }
                    }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(AppTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: AppTheme.compactRadius, style: .continuous))
            }

            HStack {
                Menu {
                    Picker("账目期间", selection: $period) {
                        ForEach(LedgerPeriod.allCases) { Text($0.label).tag($0) }
                    }
                } label: {
                    Label(period.label, systemImage: "calendar")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.bordered)
                Spacer()
                Text("\(filteredRecords.count)笔账目")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Picker("账目状态", selection: $filter) {
                ForEach(LedgerFilter.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 0) {
                summaryMetric("收入", income, color: AppTheme.brand)
                Rectangle().fill(AppTheme.separator).frame(width: 0.5, height: 38)
                summaryMetric("支出", expense, color: .primary)
                Rectangle().fill(AppTheme.separator).frame(width: 0.5, height: 38)
                summaryMetric("净额", income - expense, color: income - expense >= 0 ? AppTheme.brand : AppTheme.danger, signed: true)
            }
            .appCard(padding: 12)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(AppTheme.pageBackground)
    }

    private func summaryMetric(_ title: String, _ value: Double, color: Color, signed: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text("\(signed && value > 0 ? "+" : "")\(FinanceFormat.currency(value))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
    }

    private var ledgerScroll: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                if case .failed = evidenceCoverageStore.loadState {
                    Label("材料覆盖状态读取失败，当前不显示“材料齐全”结论。", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(AppTheme.warning)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if filteredRecords.isEmpty {
                    ContentUnavailableView("没有符合条件的账目", systemImage: "doc.text.magnifyingglass")
                        .frame(minHeight: 300)
                } else {
                    ForEach(filteredRecords.ledgerGroups) { month in
                        VStack(spacing: 9) {
                            HStack {
                                Text(FinanceFormat.monthTitle(month.month)).font(.headline)
                                Spacer()
                                Text("收 \(FinanceFormat.currency(month.income, digits: 0)) · 支 \(FinanceFormat.currency(month.expense, digits: 0))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            ForEach(month.days) { day in
                                VStack(spacing: 0) {
                                    HStack {
                                        Text(FinanceFormat.dayTitle(day.date)).font(.caption.weight(.semibold))
                                        Spacer()
                                        Text("收 \(FinanceFormat.currency(day.income, digits: 0)) · 支 \(FinanceFormat.currency(day.expense, digits: 0))")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 9)
                                    ForEach(day.records.indices, id: \.self) { index in
                                        let record = day.records[index]
                                        if index > 0 { Divider().padding(.leading, 56) }
                                        VStack(spacing: 0) {
                                            NavigationLink {
                                                RecordDetailView(route: RecordDeepLinkRoute(
                                                    recordID: record.id,
                                                    origin: .ledger,
                                                    canEdit: canEditRecords
                                                ))
                                            } label: {
                                                RecordRow(
                                                    record: record,
                                                    evidenceCoverage: evidenceCoverageStore.coverage(for: record.id)
                                                )
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 10)
                                            }
                                            .buttonStyle(.plain)
                                            .accessibilityHint("打开经营事项详情")

                                            if let coverage = evidenceCoverageStore.coverage(for: record.id),
                                               coverage.activeEvidenceCount > 0 {
                                                Button("查看附件（\(coverage.activeEvidenceCount)）", systemImage: "paperclip") {
                                                    evidenceRoute = LedgerEvidenceRoute(
                                                        recordID: record.id,
                                                        title: record.counterparty.isEmpty ? "事项附件" : record.counterparty
                                                    )
                                                }
                                                .font(.caption.weight(.medium))
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.horizontal, 12)
                                                .padding(.bottom, 10)
                                                .accessibilityHint("直接加载并预览有效附件")
                                            }
                                        }
                                    }
                                }
                                .background(AppTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                                        .stroke(AppTheme.separator.opacity(0.5), lineWidth: 0.5)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .appScrollIndicatorsHidden()
        .refreshable {
            try? await session.refresh()
            if documentUploadAvailable {
                await evidenceCoverageStore.load(userID: session.user?.id, force: true)
            }
        }
    }

    private var documentUploadAvailable: Bool {
        guard case .available(let contract) = session.serverState else { return false }
        return contract.capabilities.documentUploadCapability.safeForClientUse
    }

    private var evidenceLoadTaskID: String {
        "\(session.user?.id ?? "signed-out"):\(documentUploadAvailable)"
    }
}

private struct LedgerEvidenceRoute: Identifiable {
    let recordID: String
    let title: String
    var id: String { recordID }
}
