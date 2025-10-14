import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct CalculatorView: View {
    // Optional prefill support
    private let embedInNavigation: Bool
    struct Prefill {
        var subjectId: String?
        var frequency: DosingFrequency
        var partials: Bool
        var prnTargetPerDay: Double?
        var studyName: String?
    }

    private var prefillRef: Prefill?

    init(prefill: Prefill? = nil, embedInNavigation: Bool = true) {
        self.embedInNavigation = embedInNavigation
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
    @EnvironmentObject private var purchases: PurchaseManager
    @Environment(\.modelContext) private var ctx
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: [SortDescriptor(\Study.createdAt, order: .reverse)]) private var studies: [Study]
    @State private var selectedStudy: Study? = nil
    @State private var selectedSubject: Subject? = nil
    @State private var selectedDrug: Drug? = nil
    // Per-IP bottle inputs and results (multi-IP studies)
    @State private var drugBottles: [String: [BottleInput]] = [:]
    @State private var drugOverrides: [PersistentIdentifier: DrugOverrideState] = [:]
    @State private var subjectComplianceCache: [String: Double] = [:]
    @State private var isApplyingOverride = false
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
    @State private var showPaywallSheet = false
    @State private var latestCalculation: Calculation?

    // Multiple bottles
    @State private var bottles: [BottleInput] = []

    // Edge-day expected overrides
    @State private var firstDayCount: Int? = nil
    @State private var lastDayCount: Int? = nil

    @FocusState private var focusedField: FocusTarget?
    @State private var scrollProxy: ScrollViewProxy?

    private enum FocusTarget: Hashable {
        case prnTarget
        case quickTotals(QuickField)
        case bottle(UUID, BottleField)
    }

    private enum QuickField: Hashable { case dispensed, returned, missed, extra, holdDays }
    private enum BottleField: Hashable { case dispensed, returned }

    private enum ScrollTarget: Hashable { case results }

    private var isProUnlocked: Bool { purchases.isProUnlocked }
    private var isMultiDrugMode: Bool { selectedStudy?.multiDrug == true }

    private let keyboardInset: CGFloat = 80

    var body: some View {
        Group {
            if embedInNavigation {
                NavigationStack { calculatorContent }
            } else {
                calculatorContent
            }
        }
    }

    private var calculatorContent: some View {
        ScrollViewReader { proxy in
            Form {
                studySubjectSection
                subjectIdSection
                resultsSection
                periodSection
                regimenSection
                quickTotalsSection
                edgeDaySection
                singleBottleSection
                multiBottleSections
                adjustmentsSection
                calculateSection
                errorSection
            }
            .studyCoorBackground()
            .onAppear { scrollProxy = proxy }
            .onAppear { applyPrefillSelectionIfNeeded() }
            .onChange(of: studies.count) { _, _ in applyPrefillSelectionIfNeeded() }
            .onChange(of: frequency) { _, newValue in
                updateCurrentDrugOverride { $0.frequency = newValue }
            }
            .onChange(of: partials) { _, newValue in
                updateCurrentDrugOverride { $0.partials = newValue }
            }
            .onChange(of: prnTargetPerDay) { _, newValue in
                updateCurrentDrugOverride { $0.prnTarget = newValue }
            }
            .onChange(of: missed) { _, newValue in
                updateCurrentDrugOverride { $0.missed = newValue }
            }
            .onChange(of: extra) { _, newValue in
                updateCurrentDrugOverride { $0.extra = newValue }
            }
            .onChange(of: purchases.isProUnlocked) { _, newValue in
                if newValue {
                    showPaywallSheet = false
                }
            }
            .sheet(isPresented: $showNewSubjectSheet) { newSubjectSheet }
            .sheet(isPresented: $showNewStudySheet) { newStudySheet }
            .sheet(isPresented: $showPaywallSheet) {
                PaywallView {
                    showPaywallSheet = false
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
                    Button("Done") {
                        focusedField = nil
                        dismissKeyboard()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear
                    .frame(height: keyboardInset)
                    .allowsHitTesting(false)
            }
            .onChange(of: focusedField) { _, newValue in
                guard let newValue else { return }
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(newValue, anchor: .top)
                    }
                }
            }
#if canImport(UIKit)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                guard let current = focusedField else { return }
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(current, anchor: .top)
                    }
                }
            }
#endif
        }
    }

    private func calculate() {
        latestCalculation = nil
        if isMultiDrugMode, let s = selectedStudy {
            persistCurrentDrugOverride()

            var results: [String: ComplianceOutputs] = [:]
            var encounteredError: Error?
            let holds = parseHoldDaysValue()

            for d in s.drugs {
                let override = drugOverrides[d.id] ?? defaultOverride(for: d)
                let (bd, br, models) = parseBottles(forDrugNamed: d.name)
                let disp = bd ?? 0
                let ret  = br ?? 0
                let miss = parseAmount(override.missed)
                let ext  = parseAmount(override.extra)
                let freq = override.frequency
                let partialSetting = override.partials
                let prnTarget = freq == .prn ? parseOptionalAmount(override.prnTarget) : nil

                let inputs = ComplianceInputs(
                    dispensed: disp,
                    returned: ret,
                    startDate: startDate,
                    endDate: endDate,
                    frequency: freq,
                    missedDoses: miss,
                    extraDoses: ext,
                    holdDays: holds,
                    partialDoseEnabled: partialSetting,
                    prnTargetPerDay: prnTarget,
                    firstDayExpectedOverride: firstDayCount,
                    lastDayExpectedOverride: lastDayCount
                )

                do {
                    let out = try ComplianceEngine.compute(inputs)
                    results[d.name] = out

                    let record = Calculation()
                    record.subjectId = subjectId.isEmpty ? nil : subjectId
                    record.drugName = d.name
                    record.startDate = startDate
                    record.endDate = endDate
                    record.frequency = freq
                    record.dispensed = disp
                    record.returned = ret
                    record.missedDoses = miss
                    record.extraDoses = ext
                    record.holdDays = holds
                    record.partialDoseEnabled = partialSetting
                    record.prnTargetPerDay = prnTarget
                    record.firstDayExpectedOverride = firstDayCount
                    record.lastDayExpectedOverride = lastDayCount
                    record.expectedDoses = out.expectedDoses
                    record.actualDoses = out.actualDoses
                    record.compliancePct = out.compliancePct
                    record.flags = out.flags
                    record.breakdown = out.breakdown
                    record.createdAt = .now
                    record.bottles = models
                    ctx.insert(record)
                } catch {
                    encounteredError = error
                    break
                }
            }

            if let encounteredError {
                ctx.rollback()
                errorMsg = encounteredError.localizedDescription
                multiResults.removeAll()
                notifyError()
                return
            }

            do {
                try ctx.save()
                multiResults = results
                result = nil
                errorMsg = nil
                notifySuccess()
                scrollToResults()
            } catch {
                ctx.rollback()
                errorMsg = error.localizedDescription
                multiResults.removeAll()
                notifyError()
            }
        } else {
            let (bottleDisp, bottleRet, bottleModels) = parseBottles()
            let disp = bottleDisp ?? parseAmount(dispensed)
            let ret  = bottleRet  ?? parseAmount(returned)
            let miss = parseAmount(missed)
            let ext  = parseAmount(extra)
            let holds = parseHoldDaysValue()
            let prnTarget = frequency == .prn ? parseOptionalAmount(prnTargetPerDay) : nil

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
                result = out
                errorMsg = nil
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
                record.breakdown = out.breakdown
                record.createdAt = .now
                record.bottles = bottleModels
                ctx.insert(record)
                try ctx.save()
                latestCalculation = record
                if let study = selectedStudy {
                    refreshComplianceCache(for: study)
                }
                scrollToResults()
            } catch {
                ctx.rollback()
                result = nil
                errorMsg = error.localizedDescription
                latestCalculation = nil
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
        focusedField = nil
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }

    // MARK: - View builders split out for readability / compiler performance

    @ViewBuilder
    private var studySubjectSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(studies) { s in
                            Chip(title: s.name, selected: selectedStudy?.id == s.id) {
                                withAnimation { selectStudy(s) }
                            }
                        }
                        if isProUnlocked {
                            Button { handleAddStudyTapped() } label: {
                                Label("New", systemImage: "plus.circle")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if !isProUnlocked {
                    proUpsellBanner(
                        title: "Need Study Lists?",
                        message: "Create and manage studies, subjects, and defaults with StudyCoorCalc Pro.",
                        actionTitle: "Unlock",
                        action: handleAddStudyTapped
                    )
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
                            if isProUnlocked {
                                Button { handleAddSubjectTapped() } label: {
                                    Label("New", systemImage: "plus.circle")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                if !isProUnlocked, selectedStudy != nil {
                    proUpsellBanner(
                        title: "Add Subjects",
                        message: "Unlock Pro to register new subjects directly from the calculator.",
                        actionTitle: "Unlock",
                        action: handleAddSubjectTapped
                    )
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
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .listRowInsets(.init(top: 12, leading: 0, bottom: 12, trailing: 0))
            .listRowBackground(Color.clear)
        } header: {
            HStack {
                Label("Study & Subject", systemImage: "rectangle.and.pencil.and.ellipsis")
                Spacer()
                if isProUnlocked {
                    NavigationLink(destination: StudiesView()) {
                        Label("Manage", systemImage: "gearshape")
                    }
                    .font(.caption)
                } else {
                    Button { showPaywallSheet = true } label: {
                        Label("Unlock Pro", systemImage: "lock.fill")
                    }
                    .font(.caption)
                }
            }
        } footer: {
            Text("Selecting a study applies its defaults; choosing a subject fills Subject ID.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var subjectIdSection: some View {
        Section("Subject (optional)") {
            TextField("Subject ID", text: $subjectId)
                .textInputAutocapitalization(.characters)
        }
    }

    @ViewBuilder
    private var resultsSection: some View {
        if let s = selectedStudy, s.multiDrug, !multiResults.isEmpty {
            Section {
                ForEach(s.drugs) { d in
                    if let r = multiResults[d.name] {
                        complianceCard(for: d.name, output: r)
                    }
                }
            } header: { Label("Results", systemImage: "gauge") }
                .id(ScrollTarget.results)
        } else if let result {
            Section {
                complianceCard(for: nil, output: result)
            } header: {
                Label("Result", systemImage: "gauge")
            }
            .id(ScrollTarget.results)
        }
    }

    private var periodSection: some View {
        Section("Period") {
            DatePicker("Start", selection: $startDate, displayedComponents: .date)
            DatePicker("End", selection: $endDate, displayedComponents: .date)
        }
    }

    @ViewBuilder
    private var regimenSection: some View {
        Section("Regimen") {
            Picker("Frequency", selection: $frequency) {
                ForEach(DosingFrequency.allCases) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            if frequency == .prn {
                TextField("PRN target doses/day (optional)", text: $prnTargetPerDay)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .prnTarget)
                    .id(FocusTarget.prnTarget)
                    .numericValidation(text: $prnTargetPerDay, allowPartials: true)
            }
            Toggle("Allow partial doses", isOn: $partials)
        }
    }

    @ViewBuilder
    private var edgeDaySection: some View {
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
    }

    @ViewBuilder
    private var singleBottleSection: some View {
        if (selectedStudy?.multiDrug != true) || ((selectedStudy?.drugs.isEmpty) ?? true) {
            Section {
                if bottles.isEmpty {
                    Text("No bottles added. Use + to add.")
                        .foregroundStyle(.secondary)
                }
                ForEach($bottles) { bottle in
                    let bottleID = bottle.wrappedValue.id
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            TextField("Label", text: bottle.label)
                            Spacer()
                            Button(role: .destructive) {
                                bottles.removeAll { $0.id == bottleID }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Delete bottle")
                        }
                        HStack {
                            TextField("Dispensed", text: bottle.dispensed)
                                .keyboardType(.decimalPad)
                                .focused($focusedField, equals: .bottle(bottleID, .dispensed))
                                .id(FocusTarget.bottle(bottleID, .dispensed))
                                .numericValidation(text: bottle.dispensed, allowPartials: partials)
                            TextField("Returned", text: bottle.returned)
                                .keyboardType(.decimalPad)
                                .focused($focusedField, equals: .bottle(bottleID, .returned))
                                .id(FocusTarget.bottle(bottleID, .returned))
                                .numericValidation(text: bottle.returned, allowPartials: partials)
                        }
                        .textFieldStyle(.roundedBorder)
                    }
                }
                HStack {
                    Button { bottles.append(BottleInput()) } label: {
                        Label("Add Bottle", systemImage: "plus.circle.fill")
                    }
                }
            } header: {
                Label("Bottles", systemImage: "shippingbox")
            } footer: {
                Text("If you add bottles, their totals replace Quick Totals for dispensed/returned.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var multiBottleSections: some View {
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
                    ForEach(binding) { bottle in
                        let bottleID = bottle.wrappedValue.id
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                TextField("Label", text: bottle.label)
                                Spacer()
                                Button(role: .destructive) {
                                    var arr = drugBottles[d.name] ?? []
                                    arr.removeAll { $0.id == bottleID }
                                    drugBottles[d.name] = arr
                                } label: { Image(systemName: "trash") }
                                .buttonStyle(.borderless)
                            }
                            HStack {
                                TextField("Dispensed", text: bottle.dispensed)
                                    .keyboardType(.decimalPad)
                                    .focused($focusedField, equals: .bottle(bottleID, .dispensed))
                                    .id(FocusTarget.bottle(bottleID, .dispensed))
                                    .numericValidation(text: bottle.dispensed, allowPartials: partials)
                                TextField("Returned", text: bottle.returned)
                                    .keyboardType(.decimalPad)
                                    .focused($focusedField, equals: .bottle(bottleID, .returned))
                                    .id(FocusTarget.bottle(bottleID, .returned))
                                    .numericValidation(text: bottle.returned, allowPartials: partials)
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
                } header: {
                    Label("Bottles – \(d.name)", systemImage: "shippingbox")
                }
            }
        }
    }

    @ViewBuilder
    private var adjustmentsSection: some View {
        Section {
            TextField("Missed doses (expected but not taken, optional)", text: $missed)
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: .quickTotals(.missed))
                .id(FocusTarget.quickTotals(.missed))
                .numericValidation(text: $missed, allowPartials: partials)
            TextField("Extra doses (taken beyond schedule, optional)", text: $extra)
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: .quickTotals(.extra))
                .id(FocusTarget.quickTotals(.extra))
                .numericValidation(text: $extra, allowPartials: partials)
            TextField("Hold days (days paused, optional)", text: $holdDays)
                .keyboardType(.numberPad)
                .focused($focusedField, equals: .quickTotals(.holdDays))
                .id(FocusTarget.quickTotals(.holdDays))
                .integerValidation(text: $holdDays)
        } header: {
            Label("Adjustments", systemImage: "slider.horizontal.2.square")
        } footer: {
            Text("Hold days reduce expected doses. Missed/extra apply per investigational product when tracking multiple drugs.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var calculateSection: some View {
        Section {
            Button { calculate() } label: {
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
    }

    @ViewBuilder
    private var quickTotalsSection: some View {
        if (selectedStudy?.multiDrug != true) || ((selectedStudy?.drugs.isEmpty) ?? true) {
            Section {
                Text("Use when you’re not itemizing bottles.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Dispensed (tabs)", text: $dispensed)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .quickTotals(.dispensed))
                    .id(FocusTarget.quickTotals(.dispensed))
                    .numericValidation(text: $dispensed, allowPartials: partials)
                TextField("Returned (tabs)", text: $returned)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .quickTotals(.returned))
                    .id(FocusTarget.quickTotals(.returned))
                    .numericValidation(text: $returned, allowPartials: partials)
            } header: {
                Label("Quick Totals", systemImage: "sum")
            } footer: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Actual = (Dispensed − Returned) − Missed + Extra")
                    Text("Bottles override dispensed/returned totals when present.")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if let errorMsg {
            Section { Text(errorMsg).foregroundStyle(.red) }
        }
    }

    @ViewBuilder
    private func complianceCard(for drugName: String?, output: ComplianceOutputs) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(colors: [.blue.opacity(0.18), .green.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing))
            VStack(alignment: .leading, spacing: 16) {
                if let drugName {
                    Text(drugName)
                        .font(.headline)
                }
                VStack(spacing: 4) {
                    Text(String(format: "%.0f%%", output.compliancePct))
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundStyle(colorForCompliance(output.compliancePct))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                    Text("Compliance")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    metricRow(title: "Expected doses", value: String(format: "%.0f", output.expectedDoses))
                    metricRow(title: "Actual doses", value: String(format: "%.0f", output.actualDoses))
                }
                Divider()
                Gauge(value: min(150, max(0, output.compliancePct)), in: 0...150) {
                    Text("Compliance")
                } currentValueLabel: {
                    Text(String(format: "%.0f%%", output.compliancePct))
                        .monospacedDigit()
                } minimumValueLabel: {
                    Text("0%")
                } maximumValueLabel: {
                    Text("150%")
                }
                .tint(colorForCompliance(output.compliancePct))
                .gaugeStyle(.accessoryLinear)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: output.compliancePct)
                if !output.flags.isEmpty {
                    let friendlyFlags = output.flagDescriptions
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Flags")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(Array(friendlyFlags.enumerated()), id: \.offset) { item in
                            Text("• \(item.element)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if drugName == nil {
                    if showExplain {
                        quickExplainSummary(output: output)
                    } else if let calc = latestCalculation {
                        NavigationLink {
                            ExplainabilityView(calculation: calc)
                        } label: {
                            Label("View detailed breakdown", systemImage: "list.bullet.rectangle")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(colorForCompliance(output.compliancePct))
                    }
                }
            }
            .padding(18)
        }
    }

    @ViewBuilder
    private func quickExplainSummary(output: ComplianceOutputs) -> some View {
        VStack(alignment: .center, spacing: 12) {
            Text("Quick breakdown")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
            VStack(alignment: .center, spacing: 6) {
                Text("Actual = (Dispensed − Returned) − Missed + Extra")
                Text("Expected = Daily goal × Effective days (holds & overrides applied)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)

            if let calc = latestCalculation {
                NavigationLink {
                    ExplainabilityView(calculation: calc)
                } label: {
                    Label("View detailed breakdown", systemImage: "list.bullet.rectangle")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(colorForCompliance(output.compliancePct))
            } else {
                Text("Run a calculation to view the full breakdown.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private func metricRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.headline)
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private func proUpsellBanner(
        title: String,
        message: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            Button(actionTitle) { action() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
        )
        .padding(.vertical, 6)
    }

    private func handleAddStudyTapped() {
        guard isProUnlocked else {
            showPaywallSheet = true
            return
        }
        showNewStudySheet = true
    }

    private func handleAddSubjectTapped() {
        guard isProUnlocked else {
            showPaywallSheet = true
            return
        }
        guard selectedStudy != nil else { return }
        showNewSubjectSheet = true
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
        persistCurrentDrugOverride()

        let previousStudyID = selectedStudy?.id
        selectedStudy = s
        refreshComplianceCache(for: s)
        lastStudyName = s.name
        selectedSubject = nil
        lastSubjectCode = ""
        subjectId = ""
        result = nil
        multiResults.removeAll()
        if previousStudyID != s.id {
            bottles.removeAll()
            drugBottles.removeAll()
        }
        holdDays = ""
        dispensed = ""
        returned = ""

        if s.multiDrug {
            var overrides: [PersistentIdentifier: DrugOverrideState] = [:]
            for drug in s.drugs {
                overrides[drug.id] = defaultOverride(for: drug)
            }
            drugOverrides = overrides
            if let first = s.drugs.first {
                selectedDrug = first
                applyOverride(for: first)
            } else {
                selectedDrug = nil
                applyStudyDefaults(s)
            }
        } else {
            drugOverrides.removeAll()
            selectedDrug = nil
            applyStudyDefaults(s)
        }
    }

    private func selectSubject(_ subj: Subject) {
        selectedSubject = subj
        subjectId = subj.code
        lastSubjectCode = subj.code
    }

    private func refreshComplianceCache(for study: Study) {
        let subjectCodes = study.subjects.map(\.code)
        guard !subjectCodes.isEmpty else {
            subjectComplianceCache = [:]
            return
        }

        do {
            var accumulator: [String: (total: Double, count: Int)] = [:]
            for code in subjectCodes {
                let descriptor = FetchDescriptor<Calculation>(
                    predicate: #Predicate { $0.subjectId == code }
                )
                let calculations = try ctx.fetch(descriptor)
                guard !calculations.isEmpty else { continue }
                var total: Double = 0
                for calculation in calculations {
                    total += calculation.compliancePct
                }
                accumulator[code] = (total, calculations.count)
            }
            subjectComplianceCache = accumulator.reduce(into: [:]) { result, pair in
                let (code, value) = pair
                guard value.count > 0 else { return }
                result[code] = value.total / Double(value.count)
            }
        } catch {
            print("Failed to build compliance cache: \(error)")
            subjectComplianceCache = [:]
        }
    }

    private func selectDrug(_ d: Drug) {
        persistCurrentDrugOverride()
        selectedDrug = d
        applyOverride(for: d)
    }

    private func lastComplianceValue(for subject: Subject) -> Double? {
        subjectComplianceCache[subject.code]
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
        guard isProUnlocked else {
            showNewStudySheet = false
            showPaywallSheet = true
            return
        }
        let notes = newStudyNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let prn = NumericFormatter.parseLocalized(newStudyPRNTarget)
        let study = Study(
            name: newStudyName,
            notes: notes.isEmpty ? nil : notes,
            defaultFrequency: newStudyFreq,
            defaultPartialDoseEnabled: newStudyPartials,
            defaultPrnTargetPerDay: prn
        )
        ctx.insert(study)
        do {
            try ctx.save()
            resetNewStudyFields()
            showNewStudySheet = false
            selectStudy(study)
            errorMsg = nil
        } catch {
            ctx.rollback()
            errorMsg = error.localizedDescription
        }
    }

    private func createInlineSubject() {
        guard isProUnlocked else {
            showNewSubjectSheet = false
            showPaywallSheet = true
            return
        }
        guard let s = selectedStudy else { return }
        let name = tempSubjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        let subj = Subject(code: subjectId, displayName: name.isEmpty ? nil : name, study: s)
        s.subjects.append(subj)
        // Persist
        ctx.insert(subj)
        do {
            try ctx.save()
            selectSubject(subj)
            showNewSubjectSheet = false
            tempSubjectName = ""
            errorMsg = nil
        } catch {
            ctx.rollback()
            errorMsg = error.localizedDescription
        }
    }

    // (background reverted to light gradient)

    private func parseBottles() -> (Double?, Double?, [Bottle]) {
        guard !bottles.isEmpty else { return (nil, nil, []) }
        var totalDisp: Double = 0
        var totalRet: Double = 0
        var models: [Bottle] = []
        for b in bottles {
            let d = parseAmount(b.dispensed)
            let r = parseAmount(b.returned)
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
            let d = parseAmount(b.dispensed)
            let r = parseAmount(b.returned)
            totalDisp += d
            totalRet += r
            models.append(Bottle(label: b.label.isEmpty ? "Bottle" : b.label, dispensed: d, returned: r))
        }
        return (totalDisp, totalRet, models)
    }
}

// Local input struct for UI editing (not persisted directly)
private struct DrugOverrideState: Equatable {
    var frequency: DosingFrequency
    var partials: Bool
    var prnTarget: String
    var missed: String
    var extra: String
}

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

private extension CalculatorView {
    func defaultOverride(for drug: Drug) -> DrugOverrideState {
        DrugOverrideState(
            frequency: drug.defaultFrequency,
            partials: drug.defaultPartialDoseEnabled,
            prnTarget: drug.defaultPrnTargetPerDay.map { NumericFormatter.formatted($0, allowPartials: true) } ?? "",
            missed: "",
            extra: ""
        )
    }

    func applyStudyDefaults(_ study: Study) {
        isApplyingOverride = true
        defer { isApplyingOverride = false }
        frequency = study.defaultFrequency
        partials = study.defaultPartialDoseEnabled
        prnTargetPerDay = study.defaultPrnTargetPerDay.map { NumericFormatter.formatted($0, allowPartials: true) } ?? ""
        missed = ""
        extra = ""
    }

    func applyOverride(for drug: Drug) {
        isApplyingOverride = true
        defer { isApplyingOverride = false }
        let override = drugOverrides[drug.id] ?? defaultOverride(for: drug)
        drugOverrides[drug.id] = override
        frequency = override.frequency
        partials = override.partials
        prnTargetPerDay = override.prnTarget
        missed = override.missed
        extra = override.extra
    }

    func persistCurrentDrugOverride() {
        guard isMultiDrugMode, !isApplyingOverride, let current = selectedDrug else { return }
        drugOverrides[current.id] = DrugOverrideState(
            frequency: frequency,
            partials: partials,
            prnTarget: prnTargetPerDay,
            missed: missed,
            extra: extra
        )
    }

    func updateCurrentDrugOverride(_ update: (inout DrugOverrideState) -> Void) {
        guard isMultiDrugMode, !isApplyingOverride, let current = selectedDrug else { return }
        var override = drugOverrides[current.id] ?? defaultOverride(for: current)
        update(&override)
        drugOverrides[current.id] = override
    }

    func parseAmount(_ text: String) -> Double {
        max(0, NumericFormatter.parseLocalized(text) ?? 0)
    }

    func parseOptionalAmount(_ text: String) -> Double? {
        guard let value = NumericFormatter.parseLocalized(text) else { return nil }
        return max(0, value)
    }

    func parseHoldDaysValue() -> Int {
        guard let value = NumericFormatter.parseLocalized(holdDays) else { return 0 }
        return max(0, Int(round(value)))
    }

    func scrollToResults() {
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.3)) {
                scrollProxy?.scrollTo(ScrollTarget.results, anchor: .top)
            }
        }
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
        .environmentObject(PurchaseManager.shared)
    }
}
#endif
