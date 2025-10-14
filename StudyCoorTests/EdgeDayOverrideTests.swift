import XCTest
@testable import StudyCoor

final class EdgeDayOverrideTests: XCTestCase {
    func testSingleDay_UsesOverride() throws {
        let start = ISO8601DateFormatter().date(from: "2025-05-01T00:00:00Z")!
        let end = start
        var inputs = ComplianceInputs(
            dispensed: 3, returned: 0,
            startDate: start, endDate: end,
            frequency: .tid,
            missedDoses: 0, extraDoses: 0, holdDays: 0,
            partialDoseEnabled: false
        )

        inputs.firstDayExpectedOverride = 1
        let out1 = try ComplianceEngine.compute(inputs)
        XCTAssertEqual(out1.expectedDoses, 1, accuracy: 0.001)
        XCTAssertEqual(out1.breakdown.expected.firstDayAdjustment, -2, accuracy: 0.001)
        XCTAssertEqual(out1.breakdown.expected.totalExpected, 1, accuracy: 0.001)

        inputs.firstDayExpectedOverride = nil
        inputs.lastDayExpectedOverride = 2
        let out2 = try ComplianceEngine.compute(inputs)
        XCTAssertEqual(out2.expectedDoses, 2, accuracy: 0.001)
        XCTAssertEqual(out2.breakdown.expected.lastDayAdjustment, -1, accuracy: 0.001)
    }

    func testTwoDays_AdjustsBothEnds() throws {
        let start = ISO8601DateFormatter().date(from: "2025-05-01T00:00:00Z")!
        let end = ISO8601DateFormatter().date(from: "2025-05-02T00:00:00Z")!
        var inputs = ComplianceInputs(
            dispensed: 6, returned: 0,
            startDate: start, endDate: end,
            frequency: .tid, // 3 per day
            missedDoses: 0, extraDoses: 0, holdDays: 0,
            partialDoseEnabled: false
        )
        // Base expected = 6. First=2 (delta -1), Last=1 (delta -2) -> 6-3=3
        inputs.firstDayExpectedOverride = 2
        inputs.lastDayExpectedOverride = 1
        let out = try ComplianceEngine.compute(inputs)
        XCTAssertEqual(out.expectedDoses, 3, accuracy: 0.001)
        XCTAssertEqual(out.breakdown.expected.firstDayAdjustment, -1, accuracy: 0.001)
        XCTAssertEqual(out.breakdown.expected.lastDayAdjustment, -2, accuracy: 0.001)
        XCTAssertEqual(out.breakdown.expected.baseExpected, 6, accuracy: 0.001)
    }
}
