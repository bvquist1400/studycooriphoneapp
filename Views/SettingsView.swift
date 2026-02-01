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
                if let supportURL = URL(string: "https://bvquist1400.github.io/studycooriphoneapp/") {
                    Link(destination: supportURL) {
                        Label("Support Site", systemImage: "safari")
                    }
                }
                if let privacyURL = URL(string: "https://bvquist1400.github.io/studycooriphoneapp/privacy.html") {
                    Link(destination: privacyURL) {
                        Label("Privacy Policy", systemImage: "lock.shield")
                    }
                }
                if let termsURL = URL(string: "https://bvquist1400.github.io/studycooriphoneapp/terms.html") {
                    Link(destination: termsURL) {
                        Label("Terms of Service", systemImage: "doc.text")
                    }
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
            // Delete in dependency order: children first, then parents
            // This avoids SwiftData accessing invalidated relationships during cascade

            // 1. Delete all calculations (no relationships)
            let calculations = try ctx.fetch(FetchDescriptor<Calculation>())
            for calc in calculations { ctx.delete(calc) }

            // 2. Delete all subjects (children of Study)
            let subjects = try ctx.fetch(FetchDescriptor<Subject>())
            for subject in subjects { ctx.delete(subject) }

            // 3. Delete all drugs (children of Study)
            let drugs = try ctx.fetch(FetchDescriptor<Drug>())
            for drug in drugs { ctx.delete(drug) }

            // 4. Delete all studies (parents, now safe since children are gone)
            let studies = try ctx.fetch(FetchDescriptor<Study>())
            for study in studies { ctx.delete(study) }

            // 5. Delete any orphaned bottles
            let bottles = try ctx.fetch(FetchDescriptor<Bottle>())
            for bottle in bottles { ctx.delete(bottle) }

            // Single save after all deletions
            try ctx.save()
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
