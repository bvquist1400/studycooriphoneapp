import SwiftUI

struct CalculationDetailView: View {
    let calculation: Calculation

    @State private var shareSheet: ShareSheet?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Form {
            Section {
                LabeledContent("Subject", value: calculation.subjectId ?? "N/A")
                LabeledContent("Start", value: calculation.startDate.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("End", value: calculation.endDate.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("Frequency", value: calculation.frequency.rawValue)
                if calculation.frequency != .prn {
                    LabeledContent("Edge days") {
                        Text("first \(calculation.firstDayExpectedOverride.map(String.init) ?? "-")  last \(calculation.lastDayExpectedOverride.map(String.init) ?? "-")")
                    }
                }
            } header: { Label("Subject & Period", systemImage: "calendar") }

            Section {
                LabeledContent("Dispensed", value: String(format: "%.2f", calculation.dispensed))
                LabeledContent("Returned", value: String(format: "%.2f", calculation.returned))
                LabeledContent("Missed", value: String(format: "%.2f", calculation.missedDoses))
                LabeledContent("Extra", value: String(format: "%.2f", calculation.extraDoses))
                LabeledContent("Hold days", value: String(calculation.holdDays))
                if calculation.frequency == .prn, let t = calculation.prnTargetPerDay {
                    LabeledContent("PRN target/day", value: String(format: "%.2f", t))
                }
            } header: { Label("Counts", systemImage: "number") }

            if !calculation.bottles.isEmpty {
                Section {
                    ForEach(calculation.bottles) { b in
                        HStack {
                            Text(b.label)
                            Spacer()
                            Text(String(format: "D: %.0f  R: %.0f", b.dispensed, b.returned))
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: { Label("Bottles", systemImage: "shippingbox") }
            }

            Section {
                LabeledContent("Expected", value: String(format: "%.2f", calculation.expectedDoses))
                LabeledContent("Actual", value: String(format: "%.2f", calculation.actualDoses))
                LabeledContent("Compliance", value: String(format: "%.1f%%", calculation.compliancePct))
                if !calculation.flags.isEmpty {
                    LabeledContent("Flags", value: calculation.flags.joined(separator: ", "))
                }
                LabeledContent("Created", value: calculation.createdAt.formatted())
            } header: { Label("Results", systemImage: "gauge") }
        }
        .navigationTitle("Calculation Detail")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    shareSheet = ShareSheet(activityItems: [export(calculation)])
                } label: { Image(systemName: "square.and.arrow.up") }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: ExplainabilityView(calculation: calculation)) {
                    Image(systemName: "questionmark.circle")
                }
                .accessibilityLabel("How we calculated this")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if let data = PDFExporter.calculationSummaryPDF(calculation) {
                        shareSheet = ShareSheet(activityItems: [data])
                    }
                } label: { Image(systemName: "doc.richtext") }
                .accessibilityLabel("Export PDF")
            }
        }
        .sheet(item: $shareSheet) { $0 }
        .studyCoorBackground()
    }


    private func export(_ c: Calculation) -> String {
        """
        Subject: \(c.subjectId ?? "N/A")
        Period: \(c.startDate.formatted(date: .abbreviated, time: .omitted)) – \(c.endDate.formatted(date: .abbreviated, time: .omitted))
        Frequency: \(c.frequency.rawValue)
        Edge days: first \(c.firstDayExpectedOverride.map(String.init) ?? "-")  last \(c.lastDayExpectedOverride.map(String.init) ?? "-")
        Dispensed: \(c.dispensed)  Returned: \(c.returned)
        Missed: \(c.missedDoses)  Extra: \(c.extraDoses)  Hold days: \(c.holdDays)
        Expected: \(String(format: "%.2f", c.expectedDoses))  Actual: \(String(format: "%.2f", c.actualDoses))
        Compliance: \(String(format: "%.1f%%", c.compliancePct))
        Flags: \(c.flags.joined(separator: ", "))
        Created: \(c.createdAt.formatted())
        """
    }
}
