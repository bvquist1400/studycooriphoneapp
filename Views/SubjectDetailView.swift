import SwiftUI
import SwiftData
import Charts

struct SubjectDetailView: View {
    @Environment(\.modelContext) private var ctx
    let subject: Subject

    @Query private var calcs: [Calculation]

    init(subject: Subject) {
        self.subject = subject
        let code = subject.code
        if let study = subject.study {
            _calcs = Query(
                filter: #Predicate {
                    ($0.subject == subject) ||
                    ($0.subject == nil && $0.subjectId == code && $0.study == study)
                },
                sort: [SortDescriptor(\Calculation.createdAt, order: .reverse)]
            )
        } else {
            _calcs = Query(
                filter: #Predicate {
                    ($0.subject == subject) ||
                    ($0.subject == nil && $0.subjectId == code && $0.study == nil)
                },
                sort: [SortDescriptor(\Calculation.createdAt, order: .reverse)]
            )
        }
    }

    var body: some View {
        List {
            Section { headerCard } header: { Label("Overview", systemImage: "person.crop.circle.badge.checkmark") }

            if !calcs.isEmpty {
                Section {
                    complianceTrend
                        .frame(minHeight: 180)
                        .padding(.vertical, 4)
                } header: {
                    Label("Trends", systemImage: "chart.line.uptrend.xyaxis")
                }
            }

            Section {
                if calcs.isEmpty {
                    Text("No visits yet. Run a calculation with this subject code to see it here.")
                        .foregroundStyle(.secondary)
                }
                ForEach(calcs) { c in
                    NavigationLink(destination: ExplainabilityView(calculation: c)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(c.startDate.formatted(date: .abbreviated, time: .omitted)) → \(c.endDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.subheadline)
                            HStack(spacing: 12) {
                                Text(String(format: "%.1f%%", c.compliancePct))
                                    .padding(.vertical, 2).padding(.horizontal, 6)
                                    .background(Capsule().fill(colorForCompliance(c.compliancePct).opacity(0.12)))
                                    .foregroundStyle(colorForCompliance(c.compliancePct))
                                Text(c.frequency.rawValue).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: { Label("Visits", systemImage: "calendar") }
        }
        .navigationTitle(subject.displayName ?? subject.code)
        .listStyle(.insetGrouped)
        .studyCoorBackground()
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                stat(title: "Total Pills", value: String(format: "%.0f", totalPills))
                Spacer()
                stat(title: "Visits", value: String(calcs.count))
            }
            HStack {
                stat(title: "Avg %", value: String(format: "%.1f", averageCompliance))
                Spacer()
                stat(title: "Best/Worst", value: String(format: "%.0f/%.0f", bestCompliance, worstCompliance))
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
    }

    private func stat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline)
        }
    }

    private var totalPills: Double { calcs.reduce(0) { $0 + ($1.dispensed - $1.returned) } }
    private var averageCompliance: Double {
        guard !calcs.isEmpty else { return 0 }
        return calcs.map { $0.compliancePct }.reduce(0, +) / Double(calcs.count)
    }
    private var bestCompliance: Double { calcs.map { $0.compliancePct }.max() ?? 0 }
    private var worstCompliance: Double { calcs.map { $0.compliancePct }.min() ?? 0 }

    private var trendPoints: [(date: Date, compliance: Double)] {
        calcs
            .sorted(by: { $0.endDate < $1.endDate })
            .map { ($0.endDate, $0.compliancePct) }
    }

    @ViewBuilder
    private var complianceTrend: some View {
        if trendPoints.count >= 2 {
            Chart {
                ForEach(trendPoints, id: \.date) { point in
                    LineMark(
                        x: .value("Visit Date", point.date),
                        y: .value("Compliance (%)", point.compliance)
                    )
                    .interpolationMethod(.monotone)
                    PointMark(
                        x: .value("Visit Date", point.date),
                        y: .value("Compliance (%)", point.compliance)
                    )
                    .symbolSize(36)
                }
                RuleMark(y: .value("Target", 100))
                    .lineStyle(.init(lineWidth: 1, dash: [4]))
                    .foregroundStyle(Color.secondary)
                    .annotation(position: .topTrailing) {
                        Text("100% target")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartYAxisLabel("Compliance (%)")
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: min(6, trendPoints.count))) { value in
                    AxisValueLabel {
                        if let dateValue = value.as(Date.self) {
                            Text(dateValue, format: .dateTime.month(.abbreviated).day())
                        }
                    }
                    AxisTick()
                    AxisGridLine()
                }
            }
        } else if let only = trendPoints.first {
            VStack(spacing: 12) {
                Text("Only one visit recorded so far.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(only.compliance, specifier: "%.1f")% compliance on \(only.date.formatted(date: .abbreviated, time: .omitted)).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func colorForCompliance(_ pct: Double) -> Color {
        if pct > 110 { return .orange }
        if pct < 90 { return .red }
        return .green
    }

}
