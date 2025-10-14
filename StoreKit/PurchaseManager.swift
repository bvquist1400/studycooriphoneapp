import Foundation
import Combine
#if canImport(StoreKit)
import StoreKit
#endif

@MainActor
final class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()
#if canImport(StoreKit)
    struct EntitlementSnapshot {
        let productID: String
        let isActive: Bool
        let expirationDate: Date?
    }

    struct EntitlementEvaluation {
        let isUnlocked: Bool
        let earliestExpiration: Date?
        let sawManagedTransactions: Bool
    }
#endif

    // Public state
    @Published private(set) var isProUnlocked: Bool = false
    @Published private(set) var products: [String: Any] = [:] // StoreKit.Product when available
    @Published var isLoading: Bool = false
    @Published var lastError: String?
#if DEBUG
    @Published private(set) var isDebugOverrideActive: Bool = false
#endif

    // Product identifiers (keep in sync with App Store Connect once available)
    struct IDs {
        static let monthly = "pro.monthly"
        static let yearly  = "pro.yearly"
    }

    private static let managedProductIDs: Set<String> = [IDs.monthly, IDs.yearly]
    static let cachedEntitlementKey = "PurchaseManager.cachedProEntitlement"
#if DEBUG
    private static let debugOverrideKey = "PurchaseManager.debugProOverride"
#endif

    private let defaults: UserDefaults
    private var updatesTask: Task<Void, Never>? = nil
    private var expirationRefreshTask: Task<Void, Never>? = nil
    private var entitlementRecheckTask: Task<Void, Never>? = nil
    private static let entitlementRetryDelay: TimeInterval = 5

    private var entitlementUnlocked: Bool = false
#if DEBUG
    private var debugOverride: Bool = false
#endif

    init(userDefaults: UserDefaults = .standard, autoStart: Bool = true) {
        self.defaults = userDefaults
        entitlementUnlocked = defaults.bool(forKey: Self.cachedEntitlementKey)
#if DEBUG
        debugOverride = defaults.bool(forKey: Self.debugOverrideKey)
#endif
        updatePublishedUnlockState()

        // Attempt entitlement check immediately
        if autoStart {
            Task { await refreshEntitlements() }
        }
        // Start listening to transaction updates where supported
#if canImport(StoreKit)
        if autoStart {
            updatesTask = Task { await listenForTransactions() }
        }
#endif
    }

    deinit {
        updatesTask?.cancel()
        expirationRefreshTask?.cancel()
        entitlementRecheckTask?.cancel()
    }

    // MARK: - StoreKit Integration

    func loadProducts() async {
        #if canImport(StoreKit)
        isLoading = true; defer { isLoading = false }
        lastError = nil
        do {
            let storeProducts = try await Product.products(for: Array(Self.managedProductIDs))
            var dict: [String: Any] = [:]
            for p in storeProducts { dict[p.id] = p }
            products = dict
            if dict.isEmpty { lastError = "Products unavailable." }
        } catch {
            lastError = error.localizedDescription
        }
        #else
        // No StoreKit: keep empty
        #endif
    }

    func purchase(monthly: Bool) async {
        #if canImport(StoreKit)
        lastError = nil
        guard let product = products[monthly ? IDs.monthly : IDs.yearly] as? Product else {
            lastError = "Products unavailable. Please try again after refreshing."
            return
        }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                applyEntitlementState(from: transaction)
                await transaction.finish()
                await refreshEntitlements()
            case .userCancelled:
                break
            case .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
        #else
        // No StoreKit available
        #endif
    }

    func restorePurchases() async {
        #if canImport(StoreKit)
        lastError = nil
        do { try await AppStore.sync() } catch { lastError = error.localizedDescription }
        await refreshEntitlements()
        #else
        #endif
    }

    func refreshEntitlements(skipRetry: Bool = false) async {
        #if canImport(StoreKit)
        var snapshots: [EntitlementSnapshot] = []
        for productID in Self.managedProductIDs {
            guard let latest = await Transaction.latest(for: productID) else { continue }
            guard case .verified(let transaction) = latest else { continue }
            let active = isTransactionActive(transaction)
            snapshots.append(.init(productID: transaction.productID, isActive: active, expirationDate: transaction.expirationDate))
        }

        handleEntitlementSnapshots(snapshots, skipRetry: skipRetry)
        #else
        // Fallback: keep current state (debug override only)
        #endif
    }

#if DEBUG
    func applyDebugOverride(_ value: Bool) {
        debugOverride = value
        defaults.set(value, forKey: Self.debugOverrideKey)
        updatePublishedUnlockState()
    }

    func simulateEntitlement(_ value: Bool) {
        setEntitlementUnlocked(value)
    }
#endif

    private func isManagedProduct(_ productID: String) -> Bool {
        Self.managedProductIDs.contains(productID)
    }

    private func setEntitlementUnlocked(_ newValue: Bool) {
        if entitlementUnlocked != newValue {
            entitlementUnlocked = newValue
            defaults.set(newValue, forKey: Self.cachedEntitlementKey)
        }
        updatePublishedUnlockState()
    }

    private func updatePublishedUnlockState() {
#if DEBUG
        isDebugOverrideActive = debugOverride
        let unlocked = entitlementUnlocked || debugOverride
#else
        let unlocked = entitlementUnlocked
#endif
        if isProUnlocked != unlocked {
            isProUnlocked = unlocked
        }
    }

    #if canImport(StoreKit)
    private func listenForTransactions() async {
        for await update in Transaction.updates {
            switch update {
            case .verified(let transaction):
                applyEntitlementState(from: transaction)
                await transaction.finish()
                await refreshEntitlements()
            case .unverified:
                break
            @unknown default:
                break
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

    private func isTransactionActive(_ transaction: Transaction) -> Bool {
        guard isManagedProduct(transaction.productID) else { return false }
        if let revocationDate = transaction.revocationDate, revocationDate <= Date() { return false }
        if let expirationDate = transaction.expirationDate, expirationDate <= Date() { return false }
        return true
    }

    private func applyEntitlementState(from transaction: Transaction) {
        guard isManagedProduct(transaction.productID) else { return }
        let active = isTransactionActive(transaction)
        setEntitlementUnlocked(active)
        scheduleExpirationRefresh(for: active ? transaction.expirationDate : nil)
    }

    private func scheduleExpirationRefresh(for expirationDate: Date?) {
        expirationRefreshTask?.cancel()
        guard let expirationDate else {
            expirationRefreshTask = nil
            return
        }

        let delay = expirationDate.timeIntervalSinceNow + 2
        if delay <= 0 {
            expirationRefreshTask = nil
            Task { [weak self] in
                await self?.refreshEntitlements()
            }
            return
        }

        let nanoseconds = UInt64(max(delay, 0) * 1_000_000_000)
        expirationRefreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: nanoseconds)
            await self?.refreshEntitlements()
        }
    }
    #endif

#if canImport(StoreKit)
    private func handleEntitlementSnapshots(_ snapshots: [EntitlementSnapshot], skipRetry: Bool) {
        let evaluation = Self.evaluateEntitlements(from: snapshots)

        if evaluation.isUnlocked {
            entitlementRecheckTask?.cancel()
            scheduleExpirationRefresh(for: evaluation.earliestExpiration)
            setEntitlementUnlocked(true)
            return
        }

        if evaluation.sawManagedTransactions {
            entitlementRecheckTask?.cancel()
            scheduleExpirationRefresh(for: nil)
            setEntitlementUnlocked(false)
            return
        }

        if entitlementUnlocked && !skipRetry {
            entitlementRecheckTask?.cancel()
            entitlementRecheckTask = Task { [weak self] in
                guard let self else { return }
                let delay = UInt64(Self.entitlementRetryDelay * 1_000_000_000)
                try? await Task.sleep(nanoseconds: delay)
                await self.refreshEntitlements(skipRetry: true)
            }
        } else {
            entitlementRecheckTask?.cancel()
            scheduleExpirationRefresh(for: nil)
            setEntitlementUnlocked(false)
        }
    }

    private static func evaluateEntitlements(from snapshots: [EntitlementSnapshot]) -> EntitlementEvaluation {
        let sawManagedTransactions = !snapshots.isEmpty
        let activeSnapshots = snapshots.filter { $0.isActive }
        let earliestExpiration = activeSnapshots.compactMap { $0.expirationDate }.min()
        return EntitlementEvaluation(
            isUnlocked: !activeSnapshots.isEmpty,
            earliestExpiration: earliestExpiration,
            sawManagedTransactions: sawManagedTransactions
        )
    }
#endif

#if DEBUG
#if canImport(StoreKit)
    static func debugEvaluateEntitlements(_ snapshots: [EntitlementSnapshot]) -> EntitlementEvaluation {
        evaluateEntitlements(from: snapshots)
    }
#endif
#endif
}
