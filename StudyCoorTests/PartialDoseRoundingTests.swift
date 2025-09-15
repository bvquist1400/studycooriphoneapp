import XCTest
@testable import StudyCoor

final class PartialDoseRoundingTests: XCTestCase {
    func testRoundingOff_RoundsActual() throws {
        let day = ISO8601DateFormatter().date(from: "2025-06-01T00:00:00Z")!
        let inputs = ComplianceInputs(
            dispensed: 10.6, returned: 0,
            startDate: day, endDate: day,
            frequency: .qd,
            missedDoses: 0, extraDoses: 0, holdDays: 0,
            partialDoseEnabled: false
        )
        let out = try ComplianceEngine.compute(inputs)
        XCTAssertEqual(out.actualDoses, 11, accuracy: 0.0001)
    }

    func testRoundingOn_KeepsFraction() throws {
        let day = ISO8601DateFormatter().date(from: "2025-06-01T00:00:00Z")!
        let inputs = ComplianceInputs(
            dispensed: 10.6, returned: 0,
            startDate: day, endDate: day,
            frequency: .qd,
            missedDoses: 0, extraDoses: 0, holdDays: 0,
            partialDoseEnabled: true
        )
        let out = try ComplianceEngine.compute(inputs)
        XCTAssertEqual(out.actualDoses, 10.6, accuracy: 0.0001)
    }
}

