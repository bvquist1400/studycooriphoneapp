//
//  HistoryView.swift
//  StudyCoor
//
//  Created by Brent Bloomquist on 8/29/25.
//


import SwiftUI
import SwiftData
import UIKit

struct HistoryView: View {
    @Query(sort: [SortDescriptor(\Calculation.createdAt, order: .reverse)])
    private var items: [Calculation]

    @Environment(\.modelContext) private var ctx
    @Environment(\.colorScheme) private var colorScheme
    @State private var shareSheet: ShareSheet?
    @State private var selection = Set<Calculation>()
    @State private var persistenceError: HistorySaveError?
    @State private var cleanupURLs: [URL] = []

    var body: some View {
        NavigationStack {
            List(selection: $selection) {
                if items.isEmpty {
                    ContentUnavailableView(
                        "No History Yet",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Run a calculation on the Calculator tab to save it here.")
                    )
                    .listRowInsets(.init())
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(items) { calc in
                        NavigationLink {
                            ExplainabilityView(calculation: calc)
                        } label: {
                            row(for: calc)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) { delete(calculation: calc) } label: {
                                Label {
                                    Text("history.action.delete", tableName: "Localizable", comment: "Delete calculation from history action")
                                } icon: {
                                    Image(systemName: "trash")
                                }
                            }
                            Button { share(calculation: calc) } label: {
                                Label {
                                    Text("history.action.share", tableName: "Localizable", comment: "Share calculation from history action")
                                } icon: {
                                    Image(systemName: "square.and.arrow.up")
                                }
                            }
                        }
                        .contextMenu {
                            Button(action: { share(calculation: calc) }) {
                                Text("history.action.share", tableName: "Localizable", comment: "Share calculation from context menu")
                            }
                            Button(role: .destructive, action: { delete(calculation: calc) }) {
                                Text("history.action.delete", tableName: "Localizable", comment: "Delete calculation from context menu")
                            }
                        }
                    }
                    .onDelete(perform: delete)
                }

            }
            .navigationTitle(Text("history.navigation.title", tableName: "Localizable", comment: "History navigation title"))
            .navigationBarTitleDisplayMode(.large)
            .listStyle(.insetGrouped)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !selection.isEmpty {
                        Button { shareSelected() } label: {
                            Label {
                                Text("history.action.share", tableName: "Localizable", comment: "Share selected calculations action")
                            } icon: {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                        Button(role: .destructive) { deleteSelection() } label: {
                            Label {
                                Text("history.action.delete", tableName: "Localizable", comment: "Delete selected calculations action")
                            } icon: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                }
            }
            .studyCoorBackground()
            .sheet(item: $shareSheet) { sheet in
                sheet
            }
            .alert(item: $persistenceError) { error in
                Alert(
                    title: Text("history.alert.saveFailure.title", tableName: "Localizable", comment: "Title for failure to save history changes alert"),
                    message: Text(error.message),
                    dismissButton: .default(Text("history.alert.saveFailure.dismiss", tableName: "Localizable", comment: "Dismiss button title for history save failure alert"))
                )
            }
        }
    }


    private func delete(at offsets: IndexSet) {
        for index in offsets { ctx.delete(items[index]) }
        persistChanges()
    }

    private func delete(calculation: Calculation) {
        ctx.delete(calculation)
        persistChanges()
    }

    private func deleteSelection() {
        for c in selection { ctx.delete(c) }
        selection.removeAll()
        persistChanges()
    }

    private func persistChanges() {
        do {
            try ctx.save()
        } catch {
            ctx.rollback()
            persistenceError = HistorySaveError(message: error.localizedDescription)
        }
    }

    private func share(calculation: Calculation) {
        let summary = export(calculation)
        let csv = exportCSV([calculation])
        let suggestedName = fileNamePrefix(for: calculation)

        guard let csvURL = write(content: csv, suggestedName: suggestedName, fileExtension: "csv") else { return }
        var attachments: [URL] = [csvURL]

        if let pdfData = PDFExporter.calculationSummaryPDF(calculation),
           let pdfURL = write(data: pdfData, suggestedName: suggestedName, fileExtension: "pdf") {
            attachments.append(pdfURL)
        }

        presentShare(fileURLs: attachments, plainText: summary)
    }

    private func fileNamePrefix(for calculation: Calculation) -> String {
        let defaultName = NSLocalizedString("history.filePrefix.default", tableName: "Localizable", value: "Calculation", comment: "Default file name prefix for a calculation export")
        guard let subject = calculation.subjectId?.trimmingCharacters(in: .whitespacesAndNewlines), !subject.isEmpty else {
            return defaultName
        }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let components = subject.components(separatedBy: allowed.inverted).filter { !$0.isEmpty }
        let slug = components.joined(separator: "-")
        guard !slug.isEmpty else { return defaultName }
        return String(format: NSLocalizedString("history.filePrefix.withSlug", tableName: "Localizable", value: "Calculation-%@", comment: "File name prefix for calculation export including subject slug"), slug)
    }

    private func export(_ c: Calculation) -> String {
        let subjectPlaceholder = NSLocalizedString("history.export.summary.subjectFallback", tableName: "Localizable", value: "N/A", comment: "Fallback subject identifier in history export summary")
        let subject = (c.subjectId?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? subjectPlaceholder
        let start = c.startDate.formatted(date: .abbreviated, time: .omitted)
        let end = c.endDate.formatted(date: .abbreviated, time: .omitted)
        let firstEdge = c.firstDayExpectedOverride.map(String.init) ?? NSLocalizedString("history.export.summary.edgeDaysPlaceholder", tableName: "Localizable", value: "-", comment: "Placeholder for missing first edge day in history export")
        let lastEdge = c.lastDayExpectedOverride.map(String.init) ?? NSLocalizedString("history.export.summary.edgeDaysPlaceholder", tableName: "Localizable", value: "-", comment: "Placeholder for missing last edge day in history export")
        let dispensed = String(format: "%.2f", c.dispensed)
        let returned = String(format: "%.2f", c.returned)
        let missed = String(format: "%.2f", c.missedDoses)
        let extra = String(format: "%.2f", c.extraDoses)
        let expected = String(format: "%.2f", c.expectedDoses)
        let actual = String(format: "%.2f", c.actualDoses)
        let compliance = String(format: "%.1f%%", c.compliancePct)
        let flags = friendlyFlags(for: c).joined(separator: ", ")
        let created = c.createdAt.formatted()
        let lines = [
            String(format: NSLocalizedString("history.export.summary.subject", tableName: "Localizable", value: "Subject: %@", comment: "Subject identifier line in history export summary"), subject),
            String(format: NSLocalizedString("history.export.summary.period", tableName: "Localizable", value: "Period: %@ – %@", comment: "Period line in history export summary"), start, end),
            String(format: NSLocalizedString("history.export.summary.frequency", tableName: "Localizable", value: "Frequency: %@", comment: "Frequency line in history export summary"), c.frequency.rawValue),
            String(format: NSLocalizedString("history.export.summary.edgeDays", tableName: "Localizable", value: "Edge days: first %@  last %@", comment: "Edge days line in history export summary"), firstEdge, lastEdge),
            String(format: NSLocalizedString("history.export.summary.dispensedReturned", tableName: "Localizable", value: "Dispensed: %@  Returned: %@", comment: "Dispensed/returned line in history export summary"), dispensed, returned),
            String(format: NSLocalizedString("history.export.summary.missedExtraHold", tableName: "Localizable", value: "Missed: %@  Extra: %@  Hold days: %@", comment: "Missed/extra/hold line in history export summary"), missed, extra, String(c.holdDays)),
            String(format: NSLocalizedString("history.export.summary.expectedActual", tableName: "Localizable", value: "Expected: %@  Actual: %@", comment: "Expected/actual line in history export summary"), expected, actual),
            String(format: NSLocalizedString("history.export.summary.compliance", tableName: "Localizable", value: "Compliance: %@", comment: "Compliance line in history export summary"), compliance),
            String(format: NSLocalizedString("history.export.summary.flags", tableName: "Localizable", value: "Flags: %@", comment: "Flags line in history export summary"), flags),
            String(format: NSLocalizedString("history.export.summary.created", tableName: "Localizable", value: "Created: %@", comment: "Created date line in history export summary"), created)
        ]
        return lines.joined(separator: "\n")
    }

    private func shareSelected() {
        let selected = Array(selection)
        guard !selected.isEmpty else { return }
        let csv = exportCSV(selected)
        let multiName = NSLocalizedString("history.filePrefix.multiple", tableName: "Localizable", value: "Calculations", comment: "File name prefix when exporting multiple calculations")
        guard let url = write(content: csv, suggestedName: multiName, fileExtension: "csv") else { return }
        presentShare(fileURLs: [url], plainText: csv)
    }

    private func exportCSV(_ list: [Calculation]) -> String {
        var lines: [String] = []
        let header = [
            NSLocalizedString("history.csv.header.subject", tableName: "Localizable", value: "Subject", comment: "CSV header subject column"),
            NSLocalizedString("history.csv.header.start", tableName: "Localizable", value: "Start", comment: "CSV header start column"),
            NSLocalizedString("history.csv.header.end", tableName: "Localizable", value: "End", comment: "CSV header end column"),
            NSLocalizedString("history.csv.header.frequency", tableName: "Localizable", value: "Frequency", comment: "CSV header frequency column"),
            NSLocalizedString("history.csv.header.firstDay", tableName: "Localizable", value: "FirstDay", comment: "CSV header first day column"),
            NSLocalizedString("history.csv.header.lastDay", tableName: "Localizable", value: "LastDay", comment: "CSV header last day column"),
            NSLocalizedString("history.csv.header.dispensed", tableName: "Localizable", value: "Dispensed", comment: "CSV header dispensed column"),
            NSLocalizedString("history.csv.header.returned", tableName: "Localizable", value: "Returned", comment: "CSV header returned column"),
            NSLocalizedString("history.csv.header.missed", tableName: "Localizable", value: "Missed", comment: "CSV header missed column"),
            NSLocalizedString("history.csv.header.extra", tableName: "Localizable", value: "Extra", comment: "CSV header extra column"),
            NSLocalizedString("history.csv.header.holdDays", tableName: "Localizable", value: "HoldDays", comment: "CSV header hold days column"),
            NSLocalizedString("history.csv.header.expected", tableName: "Localizable", value: "Expected", comment: "CSV header expected column"),
            NSLocalizedString("history.csv.header.actual", tableName: "Localizable", value: "Actual", comment: "CSV header actual column"),
            NSLocalizedString("history.csv.header.compliance", tableName: "Localizable", value: "Compliance", comment: "CSV header compliance column"),
            NSLocalizedString("history.csv.header.flags", tableName: "Localizable", value: "Flags", comment: "CSV header flags column"),
            NSLocalizedString("history.csv.header.created", tableName: "Localizable", value: "Created", comment: "CSV header created column"),
            NSLocalizedString("history.csv.header.drug", tableName: "Localizable", value: "Drug", comment: "CSV header drug column")
        ].joined(separator: ",")
        lines.append(header)
        let df = DateFormatter()
        df.dateStyle = .short; df.timeStyle = .none
        for c in list.sorted(by: { $0.createdAt < $1.createdAt }) {
            let row: [String] = [
                (c.subjectId ?? ""),
                df.string(from: c.startDate),
                df.string(from: c.endDate),
                c.frequency.rawValue,
                c.firstDayExpectedOverride.map(String.init) ?? "",
                c.lastDayExpectedOverride.map(String.init) ?? "",
                String(format: "%.2f", c.dispensed),
                String(format: "%.2f", c.returned),
                String(format: "%.2f", c.missedDoses),
                String(format: "%.2f", c.extraDoses),
                String(c.holdDays),
                String(format: "%.2f", c.expectedDoses),
                String(format: "%.2f", c.actualDoses),
                String(format: "%.1f", c.compliancePct),
                friendlyFlags(for: c).joined(separator: ";"),
                df.string(from: c.createdAt),
                c.drugName ?? ""
            ]
            // Escape commas and quotes minimally
            let escaped = row.map { v -> String in
                if v.contains(",") || v.contains("\"") { return "\"" + v.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
                return v
            }
            lines.append(escaped.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    private func friendlyFlags(for calculation: Calculation) -> [String] {
        calculation.flags.map { ComplianceOutputs.description(for: $0) }
    }

    private func write(content: String, suggestedName: String, fileExtension: String) -> URL? {
        guard let data = content.data(using: .utf8) else { return nil }
        return write(data: data, suggestedName: suggestedName, fileExtension: fileExtension)
    }

    private func write(data: Data, suggestedName: String, fileExtension: String) -> URL? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = formatter.string(from: Date())
        let fileName = "\(suggestedName)-\(timestamp).\(fileExtension)"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            #if DEBUG
            print("Export write failed: \(error)")
            #endif
            return nil
        }
    }

    private func presentShare(fileURLs: [URL], plainText: String? = nil) {
        cleanupURLs = fileURLs
        var items: [Any] = fileURLs
        if let plainText { items.append(plainText) }
        shareSheet = ShareSheet(activityItems: items) {
            cleanupURLs.forEach { try? FileManager.default.removeItem(at: $0) }
            cleanupURLs.removeAll()
        }
    }

    private func colorForCompliance(_ pct: Double) -> Color {
        if pct > 110 { return .orange }
        if pct < 90 { return .red }
        return .green
    }

    @ViewBuilder
    private func row(for calc: Calculation) -> some View {
        let subjectId = calc.subjectId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let subjectDisplay = subjectId.isEmpty ? NSLocalizedString("history.row.noSubject", tableName: "Localizable", value: "No Subject", comment: "Placeholder subject name in history row") : subjectId
        VStack(alignment: .leading) {
            HStack {
                Text(subjectDisplay)
                    .font(.headline)
                Spacer()
                Text(calc.frequency.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let dn = calc.drugName, !dn.isEmpty {
                Text(String(format: NSLocalizedString("history.row.investigationalProduct", tableName: "Localizable", value: "Investigational Product: %@", comment: "Investigational product label in history row"), dn))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text("\(calc.startDate.formatted(date: .abbreviated, time: .omitted)) → \(calc.endDate.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption)
            if !calc.bottles.isEmpty {
                Text(String(format: NSLocalizedString("history.row.bottlesCount", tableName: "Localizable", value: "Bottles: %@", comment: "Bottles count label in history row"), String(calc.bottles.count)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(String(format: "%.1f%%", calc.compliancePct))
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(
                    Capsule().fill(colorForCompliance(calc.compliancePct).opacity(0.12))
                )
                .foregroundStyle(colorForCompliance(calc.compliancePct))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: calc))
        .accessibilityHint(Text("history.accessibility.rowHint", tableName: "Localizable", comment: "Accessibility hint for history row"))
    }

    private func accessibilityLabel(for calc: Calculation) -> String {
        var parts: [String] = []
        if let subject = calc.subjectId?.trimmingCharacters(in: .whitespacesAndNewlines), !subject.isEmpty {
            parts.append(String(format: NSLocalizedString("history.accessibility.rowLabel.subject", tableName: "Localizable", value: "Subject %@", comment: "Accessibility subject component for history row"), subject))
        } else {
            parts.append(NSLocalizedString("history.accessibility.rowLabel.unassigned", tableName: "Localizable", value: "Unassigned subject", comment: "Accessibility subject component when missing in history row"))
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        let start = dateFormatter.string(from: calc.startDate)
        let end = dateFormatter.string(from: calc.endDate)
        let periodRange = String(format: NSLocalizedString("history.accessibility.rowLabel.periodRange", tableName: "Localizable", value: "%@ to %@", comment: "Date range for history accessibility label"), start, end)
        parts.append(String(format: NSLocalizedString("history.accessibility.rowLabel.period", tableName: "Localizable", value: "Period %@", comment: "Accessibility period component for history row"), periodRange))
        let compliance = String(format: "%.1f", calc.compliancePct)
        parts.append(String(format: NSLocalizedString("history.accessibility.rowLabel.compliance", tableName: "Localizable", value: "Compliance %@ percent", comment: "Accessibility compliance component for history row"), compliance))
        if !calc.flags.isEmpty {
            let flagDescriptions = friendlyFlags(for: calc)
            parts.append(String(format: NSLocalizedString("history.accessibility.rowLabel.flags", tableName: "Localizable", value: "Flags %@", comment: "Accessibility flags component for history row"), flagDescriptions.joined(separator: ", ")))
        }
        return parts.joined(separator: ", ")
    }
}

struct ShareSheet: UIViewControllerRepresentable, Identifiable {
    let id = UUID()
    var activityItems: [Any]
    var onDismiss: (() -> Void)? = nil
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            onDismiss?()
        }
        return controller
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct HistorySaveError: Identifiable {
    let id = UUID()
    let message: String
}

#if DEBUG
import SwiftData
struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { HistoryPreviewSeed() }
            .modelContainer(for: [Calculation.self, Bottle.self, Study.self, Subject.self])
    }
}

private struct HistoryPreviewSeed: View {
    @Environment(\.modelContext) private var ctx
    private static var didSeed = false
    var body: some View {
        HistoryView()
            .onAppear {
                guard !Self.didSeed else { return }
                Self.didSeed = true
                seed()
            }
    }

    private func seed() {
        let now = Date()
        let start1 = Calendar.current.date(byAdding: .day, value: -14, to: now) ?? now
        let start2 = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now

        let b1 = Bottle(label: "Bottle A", dispensed: 60, returned: 5)
        let b2 = Bottle(label: "Bottle B", dispensed: 30, returned: 2)

        let c1 = Calculation()
        c1.subjectId = "SUBJ001"
        c1.startDate = start1
        c1.endDate = now
        c1.frequency = .bid
        c1.dispensed = 90
        c1.returned = 7
        c1.expectedDoses = 28 * 2
        c1.actualDoses = 83
        c1.compliancePct = 96
        c1.flags = ["OVERUSE"]
        c1.createdAt = now
        c1.bottles = [b1, b2]

        let c2 = Calculation()
        c2.subjectId = "SUBJ002"
        c2.startDate = start2
        c2.endDate = start1
        c2.frequency = .qd
        c2.dispensed = 30
        c2.returned = 10
        c2.expectedDoses = 16
        c2.actualDoses = 20
        c2.compliancePct = 125
        c2.flags = ["OVERUSE"]
        c2.createdAt = now.addingTimeInterval(-3600)

        ctx.insert(c1)
        ctx.insert(c2)
        try? ctx.save()
    }
}
#endif
