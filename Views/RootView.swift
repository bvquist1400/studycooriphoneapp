import SwiftUI

struct RootView: View {
    @AppStorage("proUnlocked") private var proUnlocked = false // Dev fallback
    @EnvironmentObject private var purchases: PurchaseManager
    var body: some View {
        TabView {
            CalculatorView()
                .tabItem { Label("Calculator", systemImage: "pill") }

            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }

            Group {
                if purchases.isProUnlocked || proUnlocked {
                    StudiesView()
                } else {
                    PaywallView()
                }
            }
            .tabItem { Label("Studies", systemImage: "book") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
