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
        let navBackground = UIColor(red: 12/255.0, green: 13/255.0, blue: 18/255.0, alpha: 1)
        let navTitleColor = UIColor.white

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = navBackground
        nav.shadowColor = .clear
        nav.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: navTitleColor
        ]
        nav.largeTitleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 34, weight: .bold),
            .foregroundColor: navTitleColor
        ]
        nav.buttonAppearance.normal.titleTextAttributes = [ .foregroundColor: navTitleColor ]
        nav.doneButtonAppearance.normal.titleTextAttributes = [ .foregroundColor: navTitleColor ]

        let scrollAppearance = UINavigationBarAppearance()
        scrollAppearance.configureWithTransparentBackground()
        scrollAppearance.backgroundColor = .clear
        scrollAppearance.shadowColor = .clear
        scrollAppearance.titleTextAttributes = nav.titleTextAttributes
        scrollAppearance.largeTitleTextAttributes = nav.largeTitleTextAttributes
        scrollAppearance.buttonAppearance = nav.buttonAppearance
        scrollAppearance.doneButtonAppearance = nav.doneButtonAppearance

        let appearance = UINavigationBar.appearance()
        appearance.standardAppearance = nav
        appearance.scrollEdgeAppearance = scrollAppearance
        appearance.compactAppearance = nav
        if #available(iOS 15.0, *) {
            appearance.compactScrollEdgeAppearance = nav
        }
        appearance.prefersLargeTitles = true
        appearance.tintColor = navTitleColor
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
