import SwiftUI

struct RootView: View {
    @EnvironmentObject private var purchases: PurchaseManager
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
