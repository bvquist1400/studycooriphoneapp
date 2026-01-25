import SwiftUI
import SwiftData

struct RootView: View {
    @EnvironmentObject private var purchases: PurchaseManager
    @Environment(\.modelContext) private var ctx

    var body: some View {
        TabView {
            CalculatorView()
                .tabItem { Label("Calculator", systemImage: "pill") }

            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }

            Group {
                if purchases.isProUnlocked {
                    StudiesView()
                } else {
                    PaywallView()
                }
            }
            .id(purchases.isProUnlocked)
            .tabItem { Label("Studies", systemImage: "book") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
