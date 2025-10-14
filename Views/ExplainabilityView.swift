import SwiftUI

struct ExplainabilityView: View {
    let calculation: Calculation

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let breakdown {
                    expectedCard(breakdown: breakdown)
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

    private func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func adjustmentText(_ adjustment: Double) -> String {
        if adjustment == 0 { return format(0) }
        let prefix = adjustment > 0 ? "+" : ""
        return "\(prefix)\(format(adjustment))"
    }

    private var friendlyFlags: [String] {
        calculation.flags.map { ComplianceOutputs.description(for: $0) }
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
}
