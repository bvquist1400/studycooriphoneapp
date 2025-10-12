import SwiftUI
import SwiftData

struct SubjectDetailView: View {
    @Environment(\.modelContext) private var ctx
    let subject: Subject

    @Query private var calcs: [Calculation]

    init(subject: Subject) {
        self.subject = subject
        let codeOpt: String? = subject.code
        _calcs = Query(
            filter: #Predicate { $0.subjectId == codeOpt },
            sort: [SortDescriptor(\Calculation.createdAt, order: .reverse)]
        )
    }

    var body: some View {
        List {
            Section { headerCard } header: { Label("Overview", systemImage: "person.crop.circle.badge.checkmark") }

            Section {
                if calcs.isEmpty {
                    Text("No visits yet. Run a calculation with this subject code to see it here.")
                        .foregroundStyle(.secondary)
                }
                ForEach(calcs) { c in
                    NavigationLink(destination: CalculationDetailView(calculation: c)) {
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

    private func colorForCompliance(_ pct: Double) -> Color {
        if pct > 110 { return .orange }
        if pct < 90 { return .red }
        return .green
    }

}
