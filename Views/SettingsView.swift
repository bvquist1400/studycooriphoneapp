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
    @State private var confirmErase = false

    var body: some View {
        Form {
            Section {
                Toggle("Show 'How we calculated this' notes", isOn: $showExplain)
                LabeledContent("Theme", value: "Dark")
            } header: { Label("Preferences", systemImage: "slider.horizontal.3") }
            Section {
                Button(role: .destructive) {
                    confirmErase = true
                } label: {
                    Label("Erase All Data", systemImage: "trash")
                }
                .alert("Erase All Data?", isPresented: $confirmErase) {
                    Button("Cancel", role: .cancel) {}
                    Button("Erase", role: .destructive) { eraseAll() }
                } message: {
                    Text("This will permanently delete all saved calculations and bottles.")
                }
            } header: { Label("Data", systemImage: "trash") }
            Section {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                Link("Support", destination: URL(string: "mailto:support@studycoor.com")!)
                Link("Support Site", destination: URL(string: "https://ios.studycoor.com/support")!)
                Link("Privacy Policy", destination: URL(string: "https://ios.studycoor.com/privacy")!)
            } header: { Label("About", systemImage: "info.circle") }
        }
        .navigationTitle("Settings")
        .studyCoorBackground()
    }


    private func eraseAll() {
        do {
            let all: [Calculation] = try ctx.fetch(FetchDescriptor<Calculation>())
            for c in all { ctx.delete(c) }
            try ctx.save()
        } catch {
            // Minimal handling; could surface an error UI if desired
            print("Erase failed: \(error)")
        }
    }
}

// ThemeOption removed; app enforces Dark mode globally.
