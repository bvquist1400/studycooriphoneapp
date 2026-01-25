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
        let subjectUUID = subject.uuid
        let sort = [SortDescriptor(\Calculation.createdAt, order: .reverse)]
        let requestedStudyUUID = subject.study?.uuid
        let predicate = #Predicate<Calculation> { calc in
            calc.subjectUUID == subjectUUID ||
            (calc.subjectUUID == nil && calc.subjectId == code && calc.studyUUID == requestedStudyUUID)
        }
        _calcs = Query(filter: predicate, sort: sort)
    }

    var body: some View {
        List {
            Section { headerCard } header: {
                Label {
                    Text("subjectDetail.overview", tableName: "Localizable", comment: "Subject detail overview section header")
                } icon: {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                }
            }

            if !calcs.isEmpty {
                Section {
                    complianceTrend
                        .frame(minHeight: 180)
                        .padding(.vertical, 4)
                } header: {
                    Label {
                        Text("subjectDetail.trends", tableName: "Localizable", comment: "Subject detail trends section header")
                    } icon: {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                    }
                }
            }

            Section {
                if calcs.isEmpty {
                    Text("subjectDetail.noVisits", tableName: "Localizable", comment: "Empty state message for subject detail visits list")
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
            } header: {
                Label {
                    Text("subjectDetail.visits", tableName: "Localizable", comment: "Subject detail visits section header")
                } icon: {
                    Image(systemName: "calendar")
                }
            }
        }
        .navigationTitle(subject.displayName ?? subject.code)
        .listStyle(.insetGrouped)
        .studyCoorBackground()
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                stat(title: NSLocalizedString("subjectDetail.header.totalPills", tableName: "Localizable", value: "Total Pills", comment: "Subject detail total pills stat title"), value: String(format: "%.0f", totalPills))
                Spacer()
                stat(title: NSLocalizedString("subjectDetail.header.visits", tableName: "Localizable", value: "Visits", comment: "Subject detail visits stat title"), value: String(calcs.count))
            }
            HStack {
                stat(title: NSLocalizedString("subjectDetail.header.average", tableName: "Localizable", value: "Avg %", comment: "Subject detail average compliance stat title"), value: String(format: "%.1f", averageCompliance))
                Spacer()
                stat(title: NSLocalizedString("subjectDetail.header.bestWorst", tableName: "Localizable", value: "Best/Worst", comment: "Subject detail best and worst compliance stat title"), value: String(format: "%.0f/%.0f", bestCompliance, worstCompliance))
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
            let visitDateAxisTitle = NSLocalizedString("subjectDetail.trend.axis.visitDate", tableName: "Localizable", value: "Visit Date", comment: "Axis title for visit dates in the subject detail compliance trend chart")
            let complianceAxisTitle = NSLocalizedString("subjectDetail.trend.axis.compliance", tableName: "Localizable", value: "Compliance (%)", comment: "Axis title for compliance percentage in the subject detail compliance trend chart")
            let targetAxisTitle = NSLocalizedString("subjectDetail.trend.axis.target", tableName: "Localizable", value: "Target", comment: "Target label used for the compliance trend chart baseline")

            Chart {
                ForEach(trendPoints, id: \.date) { point in
                    LineMark(
                        x: .value(visitDateAxisTitle, point.date),
                        y: .value(complianceAxisTitle, point.compliance)
                    )
                    .interpolationMethod(.monotone)
                    PointMark(
                        x: .value(visitDateAxisTitle, point.date),
                        y: .value(complianceAxisTitle, point.compliance)
                    )
                    .symbolSize(36)
                }
                RuleMark(y: .value(targetAxisTitle, 100))
                    .lineStyle(.init(lineWidth: 1, dash: [4]))
                    .foregroundStyle(Color.secondary)
                    .annotation(position: .topTrailing) {
                        Text("subjectDetail.trend.target", tableName: "Localizable", comment: "Annotation label showing 100 percent compliance target line")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartYAxisLabel {
                Text(complianceAxisTitle)
            }
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
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("subjectDetail.trend.accessibilityLabel", tableName: "Localizable", comment: "Accessibility label describing the compliance trend chart"))
            .accessibilityValue(trendAccessibilitySummary)
            .accessibilityHint(Text("subjectDetail.trend.accessibilityHint", tableName: "Localizable", comment: "Accessibility hint for the compliance trend chart"))
        } else if let only = trendPoints.first {
            VStack(spacing: 12) {
                Text("subjectDetail.trend.singleVisitTitle", tableName: "Localizable", comment: "Message shown when only one visit exists")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(String(format: NSLocalizedString("subjectDetail.trend.singleVisitDescription", tableName: "Localizable", value: "%@ compliance on %@.", comment: "Describes the only visit compliance result in subject detail trend"), String(format: "%.1f%%", only.compliance), only.date.formatted(date: .abbreviated, time: .omitted)))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .multilineTextAlignment(.center)
        }
    }

    private func colorForCompliance(_ pct: Double) -> Color {
        if pct > 110 { return .orange }
        if pct < 90 { return .red }
        return .green
    }

    private var trendAccessibilitySummary: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        let pointsToDescribe = trendPoints.suffix(3)
        let descriptions = pointsToDescribe.map { point in
            let date = formatter.string(from: point.date)
            return String(format: NSLocalizedString("subjectDetail.trend.accessibilitySummaryItem", tableName: "Localizable", value: "%@ at %.1f percent", comment: "Accessibility summary item describing compliance percentage on a specific date"), date, point.compliance)
        }
        if descriptions.isEmpty {
            return NSLocalizedString("subjectDetail.trend.accessibilitySummaryEmpty", tableName: "Localizable", value: "No visits recorded yet.", comment: "Accessibility summary when no visits exist")
        }
        return descriptions.joined(separator: ", ")
    }

}
