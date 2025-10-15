import XCTest
@testable import StudyCoor

final class ComplianceBreakdownScenariosTests: XCTestCase {
    private let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private func date(_ string: String) -> Date {
        guard let value = isoFormatter.date(from: string) else {
            fatalError("Invalid ISO8601 date string: \(string)")
        }
        return value
    }

    func testPRNTargetAndHoldDaysFlowIntoBreakdown() throws {
        let start = date("2025-07-01T00:00:00.000Z")
        let end = date("2025-07-04T00:00:00.000Z") // 4 days
        let inputs = ComplianceInputs(
            dispensed: 10, returned: 4,
            startDate: start, endDate: end,
            frequency: .prn,
            missedDoses: 0, extraDoses: 0, holdDays: 1,
            partialDoseEnabled: true,
            prnTargetPerDay: 1.5
        )

        let outputs = try ComplianceEngine.compute(inputs, calendar: Calendar(identifier: .gregorian))
        let expected = outputs.breakdown.expected
        let actual = outputs.breakdown.actual

        XCTAssertEqual(expected.inclusiveDays, 4)
        XCTAssertEqual(expected.holdDays, 1)
        XCTAssertEqual(expected.effectiveDays, 3)
        XCTAssertEqual(expected.baseDosesPerDay, 1.5, accuracy: 0.0001)
        XCTAssertEqual(expected.prnTargetPerDay ?? -1, 1.5, accuracy: 0.0001)
        XCTAssertEqual(expected.baseExpected, 4.5, accuracy: 0.0001)
        XCTAssertEqual(expected.totalExpected, 4.5, accuracy: 0.0001)

        XCTAssertEqual(actual.rawActual, 6, accuracy: 0.0001)
        XCTAssertEqual(actual.afterRounding, 6, accuracy: 0.0001)
        XCTAssertEqual(actual.afterClamping, 6, accuracy: 0.0001)
        XCTAssertTrue(outputs.flags.contains("HOLD_DAYS:1"))
        XCTAssertTrue(outputs.flags.contains("OVERUSE"))
    }

    func testEdgeDayOverridesAdjustExpectedTotals() throws {
        var inputs = ComplianceInputs(
            dispensed: 3, returned: 0,
            startDate: date("2025-06-01T00:00:00.000Z"),
            endDate: date("2025-06-03T00:00:00.000Z"),
            frequency: .bid,
            missedDoses: 0, extraDoses: 0, holdDays: 0,
            partialDoseEnabled: false
        )
        inputs.firstDayExpectedOverride = 1
        inputs.lastDayExpectedOverride = 0

        let outputs = try ComplianceEngine.compute(inputs, calendar: Calendar(identifier: .gregorian))
        let expected = outputs.breakdown.expected
        let actual = outputs.breakdown.actual

        XCTAssertEqual(expected.baseExpected, 6, accuracy: 0.0001)
        XCTAssertEqual(expected.firstDayAdjustment, -1, accuracy: 0.0001)
        XCTAssertEqual(expected.lastDayAdjustment, -2, accuracy: 0.0001)
        XCTAssertEqual(expected.totalExpected, 3, accuracy: 0.0001)
        XCTAssertEqual(outputs.expectedDoses, 3, accuracy: 0.0001)

        XCTAssertEqual(actual.rawActual, 3, accuracy: 0.0001)
        XCTAssertEqual(actual.afterRounding, 3, accuracy: 0.0001)
        XCTAssertEqual(actual.afterClamping, 3, accuracy: 0.0001)
        XCTAssertEqual(outputs.compliancePct, 100, accuracy: 0.0001)
    }

    func testNegativeRawActualRoundsAndClampsToZero() throws {
        let inputs = ComplianceInputs(
            dispensed: 4, returned: 0,
            startDate: date("2025-05-01T00:00:00.000Z"),
            endDate: date("2025-05-02T00:00:00.000Z"),
            frequency: .bid,
            missedDoses: 10, extraDoses: 0, holdDays: 0,
            partialDoseEnabled: false
        )

        let outputs = try ComplianceEngine.compute(inputs, calendar: Calendar(identifier: .gregorian))
        let actual = outputs.breakdown.actual

        XCTAssertEqual(actual.rawActual, -6, accuracy: 0.0001)
        XCTAssertEqual(actual.afterRounding, -6, accuracy: 0.0001)
        XCTAssertEqual(actual.afterClamping, 0, accuracy: 0.0001)
        XCTAssertEqual(outputs.actualDoses, 0, accuracy: 0.0001)
        XCTAssertEqual(outputs.compliancePct, 0, accuracy: 0.0001)
        XCTAssertTrue(outputs.flags.contains("UNDERUSE"))
    }
}
