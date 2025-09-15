import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif
// Purchase manager environment


@main
struct StudyCoorApp: App {
    init() {
        #if canImport(UIKit)
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = UIColor.systemBackground
        nav.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 18, weight: .semibold)
        ]
        nav.largeTitleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        #endif
    }
    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(.accentColor)
                .background(LinearGradient(colors: [Color(.systemBackground), Color(.secondarySystemBackground)], startPoint: .top, endPoint: .bottom))
                .preferredColorScheme(.dark)
                .environmentObject(PurchaseManager.shared)
        }
            .modelContainer(for: [Calculation.self, Bottle.self, Study.self, Subject.self, Drug.self])
    }
}
