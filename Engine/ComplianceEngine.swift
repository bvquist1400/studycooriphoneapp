import Foundation

struct ComplianceInputs {
    var dispensed: Double
    var returned: Double
    var startDate: Date
    var endDate: Date
    var frequency: DosingFrequency
    var missedDoses: Double
    var extraDoses: Double
    var holdDays: Int
    var partialDoseEnabled: Bool
    var prnTargetPerDay: Double? = nil
    // Edge-day expected dose overrides (for non-PRN), in range 0..dosesPerDay
    var firstDayExpectedOverride: Int? = nil
    var lastDayExpectedOverride: Int? = nil
}

struct ComplianceOutputs {
    let expectedDoses: Double
    let actualDoses: Double
    let compliancePct: Double
    let flags: [String]
}

enum ComplianceError: Error, LocalizedError {
    case invalidDates, negativeValues, returnedExceedsDispensed
    var errorDescription: String? {
        switch self {
        case .invalidDates: return "End date must be on or after start date."
        case .negativeValues: return "Inputs cannot be negative."
        case .returnedExceedsDispensed: return "Returned cannot exceed dispensed."
        }
    }
}

struct ComplianceEngine {
    static func compute(_ i: ComplianceInputs, calendar: Calendar = .current) throws -> ComplianceOutputs {
        guard i.dispensed >= 0, i.returned >= 0, i.missedDoses >= 0, i.extraDoses >= 0, i.holdDays >= 0
        else { throw ComplianceError.negativeValues }
        guard i.endDate >= i.startDate else { throw ComplianceError.invalidDates }
        guard i.returned <= i.dispensed else { throw ComplianceError.returnedExceedsDispensed }

        let days = daysBetweenInclusive(from: i.startDate, to: i.endDate, calendar: calendar)
        let effectiveDays = max(0, days - i.holdDays)

        var expected: Double = (i.frequency == .prn)
            ? max(0, (i.prnTargetPerDay ?? 0) * Double(effectiveDays))
            : max(0, i.frequency.dosesPerDay * Double(effectiveDays))

        // Apply first/last day expected overrides for scheduled regimens
        if i.frequency != .prn {
            let maxPer = i.frequency.dosesPerDay
            let maxPerInt = max(0, Int(maxPer))
            if effectiveDays == 1 {
                if let single = i.lastDayExpectedOverride ?? i.firstDayExpectedOverride {
                    let clamped = max(0, min(maxPerInt, single))
                    expected = Double(clamped)
                }
            } else if effectiveDays >= 2 {
                var delta: Double = 0
                if let first = i.firstDayExpectedOverride {
                    let clamped = max(0, min(maxPerInt, first))
                    delta += Double(clamped - maxPerInt)
                }
                if let last = i.lastDayExpectedOverride {
                    let clamped = max(0, min(maxPerInt, last))
                    delta += Double(clamped - maxPerInt)
                }
                expected = max(0, expected + delta)
            }
        }

        var actual = (i.dispensed - i.returned) - i.missedDoses + i.extraDoses
        if !i.partialDoseEnabled { actual = round(actual) }
        actual = max(0, actual)

        let compliance = expected == 0
            ? (actual == 0 ? 100 : 0)
            : min(150, max(0, (actual / expected) * 100))

        var flags: [String] = []
        if expected > 0 {
            if compliance < 90 { flags.append("UNDERUSE") }
            if compliance > 110 { flags.append("OVERUSE") }
        }
        if days != effectiveDays { flags.append("HOLD_DAYS:\(i.holdDays)") }

        return .init(expectedDoses: expected, actualDoses: actual, compliancePct: compliance, flags: flags)
    }

    static func daysBetweenInclusive(from: Date, to: Date, calendar: Calendar) -> Int {
        let s = calendar.startOfDay(for: from)
        let e = calendar.startOfDay(for: to)
        return ((calendar.dateComponents([.day], from: s, to: e).day) ?? 0) + 1
    }
}
