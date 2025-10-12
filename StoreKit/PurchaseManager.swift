import Foundation
import Combine
#if canImport(StoreKit)
import StoreKit
#endif

@MainActor
final class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()

    // Public state
    @Published var isProUnlocked: Bool = false
    @Published var products: [String: Any] = [:] // StoreKit.Product when available
    @Published var isLoading: Bool = false
    @Published var lastError: String?

    // Product identifiers (keep in sync with App Store Connect once available)
    struct IDs {
        static let monthly = "pro.monthly"
        static let yearly  = "pro.yearly"
    }

    private var updatesTask: Task<Void, Never>? = nil

    init() {
        // Attempt entitlement check immediately
        Task { await refreshEntitlements() }
        // Start listening to transaction updates where supported
        #if canImport(StoreKit)
        updatesTask = Task { await listenForTransactions() }
        #endif
    }

    deinit { updatesTask?.cancel() }

    // MARK: - StoreKit Integration

    func loadProducts() async {
        #if canImport(StoreKit)
        isLoading = true; defer { isLoading = false }
        lastError = nil
        do {
            let storeProducts = try await Product.products(for: [IDs.monthly, IDs.yearly])
            var dict: [String: Any] = [:]
            for p in storeProducts { dict[p.id] = p }
            self.products = dict
            if dict.isEmpty { self.lastError = "Products unavailable." }
        } catch {
            self.lastError = error.localizedDescription
        }
        #else
        // No StoreKit: keep empty
        #endif
    }

    func purchase(monthly: Bool) async {
        #if canImport(StoreKit)
        lastError = nil
        guard let product = products[monthly ? IDs.monthly : IDs.yearly] as? Product else {
            self.lastError = "Products unavailable. Please try again after refreshing."
            return
        }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                _ = try checkVerified(verification)
                await refreshEntitlements()
            case .userCancelled:
                break
            case .pending:
                break
            @unknown default:
                break
            }
        } catch {
            self.lastError = error.localizedDescription
        }
        #else
        // No StoreKit available
        #endif
    }

    func restorePurchases() async {
        #if canImport(StoreKit)
        lastError = nil
        do { try await AppStore.sync() } catch { self.lastError = error.localizedDescription }
        await refreshEntitlements()
        #else
        #endif
    }

    func refreshEntitlements() async {
        #if canImport(StoreKit)
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == IDs.monthly || transaction.productID == IDs.yearly {
                    unlocked = true
                    break
                }
            }
        }
        self.isProUnlocked = unlocked
        #else
        // Fallback: keep current state (can be toggled via AppStorage from dev paywall)
        #endif
    }

    #if canImport(StoreKit)
    private func listenForTransactions() async {
        for await update in Transaction.updates {
            if case .verified(let transaction) = update {
                if transaction.productID == IDs.monthly || transaction.productID == IDs.yearly {
                    self.isProUnlocked = true
                }
                await transaction.finish()
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw NSError(domain: "Purchase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unverified transaction"]) 
        case .verified(let safe):
            return safe
        }
    }
    #endif
}
