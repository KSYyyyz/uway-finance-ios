import Charts
import SwiftUI

struct ForecastView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var period: ForecastPeriod = .month
    @State private var visiblePointCount = 0

    private var points: [ForecastPoint] {
        ForecastCalculator.points(records: session.state.records, period: period)
    }

    private var plannedIn: Double {
        session.state.records.filter { $0.settlementStatus == .unsettled && $0.direction == .income }.reduce(0) { $0 + $1.amount }
    }

    private var plannedOut: Double {
        session.state.records.filter { $0.settlementStatus == .unsettled && $0.direction == .expense }.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PageBrief(title: "未来现金是否够用", subtitle: "基于已确认与计划事项，按周期动态测算")
                VStack(alignment: .leading, spacing: 16) {
                    Text("期末预计")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(FinanceFormat.currency(points.last?.balance ?? 0, digits: 0))
                        .font(.largeTitle.weight(.semibold))
                        .contentTransition(.numericText())
                    Picker("预测周期", selection: $period) {
                        ForEach(ForecastPeriod.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    HStack {
                        forecastMetric("预计流入", plannedIn)
                        Spacer()
                        forecastMetric("预计流出", plannedOut)
                    }
                }
                .appCard()

                VStack(alignment: .leading, spacing: 12) {
                    Text("余额走势").font(.headline)
                    Chart(Array(points.prefix(visiblePointCount))) { point in
                        LineMark(
                            x: .value("日期", point.date),
                            y: .value("余额", point.balance)
                        )
                        .foregroundStyle(AppTheme.brand)
                        .interpolationMethod(.catmullRom)
                        AreaMark(
                            x: .value("日期", point.date),
                            y: .value("余额", point.balance)
                        )
                        .foregroundStyle(AppTheme.brand.opacity(0.08))
                        .interpolationMethod(.catmullRom)
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let amount = value.as(Double.self) {
                                    Text(FinanceFormat.currency(amount, digits: 0))
                                }
                            }
                        }
                    }
                    .frame(height: 230)
                    .accessibilityLabel("未来\(period.rawValue)天现金余额走势")
                }
                .appCard()
            }
            .padding()
        }
        .appScrollIndicatorsHidden()
        .background(AppTheme.pageBackground)
        .navigationTitle("资金预测")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: period) { await revealChart() }
    }

    private func forecastMetric(_ title: String, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(FinanceFormat.currency(value, digits: 0)).font(.headline).monospacedDigit()
        }
    }

    @MainActor
    private func revealChart() async {
        visiblePointCount = reduceMotion ? points.count : 1
        guard !reduceMotion else { return }
        for count in 2...max(points.count, 2) {
            guard !Task.isCancelled else { return }
            try? await Task.sleep(for: .milliseconds(35))
            withAnimation(.linear(duration: 0.08)) { visiblePointCount = min(count, points.count) }
        }
    }
}
