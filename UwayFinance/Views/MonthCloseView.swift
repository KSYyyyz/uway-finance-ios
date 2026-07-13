import SwiftUI

struct CloseChecklistItem: Identifiable {
    let id: String
    let title: String
    let note: String
    let group: String
}

private let closeChecklist: [CloseChecklistItem] = [
    .init(id: "C-1", title: "核对公司账户流水", note: "确认本月所有收付款均已登记", group: "由我完成"),
    .init(id: "C-2", title: "补齐发票与合同", note: "处理待办中的材料缺口", group: "由我完成"),
    .init(id: "C-3", title: "确认股东与员工垫付", note: "标清垫付人和归还状态", group: "由我完成"),
    .init(id: "C-4", title: "提交本月代账资料包", note: "按约定日期一次性交接", group: "由我完成"),
    .init(id: "C-5", title: "确认资料缺口", note: "请代账反馈仍缺哪些材料", group: "与代账共同确认"),
    .init(id: "C-6", title: "确认完成账务处理", note: "保留代账完成确认", group: "与代账共同确认"),
    .init(id: "C-7", title: "保存申报结果", note: "申报截图与缴款凭证归档", group: "与代账共同确认"),
    .init(id: "C-8", title: "收取月度财务报表", note: "保存资产负债表和利润表", group: "与代账共同确认")
]

struct MonthCloseView: View {
    @EnvironmentObject private var session: AppSession

    private var completedCount: Int { closeChecklist.filter { session.state.completedClose.contains($0.id) }.count }
    private var progress: Double { closeChecklist.isEmpty ? 0 : Double(completedCount) / Double(closeChecklist.count) }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                PageBrief(title: "月度交接项目确认", subtitle: "把业务事实和材料一次交清，减少反复沟通")
                HStack(spacing: 16) {
                    ZStack {
                        Circle().stroke(Color(uiColor: .tertiarySystemFill), lineWidth: 8)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(AppTheme.brand, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(Int(progress * 100))%")
                            .font(.headline)
                            .contentTransition(.numericText())
                    }
                    .frame(width: 78, height: 78)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("7月月度交接").font(.caption).foregroundStyle(.secondary)
                        Text(completedCount == closeChecklist.count ? "本月已经交清" : "还剩\(closeChecklist.count - completedCount)项")
                            .font(.title2.weight(.semibold))
                        Text("专业判断交给代账，系统只记录交接事实。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .appCard()

                ForEach(["由我完成", "与代账共同确认"], id: \.self) { group in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(group).font(.headline).padding(.bottom, 8)
                        ForEach(closeChecklist.filter { $0.group == group }) { item in
                            Button {
                                withAnimation(MotionToken.normal) { session.toggleCloseItem(item.id) }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: session.state.completedClose.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(session.state.completedClose.contains(item.id) ? AppTheme.brand : .secondary)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                        Text(item.note).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                            if item.id != closeChecklist.filter({ $0.group == group }).last?.id { Divider().padding(.leading, 36) }
                        }
                    }
                    .appCard()
                }
            }
            .padding()
        }
        .background(AppTheme.pageBackground)
        .navigationBarHidden(true)
    }
}

