import SwiftUI
#if canImport(StoreKit)
import StoreKit
#endif

struct PaywallView: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("proUnlocked") private var proUnlocked = false // Dev fallback when StoreKit not available
    @EnvironmentObject private var purchases: PurchaseManager
    @State private var billing: Billing = .monthly

    enum Billing: String, CaseIterable, Identifiable { case monthly, yearly; var id: String { rawValue } }

    var body: some View {
        NavigationStack {
            ZStack {
                // Richer backdrop only in light mode; keep soft in dark mode
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
                        LinearGradient(colors: [Color(.systemBackground), Color(.secondarySystemBackground)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    }
                }
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Hero
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [.blue.opacity(0.25), .green.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 110, height: 110)
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 44, weight: .bold))
                                    .foregroundStyle(.blue)
                            }
                            Text("Unlock Pro")
                                .font(.largeTitle.bold())
                            Text("Organize studies, save defaults, and see trends")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        // Billing toggle
                        HStack(spacing: 8) {
                            ForEach(Billing.allCases) { b in
                                Button(action: { withAnimation(.spring) { billing = b } }) {
                                    Text(b == .monthly ? "Monthly" : "Yearly")
                                        .font(.subheadline.weight(.semibold))
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity)
                                        .background(Capsule().fill(b == billing ? Color.blue.opacity(0.2) : Color.secondary.opacity(0.1)))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Price card
                        VStack(spacing: 12) {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(priceText)
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                Text(billing == .monthly ? "/month" : "/year")
                                    .foregroundStyle(.secondary)
                            }
                            if billing == .yearly {
                                Text("Save ~33% vs monthly")
                                    .font(.caption).foregroundStyle(.green)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))

                        // Features
                        VStack(alignment: .leading, spacing: 12) {
                            feature(icon: "book", title: "Studies & Subjects", subtitle: "Keep work organized by project")
                            feature(icon: "slider.horizontal.3", title: "Saved Defaults", subtitle: "Apply dosing settings instantly")
                            feature(icon: "calendar", title: "Multi‑Visit Tracking", subtitle: "See compliance over time")
                            feature(icon: "sparkles", title: "Rollups & Insights", subtitle: "Totals, averages, best/worst")
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))

                        // CTA
                        VStack(spacing: 8) {
                            Button {
                                Task {
                                    if hasStoreKit {
                                        await purchases.purchase(monthly: billing == .monthly)
                                    } else {
                                        // Dev fallback
                                        proUnlocked = true
                                    }
                                }
                            } label: {
                                Text(billing == .monthly ? "Start Monthly" : "Start Yearly")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(LinearGradient(colors: [.blue, .green], startPoint: .leading, endPoint: .trailing)))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)

                            Button("Restore Purchase") {
                                Task {
                                    if hasStoreKit { await purchases.restorePurchases() } else { proUnlocked = true }
                                }
                            }
                                .font(.subheadline)
                        }

                        Text("Payment will be charged to your Apple ID. Auto‑renewable; manage or cancel anytime in Settings.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("StudyCoor Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(.systemBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .task { await purchases.loadProducts() }
        }
    }

    private var hasStoreKit: Bool {
        #if canImport(StoreKit)
        true
        #else
        false
        #endif
    }

    private var priceText: String {
        #if canImport(StoreKit)
        if let p = purchases.products[billing == .monthly ? PurchaseManager.IDs.monthly : PurchaseManager.IDs.yearly] as? Product {
            return p.displayPrice
        }
        #endif
        // Placeholder until products load
        return billing == .monthly ? "$4.99" : "$39.99"
    }

    @ViewBuilder private func feature(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.blue)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
        }
    }
}

#if DEBUG
struct PaywallView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationStack { PaywallView() }
                .preferredColorScheme(.light)
            NavigationStack { PaywallView() }
                .preferredColorScheme(.dark)
        }
    }
}
#endif
