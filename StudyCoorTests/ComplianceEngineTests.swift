//
//  ComplianceEngineTests.swift
//  StudyCoorTests
//

import XCTest
@testable import StudyCoor

final class ComplianceEngineTests: XCTestCase {

    func testQD_30Days_NoHolds() throws {
        let start = ISO8601DateFormatter().date(from: "2025-01-01T00:00:00Z")!
        let end   = ISO8601DateFormatter().date(from: "2025-01-30T00:00:00Z")!
        let inputs = ComplianceInputs(
            dispensed: 30, returned: 0,
            startDate: start, endDate: end,
            frequency: .qd,
            missedDoses: 0, extraDoses: 0, holdDays: 0,
            partialDoseEnabled: false
        )
        let out = try ComplianceEngine.compute(inputs)
        XCTAssertEqual(out.expectedDoses, 30, accuracy: 0.001)
        XCTAssertEqual(out.actualDoses, 30, accuracy: 0.001)
        XCTAssertEqual(out.compliancePct, 100, accuracy: 0.001)
        XCTAssertTrue(out.flags.isEmpty)

        XCTAssertEqual(out.breakdown.expected.inclusiveDays, 30)
        XCTAssertEqual(out.breakdown.expected.holdDays, 0)
        XCTAssertEqual(out.breakdown.expected.effectiveDays, 30)
        XCTAssertEqual(out.breakdown.expected.baseExpected, 30, accuracy: 0.001)
        XCTAssertEqual(out.breakdown.expected.totalExpected, 30, accuracy: 0.001)
        XCTAssertEqual(out.breakdown.actual.rawActual, 30, accuracy: 0.001)
        XCTAssertEqual(out.breakdown.actual.afterRounding, 30, accuracy: 0.001)
        XCTAssertEqual(out.breakdown.actual.afterClamping, 30, accuracy: 0.001)
    }

    func testBID_WithHoldsAndMissed() throws {
        let start = ISO8601DateFormatter().date(from: "2025-02-01T00:00:00Z")!
        let end   = ISO8601DateFormatter().date(from: "2025-02-14T00:00:00Z")!
        let inputs = ComplianceInputs(
            dispensed: 40, returned: 10,
            startDate: start, endDate: end,
            frequency: .bid,
            missedDoses: 2, extraDoses: 0, holdDays: 2,
            partialDoseEnabled: true
        )
        let out = try ComplianceEngine.compute(inputs)
        // Period = 14 days inclusive; holds 2 → effective 12 days; BID → 24 expected
        XCTAssertEqual(out.expectedDoses, 24, accuracy: 0.001)
        // Actual = (40-10) - 2 = 28
        XCTAssertEqual(out.actualDoses, 28, accuracy: 0.001)
        XCTAssertEqual(out.compliancePct, (28/24)*100, accuracy: 0.01)
        XCTAssertTrue(out.flags.contains(where: { $0.hasPrefix("HOLD_DAYS:") }))
        XCTAssertTrue(out.flags.contains("OVERUSE"))

        XCTAssertTrue(out.flagDescriptions.contains("Paused for 2 hold days"))
        XCTAssertTrue(out.flagDescriptions.contains("Usage above 110% — possible overadherence"))

        XCTAssertEqual(out.breakdown.expected.inclusiveDays, 14)
        XCTAssertEqual(out.breakdown.expected.holdDays, 2)
        XCTAssertEqual(out.breakdown.expected.effectiveDays, 12)
        XCTAssertEqual(out.breakdown.expected.baseExpected, 24, accuracy: 0.001)
        XCTAssertEqual(out.breakdown.expected.firstDayAdjustment, 0, accuracy: 0.001)
        XCTAssertEqual(out.breakdown.expected.lastDayAdjustment, 0, accuracy: 0.001)
        XCTAssertEqual(out.breakdown.actual.rawActual, 28, accuracy: 0.001)
        XCTAssertTrue(out.breakdown.actual.partialDosesEnabled)
    }

    func testPRN_NoTarget() throws {
        let start = ISO8601DateFormatter().date(from: "2025-03-01T00:00:00Z")!
        let end   = ISO8601DateFormatter().date(from: "2025-03-07T00:00:00Z")!
        let inputs = ComplianceInputs(
            dispensed: 20, returned: 15,
            startDate: start, endDate: end,
            frequency: .prn,
            missedDoses: 0, extraDoses: 0, holdDays: 0,
            partialDoseEnabled: false,
            prnTargetPerDay: nil
        )
        let out = try ComplianceEngine.compute(inputs)
        XCTAssertEqual(out.expectedDoses, 0, accuracy: 0.001)
        // Actual = 5; with expected 0, compliance becomes 0 (flag for info)
        XCTAssertEqual(out.actualDoses, 5, accuracy: 0.001)
        XCTAssertEqual(out.compliancePct, 0, accuracy: 0.001)

        XCTAssertNil(out.breakdown.expected.prnTargetPerDay)
        XCTAssertEqual(out.breakdown.expected.totalExpected, 0, accuracy: 0.001)
        XCTAssertEqual(out.breakdown.actual.rawActual, 5, accuracy: 0.001)
    }

    func testPartialRoundingBehavior() throws {
        let start = ISO8601DateFormatter().date(from: "2025-01-01T00:00:00Z")!
        let end   = ISO8601DateFormatter().date(from: "2025-01-07T00:00:00Z")!
        
        // Test with partials enabled - should preserve decimal values
        let inputsWithPartials = ComplianceInputs(
            dispensed: 10.7, returned: 0.2,
            startDate: start, endDate: end,
            frequency: .qd,
            missedDoses: 0, extraDoses: 0, holdDays: 0,
            partialDoseEnabled: true
        )
        let outWithPartials = try ComplianceEngine.compute(inputsWithPartials)
        // Actual = 10.7 - 0.2 = 10.5 (preserved as decimal)
        XCTAssertEqual(outWithPartials.actualDoses, 10.5, accuracy: 0.001)
        XCTAssertEqual(outWithPartials.breakdown.actual.rawActual, 10.5, accuracy: 0.001)
        XCTAssertEqual(outWithPartials.breakdown.actual.afterRounding, 10.5, accuracy: 0.001)
        XCTAssertTrue(outWithPartials.breakdown.actual.partialDosesEnabled)
        
        // Test with partials disabled - should round to whole number
        let inputsWithoutPartials = ComplianceInputs(
            dispensed: 10.7, returned: 0.2,
            startDate: start, endDate: end,
            frequency: .qd,
            missedDoses: 0, extraDoses: 0, holdDays: 0,
            partialDoseEnabled: false
        )
        let outWithoutPartials = try ComplianceEngine.compute(inputsWithoutPartials)
        // Actual = round(10.7 - 0.2) = round(10.5) = 11.0 (rounded to nearest whole)
        XCTAssertEqual(outWithoutPartials.actualDoses, 11.0, accuracy: 0.001)
        XCTAssertEqual(outWithoutPartials.breakdown.actual.rawActual, 10.5, accuracy: 0.001)
        XCTAssertEqual(outWithoutPartials.breakdown.actual.afterRounding, 11.0, accuracy: 0.001)
        XCTAssertEqual(outWithoutPartials.breakdown.actual.afterClamping, 11.0, accuracy: 0.001)
        XCTAssertFalse(outWithoutPartials.breakdown.actual.partialDosesEnabled)
    }

    func testFlagDescriptionsUnderuse() throws {
        let start = ISO8601DateFormatter().date(from: "2025-04-01T00:00:00Z")!
        let end   = ISO8601DateFormatter().date(from: "2025-04-02T00:00:00Z")!
        let inputs = ComplianceInputs(
            dispensed: 2, returned: 0,
            startDate: start, endDate: end,
            frequency: .qd,
            missedDoses: 1, extraDoses: 0, holdDays: 0,
            partialDoseEnabled: true
        )
        let out = try ComplianceEngine.compute(inputs)
        XCTAssertTrue(out.flags.contains("UNDERUSE"))
        XCTAssertEqual(out.flagDescriptions, ["Usage below 90% — investigate missed doses"])
    }

    func testValidation_ReturnedExceedsDispensed() {
        let start = Date(), end = Date()
        let bad = ComplianceInputs(
            dispensed: 10, returned: 12,
            startDate: start, endDate: end,
            frequency: .qd, missedDoses: 0, extraDoses: 0, holdDays: 0, partialDoseEnabled: false
        )
        XCTAssertThrowsError(try ComplianceEngine.compute(bad)) { err in
            XCTAssertEqual(err as? ComplianceError, .returnedExceedsDispensed)
        }
    }
}
