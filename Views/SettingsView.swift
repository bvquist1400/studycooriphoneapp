//
//  SettingsView.swift
//  StudyCoor
//
//  Created by Brent Bloomquist on 8/29/25.
//


import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("showHowWeCalculated") private var showExplain = true
    @Environment(\.modelContext) private var ctx
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var purchases: PurchaseManager
    @State private var confirmErase = false
    @State private var eraseError: EraseError?
    @State private var showMailError = false

    var body: some View {
        Form {
            Section {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                Button {
                    openSupportEmail()
                } label: {
                    Label("Email Support", systemImage: "envelope")
                }
                Link(destination: URL(string: "https://ios.studycoor.com/support")!) {
                    Label("Support Site", systemImage: "safari")
                }
                Link(destination: URL(string: "https://ios.studycoor.com/privacy")!) {
                    Label("Privacy Policy", systemImage: "lock.shield")
                }
                Link(destination: URL(string: "https://ios.studycoor.com/terms")!) {
                    Label("Terms of Service", systemImage: "doc.text")
                }
            } header: {
                Label("About & Support", systemImage: "info.circle")
            }

            Section {
                Toggle("Show compliance explainer", isOn: $showExplain)
                    .toggleStyle(.switch)
            } header: {
                Label("Calculator Preferences", systemImage: "slider.horizontal.3")
            } footer: {
                Text("Turn this on to display the “How we calculated this” breakdown under the results card.")
            }

            Section {
                Button(role: .destructive) {
                    confirmErase = true
                } label: {
                    Label("Erase All Data", systemImage: "trash")
                        .fontWeight(.semibold)
                }
                .alert("Erase All Data?", isPresented: $confirmErase) {
                    Button("Cancel", role: .cancel) {}
                    Button("Erase", role: .destructive) { eraseAll() }
                } message: {
                    Text("Saved studies, subjects, bottles, and calculations will be permanently removed.")
                }
                #if DEBUG
                Button(purchases.isDebugOverrideActive ? "Disable Pro Override (Debug)" : "Enable Pro Override (Debug)") {
                    purchases.applyDebugOverride(!purchases.isDebugOverrideActive)
                }
                .font(.footnote)
                .tint(.secondary)
                #endif
            } header: {
                Label("Data Management", systemImage: "externaldrive.badge.xmark")
            }
        }
        .navigationTitle("Settings")
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .studyCoorBackground()
        .alert(item: $eraseError) { error in
            Alert(
                title: Text("Erase Failed"),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert("Unable to compose email", isPresented: $showMailError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This device is not configured to send mail.")
        }
    }


    private func eraseAll() {
        do {
            let calculations = try ctx.fetch(FetchDescriptor<Calculation>())
            let studies = try ctx.fetch(FetchDescriptor<Study>())

            calculations.forEach { ctx.delete($0) }
            studies.forEach { ctx.delete($0) }
            try ctx.save()

            // A second pass cleans up any lingering orphaned records after cascades complete.
            let orphanSubjects = try ctx.fetch(FetchDescriptor<Subject>(predicate: #Predicate { $0.study == nil }))
            let orphanDrugs = try ctx.fetch(FetchDescriptor<Drug>(predicate: #Predicate { $0.study == nil }))
            orphanSubjects.forEach { ctx.delete($0) }
            orphanDrugs.forEach { ctx.delete($0) }

            if ctx.hasChanges {
                try ctx.save()
            }
        } catch {
            ctx.rollback()
            eraseError = EraseError(message: error.localizedDescription)
        }
    }

    private func openSupportEmail() {
        guard let url = URL(string: "mailto:support@studycoor.com") else { return }
        openURL(url) { accepted in
            if !accepted {
                showMailError = true
            }
        }
    }
}

// ThemeOption removed; app enforces Dark mode globally.

private struct EraseError: Identifiable {
    let id = UUID()
    let message: String
}
