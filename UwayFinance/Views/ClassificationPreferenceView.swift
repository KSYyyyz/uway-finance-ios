import SwiftUI

@MainActor
struct ClassificationPreferenceView: View {
    @StateObject private var store: ClassificationPreferenceStore
    let accountBook: FinanceAccountBookAccess
    @State private var revokeTarget: ClassificationPreferenceObservation?

    init(api: any ClassificationPreferenceAPI, accountBook: FinanceAccountBookAccess) {
        _store = StateObject(wrappedValue: ClassificationPreferenceStore(api: api))
        self.accountBook = accountBook
    }

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            preferenceList
        }
        .background(AppTheme.pageBackground)
        .navigationTitle("分类学习记录")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: accountBook.id) { await store.restore(accountBook: accountBook) }
        .sheet(item: $revokeTarget) { observation in
            PreferenceRevokeView(store: store, observation: observation)
        }
        .sensoryFeedback(.success, trigger: store.successTrigger)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageBrief(
                title: "账套级分类记忆",
                subtitle: "只来自已认证人工决定，仅重排闭集候选，不改写经营事项"
            )
            Picker("学习记录状态", selection: Binding(
                get: { store.selectedState },
                set: { state in Task { await store.changeState(state) } }
            )) {
                ForEach(ClassificationPreferenceListState.allCases) { state in
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
            }
        }
        .padding()
        .background(AppTheme.pageBackground)
    }

    private var preferenceList: some View {
        List {
            if store.isLoading, store.items.isEmpty {
                ProgressView("正在读取当前账套的学习记录…")
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            } else if store.items.isEmpty {
                ContentUnavailableView("当前没有学习记录", systemImage: "brain.head.profile")
                    .listRowBackground(Color.clear)
            } else {
                ForEach(store.items) { observation in
                    ClassificationPreferenceRow(
                        observation: observation,
                        canRevoke: accountBook.permissions.writeBusinessRecords
                            && observation.lifecycle.state == .active,
                        isBusy: store.busyObservationIDs.contains(observation.id),
                        revoke: {
                            if store.revokeDrafts[observation.id] == nil {
                                store.setRevokeReason("", for: observation.id)
                            }
                            revokeTarget = observation
                        }
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
                Text("每页最多 10 条").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("下一页", systemImage: "chevron.right") {
                    Task { await store.nextPage() }
                }
                .disabled(store.nextCursor == nil || store.isLoading)
            }
            .listRowBackground(Color.clear)
        }
        .appScrollIndicatorsHidden()
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable { await store.refresh() }
    }
}

private struct ClassificationPreferenceRow: View {
    let observation: ClassificationPreferenceObservation
    let canRevoke: Bool
    let isBusy: Bool
    let revoke: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(observation.lifecycle.state.label, systemImage: lifecycleSymbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(lifecycleColor)
                Spacer()
                Text("版本 \(observation.version)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(observation.decision.taxonomyCode ?? "拒绝旧分类建议")
                .font(.headline)
            Text(featureSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Label(observation.decision.action.label, systemImage: "person.crop.circle.badge.checkmark")
                if observation.lastUsedAt != nil {
                    Label("曾用于候选排序", systemImage: "arrow.up.arrow.down")
                }
            }
            .font(.caption)
            if let reason = observation.lifecycle.reason, !reason.isEmpty {
                Text(reason).font(.caption).foregroundStyle(.secondary)
            }
            if canRevoke {
                Button("撤销这条学习记录", systemImage: "arrow.uturn.backward.circle", role: .destructive) {
                    revoke()
                }
                .buttonStyle(.bordered)
                .disabled(isBusy)
            }
        }
        .appCard()
        .accessibilityElement(children: .contain)
    }

    private var featureSummary: String {
        let tokens = observation.features.serviceTokens
            + observation.features.itemTokens
            + observation.features.merchantTokens
        return tokens.isEmpty ? "已脱敏的账套分类特征" : tokens.prefix(3).joined(separator: " · ")
    }

    private var lifecycleSymbol: String {
        switch observation.lifecycle.state {
        case .active: "checkmark.circle.fill"
        case .revoked: "arrow.uturn.backward.circle"
        case .invalidated: "exclamationmark.circle"
        }
    }

    private var lifecycleColor: Color {
        switch observation.lifecycle.state {
        case .active: AppTheme.brand
        case .revoked: .secondary
        case .invalidated: AppTheme.warning
        }
    }
}

private struct PreferenceRevokeView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: ClassificationPreferenceStore
    let observation: ClassificationPreferenceObservation
    @State private var isSubmitting = false

    private var reason: Binding<String> {
        Binding(
            get: { store.revokeDrafts[observation.id] ?? "" },
            set: { store.setRevokeReason($0, for: observation.id) }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("撤销影响") {
                    Text("服务端会从剩余 active 人工决定重算账套记忆；不会修改原始经营事项或凭证。")
                        .font(.footnote)
                }
                Section("撤销理由") {
                    TextEditor(text: reason)
                        .appScrollIndicatorsHidden()
                        .frame(minHeight: 120)
                    Text("至少 2 个字，理由会由服务端与当前登录人写入审计记录。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let message = store.message {
                    Section { Text(message).foregroundStyle(AppTheme.warning) }
                }
            }
            .appScrollIndicatorsHidden()
            .navigationTitle("撤销学习记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.disabled(isSubmitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认撤销", role: .destructive) {
                        Task {
                            isSubmitting = true
                            let succeeded = await store.revoke(observation)
                            isSubmitting = false
                            if succeeded { dismiss() }
                        }
                    }
                    .disabled(isSubmitting || reason.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
                }
            }
        }
        .interactiveDismissDisabled(isSubmitting)
    }
}
