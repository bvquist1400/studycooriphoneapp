import XCTest
@testable import StudyCoor

final class BottleTotalsTests: XCTestCase {
    func testBottleTotalsFeedEngine() throws {
        // Simulate three bottles
        let bottles: [(dispensed: Double, returned: Double)] = [(20, 2), (15, 1), (10, 0)]
        let dispensed = bottles.reduce(0) { $0 + $1.dispensed }
        let returned = bottles.reduce(0) { $0 + $1.returned }

        let start = ISO8601DateFormatter().date(from: "2025-05-01T00:00:00Z")!
        let end   = ISO8601DateFormatter().date(from: "2025-05-10T00:00:00Z")!

        let inputs = ComplianceInputs(
            dispensed: dispensed,
            returned: returned,
            startDate: start,
            endDate: end,
            frequency: .qd,   // 10 days inclusive => expected 10
            missedDoses: 1,
            extraDoses: 0,
            holdDays: 0,
            partialDoseEnabled: false
        )

        let out = try ComplianceEngine.compute(inputs)
        // Actual = (sum dispensed - sum returned) - missed
        XCTAssertEqual(out.actualDoses, (45 - 3) - 1, accuracy: 0.001)
        XCTAssertEqual(out.expectedDoses, 10, accuracy: 0.001)
    }
}

