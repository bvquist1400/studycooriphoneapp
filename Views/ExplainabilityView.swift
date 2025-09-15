import SwiftUI

struct ExplainabilityView: View {
    let calculation: Calculation

    var body: some View {
        List {
            Section("Period & Expected") {
                LabeledContent("Days (inclusive)", value: String(days))
                LabeledContent("Hold days", value: String(calculation.holdDays))
                LabeledContent("Effective days", value: String(effectiveDays))
                if calculation.frequency != .prn {
                    LabeledContent("Base per day", value: String(format: "%.2f", calculation.frequency.dosesPerDay))
                    if let f = calculation.firstDayExpectedOverride { LabeledContent("First day override", value: String(f)) }
                    if let l = calculation.lastDayExpectedOverride { LabeledContent("Last day override", value: String(l)) }
                } else if let t = calculation.prnTargetPerDay {
                    LabeledContent("PRN target/day", value: String(format: "%.2f", t))
                }
                LabeledContent("Expected", value: String(format: "%.2f", calculation.expectedDoses))
            }
            Section("Actual") {
                LabeledContent("Dispensed", value: String(format: "%.2f", calculation.dispensed))
                LabeledContent("Returned", value: String(format: "%.2f", calculation.returned))
                LabeledContent("Missed", value: String(format: "%.2f", calculation.missedDoses))
                LabeledContent("Extra", value: String(format: "%.2f", calculation.extraDoses))
                LabeledContent("Partial doses", value: calculation.partialDoseEnabled ? "Allowed" : "Rounded")
                LabeledContent("Actual", value: String(format: "%.2f", calculation.actualDoses))
            }
            Section("Compliance") {
                LabeledContent("Compliance %", value: String(format: "%.1f%%", calculation.compliancePct))
                if !calculation.flags.isEmpty {
                    LabeledContent("Flags", value: calculation.flags.joined(separator: ", "))
                }
                Text("Compliance is Actual ÷ Expected × 100, clamped to 0–150% when Expected > 0; if Expected is 0, then 0% unless Actual is also 0 (100%).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("How We Calculated")
    }

    private var days: Int {
        ComplianceEngine.daysBetweenInclusive(from: calculation.startDate, to: calculation.endDate, calendar: .current)
    }
    private var effectiveDays: Int { max(0, days - calculation.holdDays) }
}

