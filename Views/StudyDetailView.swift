import SwiftUI
import SwiftData

struct StudyDetailView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var study: Study

    @State private var showNewSubject = false
    @State private var code = ""
    @State private var displayName = ""
    @State private var showSavedToast = false
    @State private var showNewDrug = false
    @State private var drugName = ""
    @State private var drugNotes = ""
    @State private var drugFreq: DosingFrequency = .qd
    @State private var drugPartials = false
    @State private var drugPrnTarget: String = ""
    @State private var editDrug: Drug? = nil

    var body: some View {
        List {
            Section {
                TextField("Study name", text: $study.name)
                TextField("Notes", text: Binding<String>(
                    get: { study.notes ?? "" },
                    set: { study.notes = $0.isEmpty ? nil : $0 }
                ))
            } header: { Label("Study", systemImage: "book") }

            Section {
                Picker("Frequency", selection: $study.defaultFrequency) {
                    ForEach(DosingFrequency.allCases) { f in Text(f.rawValue).tag(f) }
                }
                Toggle("Allow partial doses", isOn: $study.defaultPartialDoseEnabled)
                let prnBinding = Binding<String>(
                    get: { study.defaultPrnTargetPerDay.map { String(format: "%.2f", $0) } ?? "" },
                    set: { study.defaultPrnTargetPerDay = Double($0) }
                )
                TextField("PRN target/day (optional)", text: prnBinding)
                    .keyboardType(.decimalPad)
                    .numericValidation(text: prnBinding, allowPartials: true)
                Toggle("Multiple Investigational Products", isOn: $study.multiDrug)
            } header: { Label("Defaults", systemImage: "slider.horizontal.3") }

            if study.multiDrug {
                Section {
                    if study.drugs.isEmpty { Text("No investigational products yet. Add one with +.").foregroundStyle(.secondary) }
                    ForEach(study.drugs) { drug in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(drug.name).font(.headline)
                                Spacer()
                                Text(drug.defaultFrequency.rawValue).font(.caption).foregroundStyle(.secondary)
                            }
                            if let n = drug.notes, !n.isEmpty { Text(n).font(.caption).foregroundStyle(.secondary) }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { beginEdit(drug) }
                    }
                    .onDelete(perform: deleteDrugs)
                    Button { showNewDrug = true } label: { Label("Add Investigational Product", systemImage: "pills") }
                } header: { Label("Investigational Products", systemImage: "pills") }
            }

            Section {
                if study.subjects.isEmpty {
                    Text("No subjects yet. Add one with +.").foregroundStyle(.secondary)
                }
                ForEach(study.subjects) { subj in
                    NavigationLink(destination: SubjectDetailView(subject: subj)) {
                        VStack(alignment: .leading) {
                            Text(subj.displayName?.isEmpty == false ? (subj.displayName ?? subj.code) : subj.code)
                                .font(.headline)
                            if let nm = subj.displayName, !nm.isEmpty && nm != subj.code {
                                Text(nm).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteSubjects)
            } header: { Label("Subjects", systemImage: "person.2") }
        }
        .navigationTitle(study.name)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    try? ctx.save(); showSavedToast = true
                } label: { Label("Save", systemImage: "checkmark.circle") }
            }
            ToolbarItem(placement: .topBarTrailing) { Button { showNewSubject = true } label: { Image(systemName: "plus") } }
        }
        .sheet(isPresented: $showNewSubject) { newSubjectSheet }
        .sheet(isPresented: $showNewDrug) { newDrugSheet }
        .listStyle(.insetGrouped)
        .studyCoorBackground()
    }

    private var newSubjectSheet: some View {
        NavigationStack {
            Form {
                TextField("Subject code", text: $code)
                    .textInputAutocapitalization(.characters)
                TextField("Display name (optional)", text: $displayName)
            }
            .navigationTitle("New Subject")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showNewSubject = false; code = ""; displayName = "" } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createSubject() }
                        .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func createSubject() {
        let subj = Subject(code: code, displayName: displayName.isEmpty ? nil : displayName, study: study)
        study.subjects.append(subj)
        ctx.insert(subj)
        try? ctx.save()
        code = ""; displayName = ""; showNewSubject = false
    }

    private func deleteSubjects(at offsets: IndexSet) {
        for i in offsets { ctx.delete(study.subjects[i]) }
        try? ctx.save()
    }
}


private extension StudyDetailView {
    var newDrugSheet: some View {
        NavigationStack {
            Form {
                Section("Basics") {
                    TextField("Drug name", text: $drugName)
                    TextField("Notes (optional)", text: $drugNotes)
                }
                Section("Defaults") {
                    Picker("Frequency", selection: $drugFreq) { ForEach(DosingFrequency.allCases) { Text($0.rawValue).tag($0) } }
                    Toggle("Allow partial doses", isOn: $drugPartials)
                    TextField("PRN target/day (optional)", text: $drugPrnTarget)
                        .keyboardType(.decimalPad)
                        .numericValidation(text: $drugPrnTarget, allowPartials: true)
                }
            }
            .navigationTitle(editDrug == nil ? "New Investigational Product" : "Edit Investigational Product")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { cancelDrugEdit() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { saveDrug() }.disabled(drugName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }
        }
    }

    func beginEdit(_ d: Drug) {
        editDrug = d
        drugName = d.name
        drugNotes = d.notes ?? ""
        drugFreq = d.defaultFrequency
        drugPartials = d.defaultPartialDoseEnabled
        drugPrnTarget = d.defaultPrnTargetPerDay.map { String($0) } ?? ""
        showNewDrug = true
    }

    func cancelDrugEdit() {
        editDrug = nil
        drugName = ""; drugNotes = ""; drugFreq = .qd; drugPartials = false; drugPrnTarget = ""
        showNewDrug = false
    }

    func saveDrug() {
        let prn = Double(drugPrnTarget)
        if let edit = editDrug {
            edit.name = drugName
            edit.notes = drugNotes.isEmpty ? nil : drugNotes
            edit.defaultFrequency = drugFreq
            edit.defaultPartialDoseEnabled = drugPartials
            edit.defaultPrnTargetPerDay = prn
        } else {
            let d = Drug(name: drugName, notes: drugNotes.isEmpty ? nil : drugNotes, defaultFrequency: drugFreq, defaultPartialDoseEnabled: drugPartials, defaultPrnTargetPerDay: prn, study: study)
            study.drugs.append(d)
            ctx.insert(d)
        }
        try? ctx.save()
        cancelDrugEdit()
    }

    func deleteDrugs(at offsets: IndexSet) {
        for i in offsets { ctx.delete(study.drugs[i]) }
        try? ctx.save()
    }
}
