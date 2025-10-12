import SwiftUI
import SwiftData

struct StudiesView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: [SortDescriptor(\Study.createdAt, order: .reverse)]) private var studies: [Study]

    @State private var showNew = false
    @State private var newName = ""
    @State private var newFreq: DosingFrequency = .qd
    @State private var newPartials: Bool = false
    @State private var newPrnTargetPerDay: String = ""
    @State private var newNotes: String = ""
    @State private var newMultiDrug: Bool = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(studies) { s in
                    NavigationLink(destination: StudyDetailView(study: s)) {
                        HStack(spacing: 12) {
                            Image(systemName: "book.fill")
                                .font(.title3)
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(s.name).font(.headline)
                                HStack(spacing: 12) {
                                    if let notes = s.notes, !notes.isEmpty {
                                        Text(notes).lineLimit(1).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Text("\(s.subjects.count) subjects").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .onDelete(perform: delete)
            }
            .navigationTitle("Studies")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNew = true } label: { Label("New Study", systemImage: "plus") }
                }
            }
            .sheet(isPresented: $showNew) { newStudySheet }
            .listStyle(.insetGrouped)
            .studyCoorBackground()
        }
    }

    private var newStudySheet: some View {
        NavigationStack {
            Form {
                Section("Basics") {
                    TextField("Study name", text: $newName)
                    TextField("Notes (optional)", text: $newNotes)
                }
                Section {
                    Picker("Dosing frequency", selection: $newFreq) {
                        ForEach(DosingFrequency.allCases) { f in Text(f.rawValue).tag(f) }
                    }
                    if newFreq == .prn {
                        TextField("PRN target doses/day (optional)", text: $newPrnTargetPerDay).keyboardType(.decimalPad)
                    }
                    Toggle("Allow partial doses", isOn: $newPartials)
                    Toggle("Multi-drug study", isOn: $newMultiDrug)
                } header: { Label("Defaults", systemImage: "slider.horizontal.3") }
            }
            .navigationTitle("New Study")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showNew = false; newName = "" } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createStudy() }.disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func createStudy() {
        let prn = NumericFormatter.parseLocalized(newPrnTargetPerDay)
        let notes = newNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let study = Study(
            name: newName,
            notes: notes.isEmpty ? nil : notes,
            defaultFrequency: newFreq,
            defaultPartialDoseEnabled: newPartials,
            defaultPrnTargetPerDay: prn,
            multiDrug: newMultiDrug
        )
        ctx.insert(study)
        try? ctx.save()
        newName = ""; newNotes = ""; newFreq = .qd; newPartials = false; newPrnTargetPerDay = ""; newMultiDrug = false
        showNew = false
    }

    private func delete(at offsets: IndexSet) {
        for i in offsets { ctx.delete(studies[i]) }
        try? ctx.save()
    }
}


#if DEBUG
import SwiftData
struct StudiesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { StudiesPreviewSeed() }
            .modelContainer(for: [Calculation.self, Bottle.self, Study.self, Subject.self])
    }
}

private struct StudiesPreviewSeed: View {
    @Environment(\.modelContext) private var ctx
    private static var didSeed = false
    var body: some View {
        StudiesView()
            .onAppear {
                guard !Self.didSeed else { return }
                Self.didSeed = true
                seed()
            }
    }

    private func seed() {
        let s1 = Study(name: "Hypertension A", notes: "Phase 2", defaultFrequency: .qd)
        let s2 = Study(name: "Diabetes B", notes: "Longitudinal", defaultFrequency: .bid)
        let subj1 = Subject(code: "SUBJ001", displayName: "Alice", study: s1)
        let subj2 = Subject(code: "SUBJ002", displayName: "Bob", study: s1)
        s1.subjects.append(contentsOf: [subj1, subj2])
        ctx.insert(s1)
        ctx.insert(s2)
        try? ctx.save()
    }
}
#endif
