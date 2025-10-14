#if DEBUG
import XCTest
import Foundation
@testable import StudyCoor

@MainActor
final class PurchaseManagerTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "PurchaseManagerTests"

    override func setUpWithError() throws {
        try super.setUpWithError()
        defaults = UserDefaults(suiteName: suiteName)
        XCTAssertNotNil(defaults, "Failed to create UserDefaults suite for testing")
        defaults?.removePersistentDomain(forName: suiteName)
    }

    override func tearDownWithError() throws {
        defaults?.removePersistentDomain(forName: suiteName)
        defaults = nil
        try super.tearDownWithError()
    }

    func testCachedEntitlementRestoresUnlockState() {
        guard let defaults else {
            XCTFail("Defaults not initialised")
            return
        }

        let manager = PurchaseManager(userDefaults: defaults, autoStart: false)

        manager.simulateEntitlement(true)
        let unlocked = manager.isProUnlocked
        XCTAssertTrue(unlocked, "Entitlement should unlock after simulation")

        let cachedValue = defaults.bool(forKey: PurchaseManager.cachedEntitlementKey)
        XCTAssertTrue(cachedValue, "Entitlement cache should be persisted to defaults")

        let restored = PurchaseManager(userDefaults: defaults, autoStart: false)
        let restoredUnlocked = restored.isProUnlocked
        XCTAssertTrue(restoredUnlocked, "Entitlement should restore from cache on reinitialisation")
    }

    func testDebugOverrideSupersedesEntitlement() {
        guard let defaults else {
            XCTFail("Defaults not initialised")
            return
        }

        let manager = PurchaseManager(userDefaults: defaults, autoStart: false)

        manager.simulateEntitlement(false)
        manager.applyDebugOverride(true)
        let unlocked = manager.isProUnlocked
        XCTAssertTrue(unlocked, "Debug override should force unlock")

        manager.applyDebugOverride(false)
        let locked = manager.isProUnlocked
        XCTAssertFalse(locked, "Revoking debug override should return to entitlement state")
    }

    func testEntitlementEvaluationUnlocksWithActiveTransaction() {
        #if canImport(StoreKit)
        let expiration = Date().addingTimeInterval(3600)
        let snapshot = PurchaseManager.EntitlementSnapshot(
            productID: PurchaseManager.IDs.monthly,
            isActive: true,
            expirationDate: expiration
        )
        let evaluation = PurchaseManager.debugEvaluateEntitlements([snapshot])
        XCTAssertTrue(evaluation.isUnlocked, "Active transaction should unlock entitlement")
        XCTAssertEqual(evaluation.earliestExpiration, expiration, "Earliest expiration should match active transaction")
        XCTAssertTrue(evaluation.sawManagedTransactions, "Evaluation should note managed transaction presence")
        #endif
    }

    func testEntitlementEvaluationRemainsLockedForInactiveTransactions() {
        #if canImport(StoreKit)
        let snapshot = PurchaseManager.EntitlementSnapshot(
            productID: PurchaseManager.IDs.monthly,
            isActive: false,
            expirationDate: Date().addingTimeInterval(-3600)
        )
        let evaluation = PurchaseManager.debugEvaluateEntitlements([snapshot])
        XCTAssertFalse(evaluation.isUnlocked, "Inactive transaction should keep entitlement locked")
        XCTAssertNil(evaluation.earliestExpiration, "No active transaction should yield nil expiration")
        XCTAssertTrue(evaluation.sawManagedTransactions, "Managed transaction should be detected even if inactive")
        #endif
    }

    func testEntitlementEvaluationHandlesNoTransactions() {
        #if canImport(StoreKit)
        let evaluation = PurchaseManager.debugEvaluateEntitlements([])
        XCTAssertFalse(evaluation.isUnlocked, "No transactions should keep entitlement locked")
        XCTAssertNil(evaluation.earliestExpiration, "No transactions means no expiration")
        XCTAssertFalse(evaluation.sawManagedTransactions, "No transactions should report absence")
        #endif
    }
}
#endif
