import SwiftUI

private struct StudyCoorBackgroundLayer: View {
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        Group {
            if colorScheme == .light {
                ZStack {
                    LinearGradient(
                        colors: [.indigo.opacity(0.25), .blue.opacity(0.22), .teal.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    RadialGradient(
                        colors: [.clear, Color.blue.opacity(0.10)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 700
                    )
                    .blendMode(.screen)
                }
            } else {
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        // Avoid covering the navigation bar/title on iOS 18+ while still letting
        // the gradient extend edge-to-edge for the content area.
        .ignoresSafeArea(edges: [.horizontal, .bottom])
    }
}

extension View {
    /// Applies the standard StudyCoor background gradient respecting light/dark mode.
    func studyCoorBackground() -> some View {
        background(StudyCoorBackgroundLayer())
    }
}
