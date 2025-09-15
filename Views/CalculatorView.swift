import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct CalculatorView: View {
    // Optional prefill support
    struct Prefill {
        var subjectId: String?
        var frequency: DosingFrequency
        var partials: Bool
        var prnTargetPerDay: Double?
        var studyName: String?
    }

    private var prefillRef: Prefill?

    init(prefill: Prefill? = nil) {
        self.prefillRef = prefill
        if let p = prefill {
            _subjectId = State(initialValue: p.subjectId ?? "")
            _frequency = State(initialValue: p.frequency)
            _partials = State(initialValue: p.partials)
            _prnTargetPerDay = State(initialValue: p.prnTargetPerDay.map { String(format: "%.2f", $0) } ?? "")
        } else {
            self.prefillRef = nil
        }
    }
    @Environment(\.modelContext) private var ctx
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: [SortDescriptor(\Study.createdAt, order: .reverse)]) private var studies: [Study]
    @State private var selectedStudy: Study? = nil
    @State private var selectedSubject: Subject? = nil
    @State private var selectedDrug: Drug? = nil
    // Per-IP bottle inputs and results (multi-IP studies)
    @State private var drugBottles: [String: [BottleInput]] = [:]
    @State private var multiResults: [String: ComplianceOutputs] = [:]
    @State private var showNewSubjectSheet = false
    @State private var tempSubjectName = ""
    @State private var showNewStudySheet = false
    @State private var newStudyName = ""
    @State private var newStudyNotes = ""
    @State private var newStudyFreq: DosingFrequency = .qd
    @State private var newStudyPartials = false
    @State private var newStudyPRNTarget = ""

    @AppStorage("lastStudyName") private var lastStudyName: String = ""
    @AppStorage("lastSubjectCode") private var lastSubjectCode: String = ""

    @State private var subjectId = ""
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -28, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var frequency: DosingFrequency = .qd

    // Aggregate fields (used when no bottles or as quick entry)
    @State private var dispensed: String = ""
    @State private var returned: String = ""
    @State private var missed: String   = ""
    @State private var extra: String    = ""
    @State private var holdDays: String = ""
    @State private var partials = false
    @State private var prnTargetPerDay: String = ""

    @State private var result: ComplianceOutputs?
    @AppStorage("showHowWeCalculated") private var showExplain = true
    @State private var errorMsg: String?

    // Multiple bottles
    @State private var bottles: [BottleInput] = []

    // Edge-day expected overrides
    @State private var firstDayCount: Int? = nil
    @State private var lastDayCount: Int? = nil

    @FocusState private var isNumericFieldFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                // Title uses standard Navigation Bar (Option 2)
                // Study & Subject quick selectors
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(studies) { s in
                                Chip(title: s.name, selected: selectedStudy?.id == s.id) {
                                    withAnimation { selectStudy(s) }
                                }
                            }
                            Button { showNewStudySheet = true } label: { Label("New", systemImage: "plus.circle") }
                                .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 4)
                    }
                    if let s = selectedStudy, !s.subjects.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(s.subjects) { subj in
                                    SubjectChip(
                                        title: subj.displayName ?? subj.code,
                                        badge: lastComplianceText(for: subj),
                                        badgeColor: colorForCompliance(lastComplianceValue(for: subj) ?? 0),
                                        selected: selectedSubject?.id == subj.id,
                                        action: { withAnimation { selectSubject(subj) } }
                                    )
                                }
                                Button {
                                    showNewSubjectSheet = true
                                } label: {
                                    Label("New", systemImage: "plus.circle")
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    if let s = selectedStudy, s.multiDrug, !s.drugs.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(s.drugs) { d in
                                    Chip(title: d.name, selected: selectedDrug?.id == d.id) {
                                        withAnimation { selectDrug(d) }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    HStack {
                        Label("Study & Subject", systemImage: "rectangle.and.pencil.and.ellipsis")
                        Spacer()
                        NavigationLink(destination: StudiesView()) {
                            Label("Manage", systemImage: "gearshape")
                        }
                        .font(.caption)
                    }
                } footer: {
                    Text("Selecting a study applies its defaults; choosing a subject fills Subject ID.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("Subject (optional)") {
                    TextField("Subject ID", text: $subjectId)
                        .textInputAutocapitalization(.characters)
                }

                // Calculate action placed under Subject ID for visibility
                Section {
                    Button {
                        calculate()
                    } label: {
                        Text("Calculate")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(LinearGradient(colors: [.blue, .green], startPoint: .leading, endPoint: .trailing))
                            )
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }

                // Per-IP results (multi-IP) or single result card moved directly below Subject section
                if let s = selectedStudy, s.multiDrug, !multiResults.isEmpty {
                    Section {
                        ForEach(s.drugs) { d in
                            if let r = multiResults[d.name] {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(LinearGradient(colors: [.blue.opacity(0.15), .green.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(d.name).font(.headline)
                                        Text(String(format: "Expected: %.2f", r.expectedDoses))
                                        Text(String(format: "Actual: %.2f",   r.actualDoses))
                                        Gauge(value: min(150, max(0, r.compliancePct)), in: 0...150) { Text("Compliance") } currentValueLabel: { Text(String(format: "%.1f%%", r.compliancePct)) } minimumValueLabel: { Text("0%") } maximumValueLabel: { Text("150%") }
                                            .tint(colorForCompliance(r.compliancePct))
                                            .gaugeStyle(.accessoryLinear)
                                        if !r.flags.isEmpty { Text("Flags: \(r.flags.joined(separator: ", "))").foregroundStyle(.secondary) }
                                    }
                                    .padding(12)
                                }
                            }
                        }
                    } header: { Label("Results", systemImage: "gauge") }
                }
                else if let result {
                    Section {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(LinearGradient(colors: [.blue.opacity(0.15), .green.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            VStack(alignment: .leading, spacing: 8) {
                                Text(String(format: "Expected: %.2f", result.expectedDoses))
                                Text(String(format: "Actual: %.2f",   result.actualDoses))
                                Gauge(value: min(150, max(0, result.compliancePct)), in: 0...150) {
                                    Text("Compliance")
                                } currentValueLabel: {
                                    Text(String(format: "%.1f%%", result.compliancePct))
                                } minimumValueLabel: {
                                    Text("0%")
                                } maximumValueLabel: {
                                    Text("150%")
                                }
                                .tint(colorForCompliance(result.compliancePct))
                                .gaugeStyle(.accessoryLinear)
                                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: result.compliancePct)
                                if !result.flags.isEmpty {
                                    Text("Flags: \(result.flags.joined(separator: ", "))")
                                        .foregroundStyle(.secondary)
                                }
                                if showExplain {
                                    Text("How we calculated this: expected is based on frequency × effective days (period minus holds), adjusted for first/last day overrides. Actual is dispensed − returned − missed + extra, clamped at 0 and rounded when partials are off.")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(12)
                        }
                    } header: {
                        Label("Result", systemImage: "gauge")
                    }
                }

                Section("Period") {
                    DatePicker("Start", selection: $startDate, displayedComponents: .date)
                    DatePicker("End", selection: $endDate, displayedComponents: .date)
                }

                Section("Regimen") {
                    Picker("Frequency", selection: $frequency) {
                        ForEach(DosingFrequency.allCases) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                    if frequency == .prn {
                        TextField("PRN target doses/day (optional)", text: $prnTargetPerDay)
                            .keyboardType(.decimalPad)
                            .numericValidation(text: $prnTargetPerDay, allowPartials: true)
                    }
                    Toggle("Allow partial doses", isOn: $partials)
                }

                if frequency != .prn && Int(frequency.dosesPerDay) > 0 {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            LabeledContent("First day") {
                                DoseSelector(maxCount: Int(frequency.dosesPerDay), selection: $firstDayCount)
                            }
                            LabeledContent("Last day") {
                                DoseSelector(maxCount: Int(frequency.dosesPerDay), selection: $lastDayCount)
                            }
                        }
                        Text("Adjust how many doses were expected on the first and last calendar day. Defaults to the full daily frequency when unset.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } header: {
                        Label("Edge Day Intake", systemImage: "calendar.badge.clock")
                    }
                }

                // Default single bottle section only when not a multi-IP study
                if (selectedStudy?.multiDrug != true) || ((selectedStudy?.drugs.isEmpty) ?? true) {
                    Section {
                        if bottles.isEmpty {
                            Text("No bottles added. Use + to add.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach($bottles) { $b in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    TextField("Label", text: $b.label)
                                    Spacer()
                                    Button(role: .destructive) {
                                        bottles.removeAll { $0.id == b.id }
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel("Delete bottle")
                                }
                                HStack {
                                    TextField("Dispensed", text: $b.dispensed)
                                        .keyboardType(.decimalPad)
                                        .focused($isNumericFieldFocused)
                                        .numericValidation(text: $b.dispensed, allowPartials: partials)
                                    TextField("Returned", text: $b.returned)
                                        .keyboardType(.decimalPad)
                                        .focused($isNumericFieldFocused)
                                        .numericValidation(text: $b.returned, allowPartials: partials)
                                }
                                .textFieldStyle(.roundedBorder)
                            }
                        }
                        HStack {
                            Button { bottles.append(BottleInput()) } label: { Label("Add Bottle", systemImage: "plus.circle.fill") }
                        }
                    } header: { Label("Bottles", systemImage: "shippingbox") } footer: { Text("If you add bottles, their totals replace Quick Totals for dispensed/returned.").font(.caption).foregroundStyle(.secondary) }
                }

                // Multi-IP bottles: a section per Investigational Product
                if let s = selectedStudy, s.multiDrug {
                    ForEach(s.drugs) { d in
                        Section {
                            let binding = Binding<[BottleInput]>(
                                get: { drugBottles[d.name] ?? [] },
                                set: { drugBottles[d.name] = $0 }
                            )
                            if (drugBottles[d.name] ?? []).isEmpty {
                                Text("No bottles for \(d.name). Use + to add.")
                                    .foregroundStyle(.secondary)
                            }
                            ForEach(binding) { $b in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        TextField("Label", text: $b.label)
                                        Spacer()
                                        Button(role: .destructive) {
                                            var arr = drugBottles[d.name] ?? []
                                            arr.removeAll { $0.id == b.id }
                                            drugBottles[d.name] = arr
                                        } label: { Image(systemName: "trash") }
                                        .buttonStyle(.borderless)
                                    }
                                    HStack {
                                        TextField("Dispensed", text: $b.dispensed)
                                            .keyboardType(.decimalPad)
                                            .focused($isNumericFieldFocused)
                                            .numericValidation(text: $b.dispensed, allowPartials: partials)
                                        TextField("Returned", text: $b.returned)
                                            .keyboardType(.decimalPad)
                                            .focused($isNumericFieldFocused)
                                            .numericValidation(text: $b.returned, allowPartials: partials)
                                    }
                                    .textFieldStyle(.roundedBorder)
                                }
                            }
                            HStack {
                                Button {
                                    var arr = drugBottles[d.name] ?? []
                                    arr.append(BottleInput())
                                    drugBottles[d.name] = arr
                                } label: { Label("Add Bottle", systemImage: "plus.circle.fill") }
                            }
                        } header: { Label("Bottles – \(d.name)", systemImage: "shippingbox") }
                    }
                }

                // Show Quick Totals only for single-IP (or when no IPs have been defined yet)
                if (selectedStudy?.multiDrug != true) || ((selectedStudy?.drugs.isEmpty) ?? true) {
                    Section {
                        Text("Use when you’re not itemizing bottles.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Dispensed (tabs)", text: $dispensed)
                            .keyboardType(.decimalPad)
                            .focused($isNumericFieldFocused)
                            .numericValidation(text: $dispensed, allowPartials: partials)
                        TextField("Returned (tabs)", text: $returned)
                            .keyboardType(.decimalPad)
                            .focused($isNumericFieldFocused)
                            .numericValidation(text: $returned, allowPartials: partials)
                        TextField("Missed doses (expected but not taken, optional)", text: $missed)
                            .keyboardType(.decimalPad)
                            .focused($isNumericFieldFocused)
                            .numericValidation(text: $missed, allowPartials: partials)
                        TextField("Extra doses (taken beyond schedule, optional)", text: $extra)
                            .keyboardType(.decimalPad)
                            .focused($isNumericFieldFocused)
                            .numericValidation(text: $extra, allowPartials: partials)
                        TextField("Hold days (days paused, optional)", text: $holdDays)
                            .keyboardType(.numberPad)
                            .focused($isNumericFieldFocused)
                            .integerValidation(text: $holdDays)
                    } header: {
                        Label("Quick Totals", systemImage: "sum")
                    } footer: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Actual = (Dispensed − Returned) − Missed + Extra")
                            Text("Hold days reduce expected doses. Bottles override Dispensed/Returned here.")
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }
                }

                // (Result section moved above under Subject)

                if let errorMsg {
                    Section { Text(errorMsg).foregroundStyle(.red) }
                }
            }
            .navigationTitle("StudyCoorCalc")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation { bottles.append(BottleInput()) }
                    } label: {
                        Label("Add Bottle", systemImage: "plus.circle")
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { dismissKeyboard() }
                }
            }
            .studyCoorBackground()
            .toolbarBackground(Color(.systemBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            // Add a small buffer below the navigation bar, helpful in dark mode
            .safeAreaInset(edge: .top, spacing: 0) {
                Color(.systemBackground).opacity(0.001).frame(height: 8)
            }
            .onAppear { applyPrefillSelectionIfNeeded() }
            .onChange(of: studies.count) { _, _ in applyPrefillSelectionIfNeeded() }
            .sheet(isPresented: $showNewSubjectSheet) { newSubjectSheet }
            .sheet(isPresented: $showNewStudySheet) { newStudySheet }
        }
    }

    private func calculate() {
        // Parse inputs safely
        if let s = selectedStudy, s.multiDrug {
            // Per-IP calculations based on per-IP bottles. Global quick totals and adjustments are not applied per-IP in this first pass.
            var results: [String: ComplianceOutputs] = [:]
            for d in s.drugs {
                let (bd, br, models) = parseBottles(forDrugNamed: d.name)
                let disp = bd ?? 0
                let ret  = br ?? 0
                let holds = Int(holdDays) ?? 0
                let prnTarget: Double? = d.defaultPrnTargetPerDay
                let freq = d.defaultFrequency

                let inputs = ComplianceInputs(
                    dispensed: disp,
                    returned: ret,
                    startDate: startDate,
                    endDate: endDate,
                    frequency: freq,
                    missedDoses: 0,
                    extraDoses: 0,
                    holdDays: holds,
                    partialDoseEnabled: d.defaultPartialDoseEnabled,
                    prnTargetPerDay: prnTarget,
                    firstDayExpectedOverride: firstDayCount,
                    lastDayExpectedOverride: lastDayCount
                )
                do {
                    let out = try ComplianceEngine.compute(inputs)
                    results[d.name] = out
                    // Persist per-IP record
                    let record = Calculation()
                    record.subjectId = subjectId.isEmpty ? nil : subjectId
                    record.drugName = d.name
                    record.startDate = startDate
                    record.endDate = endDate
                    record.frequency = freq
                    record.dispensed = disp
                    record.returned = ret
                    record.missedDoses = 0
                    record.extraDoses = 0
                    record.holdDays = holds
                    record.partialDoseEnabled = d.defaultPartialDoseEnabled
                    record.prnTargetPerDay = prnTarget
                    record.firstDayExpectedOverride = firstDayCount
                    record.lastDayExpectedOverride = lastDayCount
                    record.expectedDoses = out.expectedDoses
                    record.actualDoses = out.actualDoses
                    record.compliancePct = out.compliancePct
                    record.flags = out.flags
                    record.createdAt = .now
                    record.bottles = models
                    ctx.insert(record)
                } catch {
                    self.errorMsg = error.localizedDescription
                }
            }
            try? ctx.save()
            self.multiResults = results
            self.result = nil
            notifySuccess()
        } else {
            let (bottleDisp, bottleRet, bottleModels) = parseBottles()
            let disp = bottleDisp ?? (Double(dispensed) ?? 0)
            let ret  = bottleRet  ?? (Double(returned)  ?? 0)
            let miss = Double(missed)    ?? 0
            let ext  = Double(extra)     ?? 0
            let holds = Int(holdDays)    ?? 0
            let prnTarget: Double? = Double(prnTargetPerDay)

            let inputs = ComplianceInputs(
                dispensed: disp,
                returned: ret,
                startDate: startDate,
                endDate: endDate,
                frequency: frequency,
                missedDoses: miss,
                extraDoses: ext,
                holdDays: holds,
                partialDoseEnabled: partials,
                prnTargetPerDay: prnTarget,
                firstDayExpectedOverride: firstDayCount,
                lastDayExpectedOverride: lastDayCount
            )

            do {
                let out = try ComplianceEngine.compute(inputs)
                self.result = out
                self.errorMsg = nil
                notifySuccess()

                let record = Calculation()
                record.subjectId = subjectId.isEmpty ? nil : subjectId
                record.drugName = selectedDrug?.name
                record.startDate = startDate
                record.endDate = endDate
                record.frequency = frequency
                record.dispensed = disp
                record.returned = ret
                record.missedDoses = miss
                record.extraDoses = ext
                record.holdDays = holds
                record.partialDoseEnabled = partials
                record.prnTargetPerDay = prnTarget
                record.firstDayExpectedOverride = firstDayCount
                record.lastDayExpectedOverride = lastDayCount
                record.expectedDoses = out.expectedDoses
                record.actualDoses = out.actualDoses
                record.compliancePct = out.compliancePct
                record.flags = out.flags
                record.createdAt = .now
                record.bottles = bottleModels
                ctx.insert(record)
                try? ctx.save()
            } catch {
                self.result = nil
                self.errorMsg = error.localizedDescription
                notifyError()
            }
        }
    }

    private func colorForCompliance(_ pct: Double) -> Color {
        if pct > 110 { return .orange }
        if pct < 90  { return .red }
        return .green
    }

    private func dismissKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }

    private func applyPrefillSelectionIfNeeded() {
        // If already set, skip
        if selectedStudy != nil || selectedSubject != nil { return }

        if let p = prefillRef {
            if let name = p.studyName, let s = studies.first(where: { $0.name == name }) {
                selectStudy(s)
                if let code = p.subjectId, let subj = s.subjects.first(where: { $0.code == code }) {
                    selectSubject(subj)
                }
                return
            }
            if let code = p.subjectId {
                if let pair = studies.compactMap({ s in s.subjects.first(where: { $0.code == code }).map { (s, $0) } }).first {
                    selectStudy(pair.0)
                    selectSubject(pair.1)
                    return
                }
            }
        }

        // Fall back to persisted last selections
        if !lastStudyName.isEmpty, let s = studies.first(where: { $0.name == lastStudyName }) {
            selectStudy(s)
            if !lastSubjectCode.isEmpty, let subj = s.subjects.first(where: { $0.code == lastSubjectCode }) {
                selectSubject(subj)
            }
        }
    }

    private func selectStudy(_ s: Study) {
        selectedStudy = s
        lastStudyName = s.name
        // Apply study defaults
        frequency = s.defaultFrequency
        partials = s.defaultPartialDoseEnabled
        prnTargetPerDay = s.defaultPrnTargetPerDay.map { String(format: "%.2f", $0) } ?? ""
        // Reset selected subject when changing study
        selectedSubject = nil
        lastSubjectCode = ""
        // Preselect first drug if multi-drug
        if s.multiDrug, let first = s.drugs.first { selectDrug(first) } else { selectedDrug = nil }
    }

    private func selectSubject(_ subj: Subject) {
        selectedSubject = subj
        subjectId = subj.code
        lastSubjectCode = subj.code
    }

    private func selectDrug(_ d: Drug) {
        selectedDrug = d
        // Apply drug defaults overriding study defaults
        frequency = d.defaultFrequency
        partials = d.defaultPartialDoseEnabled
        prnTargetPerDay = d.defaultPrnTargetPerDay.map { String(format: "%.2f", $0) } ?? ""
    }

    private func lastComplianceValue(for subject: Subject) -> Double? {
        let codeOpt: String? = subject.code
        let desc = FetchDescriptor<Calculation>(
            predicate: #Predicate { $0.subjectId == codeOpt },
            sortBy: [SortDescriptor(\Calculation.createdAt, order: .reverse)]
        )
        if let c = try? ctx.fetch(desc).first {
            return c.compliancePct
        }
        return nil
    }

    private func lastComplianceText(for subject: Subject) -> String? {
        guard let v = lastComplianceValue(for: subject) else { return nil }
        return String(format: "%.0f%%", v)
    }

    private func notifySuccess() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    private func notifyError() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }


    // MARK: - Inline creation sheets
    private var newSubjectSheet: some View {
        NavigationStack {
            Form {
                TextField("Subject code", text: $subjectId)
                    .textInputAutocapitalization(.characters)
                TextField("Display name (optional)", text: $tempSubjectName)
            }
            .navigationTitle("New Subject")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showNewSubjectSheet = false; tempSubjectName = "" } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createInlineSubject() }
                        .disabled(subjectId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedStudy == nil)
                }
            }
        }
    }

    private var newStudySheet: some View {
        NavigationStack {
            Form {
                Section("Basics") {
                    TextField("Study name", text: $newStudyName)
                    TextField("Notes (optional)", text: $newStudyNotes)
                }
                Section("Defaults") {
                    Picker("Frequency", selection: $newStudyFreq) {
                        ForEach(DosingFrequency.allCases) { f in Text(f.rawValue).tag(f) }
                    }
                    Toggle("Allow partial doses", isOn: $newStudyPartials)
                    TextField("PRN target/day (optional)", text: $newStudyPRNTarget)
                        .keyboardType(.decimalPad)
                        .numericValidation(text: $newStudyPRNTarget, allowPartials: true)
                }
            }
            .navigationTitle("New Study")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showNewStudySheet = false; resetNewStudyFields() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createInlineStudy() }
                        .disabled(newStudyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func resetNewStudyFields() {
        newStudyName = ""; newStudyNotes = ""; newStudyFreq = .qd; newStudyPartials = false; newStudyPRNTarget = ""
    }

    private func createInlineStudy() {
        let notes = newStudyNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let prn = Double(newStudyPRNTarget)
        let study = Study(
            name: newStudyName,
            notes: notes.isEmpty ? nil : notes,
            defaultFrequency: newStudyFreq,
            defaultPartialDoseEnabled: newStudyPartials,
            defaultPrnTargetPerDay: prn
        )
        ctx.insert(study)
        try? ctx.save()
        resetNewStudyFields()
        showNewStudySheet = false
        selectStudy(study)
    }

    private func createInlineSubject() {
        guard let s = selectedStudy else { return }
        let name = tempSubjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        let subj = Subject(code: subjectId, displayName: name.isEmpty ? nil : name, study: s)
        s.subjects.append(subj)
        // Persist
        ctx.insert(subj)
        try? ctx.save()
        // Select it and close
        selectSubject(subj)
        showNewSubjectSheet = false
        tempSubjectName = ""
    }

    // (background reverted to light gradient)

    private func parseBottles() -> (Double?, Double?, [Bottle]) {
        guard !bottles.isEmpty else { return (nil, nil, []) }
        var totalDisp: Double = 0
        var totalRet: Double = 0
        var models: [Bottle] = []
        for b in bottles {
            let d = Double(b.dispensed) ?? 0
            let r = Double(b.returned) ?? 0
            totalDisp += d
            totalRet += r
            models.append(Bottle(label: b.label.isEmpty ? "Bottle" : b.label, dispensed: d, returned: r))
        }
        return (totalDisp, totalRet, models)
    }
    
    private func parseBottles(forDrugNamed name: String) -> (Double?, Double?, [Bottle]) {
        let arr = drugBottles[name] ?? []
        guard !arr.isEmpty else { return (nil, nil, []) }
        var totalDisp: Double = 0
        var totalRet: Double = 0
        var models: [Bottle] = []
        for b in arr {
            let d = Double(b.dispensed) ?? 0
            let r = Double(b.returned) ?? 0
            totalDisp += d
            totalRet += r
            models.append(Bottle(label: b.label.isEmpty ? "Bottle" : b.label, dispensed: d, returned: r))
        }
        return (totalDisp, totalRet, models)
    }
}

// Local input struct for UI editing (not persisted directly)
private struct BottleInput: Identifiable, Hashable {
    let id = UUID()
    var label: String = "Bottle"
    var dispensed: String = ""
    var returned: String = ""
}

// A compact selector showing N check circles to choose a count from 0..N
private struct DoseSelector: View {
    let maxCount: Int
    @Binding var selection: Int?

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...maxCount, id: \.self) { idx in
                let filled = (selection ?? 0) >= idx
                Image(systemName: filled ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(filled ? Color.accentColor : Color.secondary)
                    .accessibilityLabel("Dose \(idx)")
                    .accessibilityValue(filled ? "Selected" : "Not selected")
                    .accessibilityAddTraits(.isButton)
                    .onTapGesture {
                        if selection == idx { selection = nil } else { selection = idx }
                    }
            }
            Button {
                selection = nil
            } label: {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Clear override")
            .accessibilityLabel("Clear override")
        }
    }
}

// Small pill-like selectable chip
private struct Chip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(Capsule().fill(selected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.15)))
                .foregroundStyle(selected ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .overlay(
            Capsule().stroke(selected ? Color.accentColor : Color.clear, lineWidth: 1)
        )
    }
}

// Subject chip with a small badge (e.g., last compliance %)
private struct SubjectChip: View {
    let title: String
    let badge: String?
    let badgeColor: Color
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                if let badge {
                    Text(badge)
                        .font(.caption2)
                        .padding(.vertical, 2)
                        .padding(.horizontal, 6)
                        .background(Capsule().fill(badgeColor.opacity(0.15)))
                        .foregroundStyle(badgeColor)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(Capsule().fill(selected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.15)))
            .foregroundStyle(selected ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .overlay(Capsule().stroke(selected ? Color.accentColor : Color.clear, lineWidth: 1))
    }
}

#if DEBUG
import SwiftData
struct CalculatorView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            CalculatorView()
        }
        .modelContainer(for: [Calculation.self, Bottle.self, Study.self, Subject.self])
    }
}
#endif
