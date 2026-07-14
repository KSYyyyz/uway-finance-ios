import SwiftUI

@MainActor
struct ClassificationReviewView: View {
    @EnvironmentObject private var session: AppSession
    @StateObject private var store: ClassificationReviewStore

    init(api: any ClassificationReviewAPI) {
        _store = StateObject(wrappedValue: ClassificationReviewStore(api: api))
    }

    private var reviewAvailable: Bool {
        guard case .available(let contract) = session.serverState else { return false }
        return contract.capabilities.classificationReview?.available == true
    }

    private var aiAvailable: Bool {
        guard case .available(let contract) = session.serverState else { return false }
        let ai = contract.capabilities.aiClassificationCapability
        return ai.available
            && ai.contract == "closed_set_existing_operating_item_v1"
            && ai.modelCanAccept == false
            && ai.writesBusinessRecords == false
            && contract.capabilities.safety.aiMayWriteBusinessRecords == false
    }

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            if !reviewAvailable {
                ContentUnavailableView(
                    "分类复核暂不可用",
                    systemImage: "checkmark.bubble",
                    description: Text("当前服务器尚未公布分类复核能力。")
                )
            } else if store.isLoading, store.items.isEmpty {
                ProgressView("正在恢复复核队列…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                reviewList
            }
        }
        .background(AppTheme.pageBackground)
        .navigationTitle("分类复核")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .task {
            guard reviewAvailable else { return }
            await store.restoreSession()
        }
        .sensoryFeedback(.success, trigger: store.successTrigger)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageBrief(
                title: "经营事项分类复核",
                subtitle: "AI 只给建议，正式分类必须遵循强规则或人工决定"
            )
            Picker("复核状态", selection: Binding(
                get: { store.selectedState },
                set: { state in Task { await store.changeState(state) } }
            )) {
                ForEach(ClassificationReviewState.allCases) { state in
                    Text(state.label).tag(state)
                }
            }
            .pickerStyle(.segmented)

            if let message = store.message {
                Label(message, systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.compactRadius))
                    .accessibilityLabel("复核状态：\(message)")
            }
        }
        .padding()
        .background(AppTheme.pageBackground)
    }

    private var reviewList: some View {
        List {
            if store.items.isEmpty {
                ContentUnavailableView("当前没有复核事项", systemImage: "checkmark.circle")
                    .listRowBackground(Color.clear)
            } else {
                ForEach(store.items) { item in
                    ClassificationReviewRow(
                        item: item,
                        taxonomy: store.taxonomy.filter { $0.direction == item.record.direction },
                        draft: store.drafts[item.id] ?? ClassificationReviewDraft(),
                        analysis: store.analyses[item.id],
                        isBusy: store.busyRecordIDs.contains(item.id),
                        aiAvailable: aiAvailable,
                        setAction: { store.setAction($0, for: item.id) },
                        setReason: { store.setReason($0, for: item.id) },
                        setTaxonomy: { store.setTaxonomyCode($0, for: item.id) },
                        setNormalizedName: { store.setNormalizedItemName($0, for: item.id) },
                        analyze: { Task { await store.analyze(item, aiAvailable: aiAvailable) } },
                        submit: { Task { await store.submitDecision(item) } }
                    )
                    .listRowInsets(EdgeInsets(top: 7, leading: 16, bottom: 7, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }

            HStack {
                Button("上一页", systemImage: "chevron.left") {
                    Task { await store.previousPage() }
                }
                .disabled(!store.canGoBack || store.isLoading)
                Spacer()
                Text("每页最多 10 条")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("下一页", systemImage: "chevron.right") {
                    Task { await store.nextPage() }
                }
                .labelStyle(.titleAndIcon)
                .disabled(store.nextCursor == nil || store.isLoading)
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable { await store.refresh() }
    }
}

private struct ClassificationReviewRow: View {
    let item: ClassificationReviewItem
    let taxonomy: [ClassificationTaxonomyItem]
    let draft: ClassificationReviewDraft
    let analysis: ClassificationAnalysisResult?
    let isBusy: Bool
    let aiAvailable: Bool
    let setAction: (ClassificationDecisionAction) -> Void
    let setReason: (String) -> Void
    let setTaxonomy: (String?) -> Void
    let setNormalizedName: (String) -> Void
    let analyze: () -> Void
    let submit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            recordHeader
            proposalCard
            if let analysis { analysisCard(analysis) }
            if !item.allowedActions.isEmpty { actionControls }
        }
        .appCard()
        .accessibilityElement(children: .contain)
    }

    private var recordHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.record.counterparty.isEmpty ? "未填写交易对方" : item.record.counterparty)
                    .font(.headline)
                Spacer()
                Text("¥\(item.record.amount.value.decimalString)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(item.record.direction == .income ? AppTheme.brand : .primary)
            }
            Text("\(item.record.eventDate) · \(item.record.category)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(item.record.description.isEmpty ? "无事项说明" : item.record.description)
                .font(.subheadline)
        }
    }

    private var proposalCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label(item.proposal.taxonomyName, systemImage: proposalSymbol)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(proposalStateLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(proposalColor)
            }
            Text(item.proposal.normalizedItemName)
                .font(.footnote)
            Text("来源：\(item.proposal.origin) · 依据：\(item.proposal.reasonCode)")
                .font(.caption)
                .foregroundStyle(.secondary)
            if item.proposal.stale {
                Label("源事实已变化，必须按服务端当前版本重新复核", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(AppTheme.warning)
            }
        }
        .padding(11)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.compactRadius))
    }

    private func analysisCard(_ analysis: ClassificationAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(analysisStatusLabel(analysis.status), systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))
            Text("\(analysis.taxonomyCode ?? "未形成分类") · \(analysis.reasonCode)")
                .font(.footnote)
            if !analysis.issueCodes.isEmpty {
                Text(analysis.issueCodes.joined(separator: "、"))
                    .font(.caption)
                    .foregroundStyle(AppTheme.danger)
            }
            Text("模型不能自动确认，也没有改写原始经营事项。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(11)
        .background(AppTheme.brand.opacity(0.08), in: RoundedRectangle(cornerRadius: AppTheme.compactRadius))
    }

    private var actionControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(aiAvailable ? "生成 AI 建议" : "AI 暂不可用", systemImage: "sparkles") {
                analyze()
            }
            .buttonStyle(.bordered)
            .disabled(isBusy || !aiAvailable)

            Picker("人工决定", selection: Binding(get: { draft.action }, set: setAction)) {
                ForEach(ClassificationDecisionAction.allCases) { action in
                    Text(action.label).tag(action)
                }
            }
            .pickerStyle(.segmented)

            if draft.action != .reject {
                Picker("闭集分类", selection: Binding(get: { draft.taxonomyCode }, set: setTaxonomy)) {
                    Text("请选择").tag(String?.none)
                    ForEach(taxonomy) { option in
                        Text(option.name).tag(String?.some(option.code))
                    }
                }
                TextField(
                    "规范化归并名称",
                    text: Binding(get: { draft.normalizedItemName }, set: setNormalizedName)
                )
                .textFieldStyle(.roundedBorder)
            }

            TextField("复核理由（必填）", text: Binding(get: { draft.reason }, set: setReason), axis: .vertical)
                .lineLimit(2...5)
                .textFieldStyle(.roundedBorder)

            Button(draft.action.label, systemImage: "checkmark.shield") {
                submit()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isBusy)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var proposalSymbol: String {
        switch item.reviewState {
        case .pending: "questionmark.circle"
        case .accepted: "checkmark.circle.fill"
        case .rejected: "xmark.circle.fill"
        }
    }

    private var proposalStateLabel: String { item.reviewState.label }
    private var proposalColor: Color {
        switch item.reviewState {
        case .pending: AppTheme.warning
        case .accepted: AppTheme.brand
        case .rejected: AppTheme.danger
        }
    }

    private func analysisStatusLabel(_ status: ClassificationAnalysisStatus) -> String {
        switch status {
        case .accepted: "强规则已接受"
        case .review: "AI 建议待人工确认"
        case .rejected: "Harness 已失败关闭"
        }
    }
}
