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
                ForEach(items) { calc in
                    NavigationLink {
                        CalculationDetailView(calculation: calc)
                    } label: {
                        row(for: calc)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) { delete(calculation: calc) } label: { Label("Delete", systemImage: "trash") }
                        Button { share(calculation: calc) } label: { Label("Share", systemImage: "square.and.arrow.up") }
                    }
                    .contextMenu {
                        Button("Share", action: { share(calculation: calc) })
                        Button(role: .destructive, action: { delete(calculation: calc) }) {
                            Text("Delete")
                        }
                    }
                }
                .onDelete(perform: delete)
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .listStyle(.insetGrouped)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !selection.isEmpty {
                        Button { shareSelected() } label: { Label("Share", systemImage: "square.and.arrow.up") }
                        Button(role: .destructive) { deleteSelection() } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
            .studyCoorBackground()
            .sheet(item: $shareSheet) { sheet in
                sheet
            }
            .alert(item: $persistenceError) { error in
                Alert(
                    title: Text("Unable to save changes"),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
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
        let content = export(calculation)
        guard let url = write(content: content, suggestedName: "Calculation", fileExtension: "txt") else { return }
        presentShare(fileURL: url, plainText: content)
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
        Flags: \(friendlyFlags(for: c).joined(separator: ", "))
        Created: \(c.createdAt.formatted())
        """
    }

    private func shareSelected() {
        let selected = Array(selection)
        guard !selected.isEmpty else { return }
        let csv = exportCSV(selected)
        guard let url = write(content: csv, suggestedName: "Calculations", fileExtension: "csv") else { return }
        presentShare(fileURL: url, plainText: csv)
    }

    private func exportCSV(_ list: [Calculation]) -> String {
        var lines: [String] = []
        let header = [
            "Subject","Start","End","Frequency","FirstDay","LastDay","Dispensed","Returned","Missed","Extra","HoldDays","Expected","Actual","Compliance","Flags","Created","Drug"
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
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = formatter.string(from: Date())
        let fileName = "\(suggestedName)-\(timestamp).\(fileExtension)"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            print("Export write failed: \(error)")
            return nil
        }
    }

    private func presentShare(fileURL: URL, plainText: String? = nil) {
        cleanupURLs = [fileURL]
        var items: [Any] = [fileURL]
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
        VStack(alignment: .leading) {
            HStack {
                Text(calc.subjectId ?? "No Subject")
                    .font(.headline)
                Spacer()
                Text(calc.frequency.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let dn = calc.drugName, !dn.isEmpty {
                Text("Investigational Product: \(dn)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text("\(calc.startDate.formatted(date: .abbreviated, time: .omitted)) → \(calc.endDate.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption)
            if !calc.bottles.isEmpty {
                Text("Bottles: \(calc.bottles.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text(String(format: "%.1f%%", calc.compliancePct))
                    .font(.subheadline.weight(.semibold))
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        Capsule().fill(colorForCompliance(calc.compliancePct).opacity(0.12))
                    )
                    .foregroundStyle(colorForCompliance(calc.compliancePct))

                let friendlyFlags = calc.flags.map { ComplianceOutputs.description(for: $0) }
                if !friendlyFlags.isEmpty {
                    WrapRow(friendlyFlags) { flag in
                        Text(flag)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.thinMaterial, in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct WrapRow<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let content: (Data.Element) -> Content

    init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.content = content
    }

    var body: some View {
        FlexibleWrapView(data: data, spacing: 8, content: content)
    }
}

private struct FlexibleWrapView<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let spacing: CGFloat
    let content: (Data.Element) -> Content

    @State private var sizes: [Data.Element: CGSize] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            let rows = computeRows()
            ForEach(Array(rows.enumerated()), id: \.offset) { row in
                HStack(spacing: spacing) {
                    ForEach(row.element, id: \.self) { element in
                        content(element)
                            .fixedSize()
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .onAppear {
                                            sizes[element] = geo.size
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
        var currentWidth: CGFloat = 0
        let maxWidth = 240.0

        for element in data {
            let elementSize = sizes[element, default: .zero]
            let width = elementSize.width == 0 ? maxWidth : elementSize.width
            let tentativeWidth = currentWidth == 0 ? width : currentWidth + spacing + width
            if tentativeWidth > maxWidth, !rows[rows.count - 1].isEmpty {
                rows.append([element])
                currentWidth = width
            } else {
                rows[rows.count - 1].append(element)
                currentWidth = tentativeWidth
            }
        }
        return rows
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
