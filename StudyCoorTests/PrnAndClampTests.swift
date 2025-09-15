import XCTest
@testable import StudyCoor

final class PrnAndClampTests: XCTestCase {
    func testPRN_WithTarget_ComputesExpected() throws {
        let start = ISO8601DateFormatter().date(from: "2025-07-01T00:00:00Z")!
        let end   = ISO8601DateFormatter().date(from: "2025-07-04T00:00:00Z")! // 4 days inclusive
        let inputs = ComplianceInputs(
            dispensed: 20, returned: 13,
            startDate: start, endDate: end,
            frequency: .prn,
            missedDoses: 0, extraDoses: 0, holdDays: 0,
            partialDoseEnabled: true,
            prnTargetPerDay: 1.5
        )
        let out = try ComplianceEngine.compute(inputs)
        XCTAssertEqual(out.expectedDoses, 6, accuracy: 0.0001)
        XCTAssertEqual(out.actualDoses, 7, accuracy: 0.0001)
        XCTAssertEqual(out.compliancePct, (7/6)*100, accuracy: 0.01)
    }

    func testClamp_Overuse_CappedAt150() throws {
        let start = ISO8601DateFormatter().date(from: "2025-08-01T00:00:00Z")!
        let end   = start // 1 day expected = 1
        let inputs = ComplianceInputs(
            dispensed: 20, returned: 0,
            startDate: start, endDate: end,
            frequency: .qd,
            missedDoses: 0, extraDoses: 0, holdDays: 0,
            partialDoseEnabled: false
        )
        let out = try ComplianceEngine.compute(inputs)
        XCTAssertEqual(out.expectedDoses, 1, accuracy: 0.0001)
        XCTAssertEqual(out.compliancePct, 150, accuracy: 0.0001)
    }

    func testZeroExpected_ZeroActual_Is100() throws {
        let start = ISO8601DateFormatter().date(from: "2025-09-01T00:00:00Z")!
        let end   = start
        let inputs = ComplianceInputs(
            dispensed: 0, returned: 0,
            startDate: start, endDate: end,
            frequency: .prn,
            missedDoses: 0, extraDoses: 0, holdDays: 0,
            partialDoseEnabled: false,
            prnTargetPerDay: nil
        )
        let out = try ComplianceEngine.compute(inputs)
        XCTAssertEqual(out.expectedDoses, 0, accuracy: 0.0001)
        XCTAssertEqual(out.actualDoses, 0, accuracy: 0.0001)
        XCTAssertEqual(out.compliancePct, 100, accuracy: 0.0001)
    }

    func testZeroExpected_NonZeroActual_Is0() throws {
        let start = ISO8601DateFormatter().date(from: "2025-10-01T00:00:00Z")!
        let end   = start
        let inputs = ComplianceInputs(
            dispensed: 5, returned: 0,
            startDate: start, endDate: end,
            frequency: .prn,
            missedDoses: 0, extraDoses: 0, holdDays: 0,
            partialDoseEnabled: false,
            prnTargetPerDay: nil
        )
        let out = try ComplianceEngine.compute(inputs)
        XCTAssertEqual(out.expectedDoses, 0, accuracy: 0.0001)
        XCTAssertEqual(out.actualDoses, 5, accuracy: 0.0001)
        XCTAssertEqual(out.compliancePct, 0, accuracy: 0.0001)
    }
}

