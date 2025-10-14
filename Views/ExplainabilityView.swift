import SwiftUI

struct ExplainabilityView: View {
    let calculation: Calculation

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let breakdown {
                    expectedCard(breakdown: breakdown)
                    stepByStepCard(breakdown: breakdown)
                    actualCard(breakdown: breakdown)
                } else {
                    legacyInputsCard
                }
                complianceCard
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("How We Calculated")
    }

    private var breakdown: ComplianceBreakdown? {
        if let stored = calculation.breakdown {
            return stored
        }
        let inputs = ComplianceInputs(
            dispensed: calculation.dispensed,
            returned: calculation.returned,
            startDate: calculation.startDate,
            endDate: calculation.endDate,
            frequency: calculation.frequency,
            missedDoses: calculation.missedDoses,
            extraDoses: calculation.extraDoses,
            holdDays: calculation.holdDays,
            partialDoseEnabled: calculation.partialDoseEnabled,
            prnTargetPerDay: calculation.prnTargetPerDay,
            firstDayExpectedOverride: calculation.firstDayExpectedOverride,
            lastDayExpectedOverride: calculation.lastDayExpectedOverride
        )
        return try? ComplianceEngine.compute(inputs).breakdown
    }

    private var days: Int {
        ComplianceEngine.daysBetweenInclusive(from: calculation.startDate, to: calculation.endDate, calendar: .current)
    }
    private var effectiveDays: Int { max(0, days - calculation.holdDays) }
    private var periodText: String {
        let start = Self.dayFormatter.string(from: calculation.startDate)
        let end = Self.dayFormatter.string(from: calculation.endDate)
        if start == end { return start }
        return "\(start) → \(end)"
    }

    private func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func formatPercent(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }

    private func adjustmentText(_ adjustment: Double) -> String {
        if adjustment == 0 { return format(0) }
        let prefix = adjustment > 0 ? "+" : ""
        return "\(prefix)\(format(adjustment))"
    }

    private var friendlyFlags: [String] {
        calculation.flags.map { ComplianceOutputs.description(for: $0) }
    }

    private func computationSteps(for breakdown: ComplianceBreakdown) -> [(title: String, detail: String)] {
        var steps: [(String, String)] = []

        steps.append((
            "Count the study days",
            "\(periodText) covers \(breakdown.expected.inclusiveDays) day\(breakdown.expected.inclusiveDays == 1 ? "" : "s") inclusive."
        ))

        if breakdown.expected.holdDays > 0 {
            steps.append((
                "Remove hold days",
                "Subtract \(breakdown.expected.holdDays) hold day\(breakdown.expected.holdDays == 1 ? "" : "s") → \(breakdown.expected.effectiveDays) effective day\(breakdown.expected.effectiveDays == 1 ? "" : "s")."
            ))
        } else {
            steps.append((
                "Confirm effective days",
                "No hold days were supplied, so effective days remain \(breakdown.expected.effectiveDays)."
            ))
        }

        if calculation.frequency == .prn {
            let target = breakdown.expected.prnTargetPerDay ?? 0
            steps.append((
                "Apply PRN target",
                "\(format(target)) target dose\(target == 1 ? "" : "s") per day × \(breakdown.expected.effectiveDays) day\(breakdown.expected.effectiveDays == 1 ? "" : "s") = \(format(breakdown.expected.baseExpected))."
            ))
        } else {
            let perDay = breakdown.expected.baseDosesPerDay
            steps.append((
                "Daily schedule",
                "\(calculation.frequency.rawValue) expects \(format(perDay)) dose\(perDay == 1 ? "" : "s") per day × \(breakdown.expected.effectiveDays) day\(breakdown.expected.effectiveDays == 1 ? "" : "s") = \(format(breakdown.expected.baseExpected))."
            ))
        }

        var edgeAdjustments: [String] = []
        if breakdown.expected.firstDayAdjustment != 0 {
            edgeAdjustments.append("first day \(adjustmentText(breakdown.expected.firstDayAdjustment))")
        }
        if breakdown.expected.lastDayAdjustment != 0 {
            edgeAdjustments.append("last day \(adjustmentText(breakdown.expected.lastDayAdjustment))")
        }
        if !edgeAdjustments.isEmpty {
            steps.append((
                "Edge-day overrides",
                edgeAdjustments.joined(separator: ", ") + " → \(format(breakdown.expected.totalExpected)) total expected doses."
            ))
        } else {
            steps.append((
                "Expected total",
                "No edge-day overrides were applied, so total expected remains \(format(breakdown.expected.totalExpected))."
            ))
        }

        let actualFormula = "\(format(breakdown.actual.dispensed)) − \(format(breakdown.actual.returned)) − \(format(breakdown.actual.missed)) + \(format(breakdown.actual.extra)) = \(format(breakdown.actual.rawActual))."
        steps.append((
            "Aggregate actual usage",
            "Dispensed minus returned minus missed plus extra → \(actualFormula)"
        ))

        if !breakdown.actual.partialDosesEnabled {
            steps.append((
                "Round whole doses",
                "Partial doses disabled, so round \(format(breakdown.actual.rawActual)) → \(format(breakdown.actual.afterRounding))."
            ))
        }

        if breakdown.actual.afterRounding != breakdown.actual.afterClamping {
            steps.append((
                "Clamp below zero",
                "Prevent negative totals by clamping \(format(breakdown.actual.afterRounding)) → \(format(breakdown.actual.afterClamping))."
            ))
        }

        if breakdown.expected.totalExpected == 0 {
            if breakdown.actual.afterClamping == 0 {
                steps.append((
                    "Compute compliance",
                    "Both expected and actual are zero, so compliance defaults to 100%."
                ))
            } else {
                steps.append((
                    "Compute compliance",
                    "Expected is zero but actual is \(format(breakdown.actual.afterClamping)); compliance defaults to 0%."
                ))
            }
        } else {
            let rawPercent = (breakdown.actual.afterClamping / breakdown.expected.totalExpected) * 100
            var detail = "\(format(breakdown.actual.afterClamping)) ÷ \(format(breakdown.expected.totalExpected)) = \(formatPercent(rawPercent))."
            let displayed = calculation.compliancePct
            if abs(rawPercent - displayed) > 0.05 {
                detail += " Clamped to \(formatPercent(displayed))."
            }
            steps.append((
                "Compute compliance",
                detail
            ))
        }

        return steps
    }

    @ViewBuilder
    private func expectedCard(breakdown: ComplianceBreakdown) -> some View {
        explainabilityCard(
            title: "Expected Doses",
            systemImage: "calendar.badge.clock"
        ) {
            StatRow(label: "Days (inclusive)", value: "\(breakdown.expected.inclusiveDays)")
            StatRow(label: "Hold days", value: "\(breakdown.expected.holdDays)")
            StatRow(label: "Effective days", value: "\(breakdown.expected.effectiveDays)")

            if calculation.frequency == .prn {
                if let target = breakdown.expected.prnTargetPerDay {
                    StatRow(label: "PRN target / day", value: format(target))
                }
            } else {
                StatRow(label: "Scheduled per day", value: format(breakdown.expected.baseDosesPerDay))
                if breakdown.expected.firstDayAdjustment != 0 {
                    StatRow(label: "First day adjustment", value: adjustmentText(breakdown.expected.firstDayAdjustment))
                }
                if breakdown.expected.lastDayAdjustment != 0 {
                    StatRow(label: "Last day adjustment", value: adjustmentText(breakdown.expected.lastDayAdjustment))
                }
            }

            Divider()

            StatRow(label: "Base expected", value: format(breakdown.expected.baseExpected))
            StatRow(label: "Total expected", value: format(breakdown.expected.totalExpected), highlight: true)
        } footer: {
            Text("Base expected equals daily goal × effective days. Edge-day overrides adjust the start and/or finish to match study expectations.")
        }
    }

    @ViewBuilder
    private func stepByStepCard(breakdown: ComplianceBreakdown) -> some View {
        let steps = computationSteps(for: breakdown)
        explainabilityCard(
            title: "Step-by-Step",
            systemImage: "list.number"
        ) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                StepRow(number: index + 1, title: step.title, detail: step.detail)
                if index != steps.count - 1 {
                    Divider()
                }
            }
        } footer: {
            Text("These steps mirror the compliance engine so you can audit how expected and actual doses feed into the final percentage.")
        }
    }

    @ViewBuilder
    private func actualCard(breakdown: ComplianceBreakdown) -> some View {
        explainabilityCard(
            title: "Actual Doses",
            systemImage: "pill.fill"
        ) {
            ContributionRow(label: "Dispensed", value: format(breakdown.actual.dispensed), symbol: "+")
            ContributionRow(label: "Returned", value: format(breakdown.actual.returned), symbol: "−")
            ContributionRow(label: "Missed", value: format(breakdown.actual.missed), symbol: "−")
            ContributionRow(label: "Extra", value: format(breakdown.actual.extra), symbol: "+")

            Divider()

            StatRow(label: "Raw total", value: format(breakdown.actual.rawActual))

            if !breakdown.actual.partialDosesEnabled {
                StatRow(label: "Rounded", value: format(breakdown.actual.afterRounding))
            }
            if breakdown.actual.afterRounding != breakdown.actual.afterClamping {
                StatRow(label: "After clamp", value: format(breakdown.actual.afterClamping))
            }

            StatRow(label: "Final actual", value: format(breakdown.actual.afterClamping), highlight: true)
        } footer: {
            Text(breakdown.actual.partialDosesEnabled
                 ? "Partial dosing enabled—actual totals keep decimal precision before clamping to zero."
                 : "Partial dosing disabled—raw totals are rounded to the nearest whole dose before clamping to zero.")
        }
    }

    @ViewBuilder
    private var legacyInputsCard: some View {
        explainabilityCard(
            title: "Inputs Snapshot",
            systemImage: "doc.text.magnifyingglass"
        ) {
            StatRow(label: "Days (inclusive)", value: "\(days)")
            StatRow(label: "Hold days", value: "\(calculation.holdDays)")
            StatRow(label: "Effective days", value: "\(effectiveDays)")

            if calculation.frequency != .prn {
                StatRow(label: "Base per day", value: format(calculation.frequency.dosesPerDay))
                if let f = calculation.firstDayExpectedOverride {
                    StatRow(label: "First day override", value: "\(f)")
                }
                if let l = calculation.lastDayExpectedOverride {
                    StatRow(label: "Last day override", value: "\(l)")
                }
            } else if let target = calculation.prnTargetPerDay {
                StatRow(label: "PRN target / day", value: format(target))
            }

            Divider()

            StatRow(label: "Expected", value: format(calculation.expectedDoses), highlight: true)

            Divider()

            StatRow(label: "Dispensed", value: format(calculation.dispensed))
            StatRow(label: "Returned", value: format(calculation.returned))
            StatRow(label: "Missed", value: format(calculation.missedDoses))
            StatRow(label: "Extra", value: format(calculation.extraDoses))
            StatRow(label: "Partial doses", value: calculation.partialDoseEnabled ? "Allowed" : "Rounded")
            StatRow(label: "Actual", value: format(calculation.actualDoses), highlight: true)
        } footer: {
            Text("This calculation predates the full explainability breakdown, so values are reconstructed from saved inputs.")
        }
    }

    @ViewBuilder
    private var complianceCard: some View {
        explainabilityCard(
            title: "Compliance Summary",
            systemImage: "percent"
        ) {
            StatRow(label: "Actual doses", value: format(calculation.actualDoses))
            StatRow(label: "Expected doses", value: format(calculation.expectedDoses))

            Divider()

            StatRow(label: "Compliance", value: String(format: "%.1f%%", calculation.compliancePct), highlight: true)

            if !friendlyFlags.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Flags")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Wrap(friendlyFlags) { flag in
                        Text(flag)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.thinMaterial, in: Capsule())
                    }
                }
            }
        } footer: {
            Text("Compliance = Actual ÷ Expected × 100. Values are clamped between 0% and 150%. If expected is 0, compliance is 0% unless both expected and actual are zero.")
        }
    }

    @ViewBuilder
    private func explainabilityCard<Content: View, Footer: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content,
        footer: () -> Footer
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                Text(title)
                    .font(.headline)
            }

            VStack(spacing: 12) {
                content()
            }

            footer()
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private struct StepRow: View {
        let number: Int
        let title: String
        let detail: String

        private let numberColumnWidth: CGFloat = 32
        private let gutter: CGFloat = 12

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: gutter) {
                    Text("\(number).")
                        .font(.system(size: 15, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: numberColumnWidth, alignment: .trailing)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, numberColumnWidth + gutter)
            }
        }
    }

    private struct StatRow: View {
        let label: String
        let value: String
        var highlight: Bool = false

        var body: some View {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 12)
                Text(value)
                    .font(highlight ? .headline.weight(.semibold) : .headline)
                    .monospacedDigit()
                    .foregroundStyle(highlight ? Color.accentColor : Color.primary)
            }
        }
    }

    private struct ContributionRow: View {
        let label: String
        let value: String
        let symbol: String

        var body: some View {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 12)
                HStack(spacing: 6) {
                    Text(symbol)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.headline)
                        .monospacedDigit()
                }
            }
        }
    }

    private struct Wrap<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
        let data: Data
        let content: (Data.Element) -> Content

        init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
            self.data = data
            self.content = content
        }

        var body: some View {
            FlexibleView(
                availableWidth: UIScreen.main.bounds.width - 32,
                data: data,
                spacing: 8,
                content: content
            )
        }
    }

    private struct FlexibleView<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
        let availableWidth: CGFloat
        let data: Data
        let spacing: CGFloat
        let content: (Data.Element) -> Content

        @State private var elementsSize: [Data.Element: CGSize] = [:]

        var body: some View {
            let rows = computeRows()
            return VStack(alignment: .leading, spacing: spacing) {
                ForEach(Array(rows.enumerated()), id: \.offset) { row in
                    HStack(spacing: spacing) {
                        ForEach(row.element, id: \.self) { element in
                            content(element)
                                .fixedSize()
                                .background(
                                    GeometryReader { geo in
                                        Color.clear
                                            .onAppear {
                                                elementsSize[element] = geo.size
                                            }
                                    }
                                )
                        }
                    }
                }
            }
        }

        private func computeRows() -> [[Data.Element]] {
            guard !data.isEmpty else { return [] }

            var rows: [[Data.Element]] = [[]]
            var currentRowWidth: CGFloat = 0

            for element in data {
                let elementSize = elementsSize[element, default: .zero]
                let elementWidth = elementSize.width == 0 ? availableWidth : elementSize.width
                let tentativeWidth = currentRowWidth == 0 ? elementWidth : currentRowWidth + spacing + elementWidth

                if tentativeWidth > availableWidth, !rows[rows.count - 1].isEmpty {
                    rows.append([element])
                    currentRowWidth = elementWidth
                } else {
                    rows[rows.count - 1].append(element)
                    currentRowWidth = tentativeWidth
                }
            }

            return rows
        }
    }

    private static let dayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }()
}
