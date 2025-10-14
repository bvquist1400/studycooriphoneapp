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

struct ComplianceBreakdown: Codable, Equatable {
    struct Expected: Codable, Equatable {
        let inclusiveDays: Int
        let holdDays: Int
        let effectiveDays: Int
        let baseDosesPerDay: Double
        let prnTargetPerDay: Double?
        let baseExpected: Double
        let firstDayAdjustment: Double
        let lastDayAdjustment: Double
        let totalExpected: Double
    }

    struct Actual: Codable, Equatable {
        let dispensed: Double
        let returned: Double
        let missed: Double
        let extra: Double
        let rawActual: Double
        let afterRounding: Double
        let afterClamping: Double
        let partialDosesEnabled: Bool
    }

    let expected: Expected
    let actual: Actual
}

struct ComplianceOutputs {
    let expectedDoses: Double
    let actualDoses: Double
    let compliancePct: Double
    let flags: [String]
    let breakdown: ComplianceBreakdown

    static func description(for flag: String) -> String {
        if flag.hasPrefix("HOLD_DAYS:") {
            if let value = Int(flag.split(separator: ":").last ?? "") {
                return "Paused for \(value) hold day\(value == 1 ? "" : "s")"
            }
            return "Includes hold days"
        }
        switch flag {
        case "UNDERUSE":
            return "Usage below 90% — investigate missed doses"
        case "OVERUSE":
            return "Usage above 110% — possible overadherence"
        default:
            return flag.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    var flagDescriptions: [String] {
        flags.map { Self.description(for: $0) }
    }
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
        let baseDosesPerDay = (i.frequency == .prn) ? (i.prnTargetPerDay ?? 0) : i.frequency.dosesPerDay
        let baseExpected = max(0, baseDosesPerDay * Double(effectiveDays))
        var firstAdjustment: Double = 0
        var lastAdjustment: Double = 0

        var expected = baseExpected

        // Apply first/last day expected overrides for scheduled regimens
        if i.frequency != .prn {
            let maxPer = i.frequency.dosesPerDay
            let maxPerInt = max(0, Int(maxPer))
            if effectiveDays == 1 {
                if let single = i.lastDayExpectedOverride ?? i.firstDayExpectedOverride {
                    let clamped = max(0, min(maxPerInt, single))
                    let delta = Double(clamped) - baseExpected
                    if i.lastDayExpectedOverride != nil {
                        lastAdjustment = delta
                    } else {
                        firstAdjustment = delta
                    }
                    expected = Double(clamped)
                }
            } else if effectiveDays >= 2 {
                var delta: Double = 0
                if let first = i.firstDayExpectedOverride {
                    let clamped = max(0, min(maxPerInt, first))
                    let diff = Double(clamped - maxPerInt)
                    firstAdjustment = diff
                    delta += diff
                }
                if let last = i.lastDayExpectedOverride {
                    let clamped = max(0, min(maxPerInt, last))
                    let diff = Double(clamped - maxPerInt)
                    lastAdjustment = diff
                    delta += diff
                }
                expected = max(0, expected + delta)
            }
        }

        let rawActual = (i.dispensed - i.returned) - i.missedDoses + i.extraDoses
        let afterRounding = i.partialDoseEnabled ? rawActual : round(rawActual)
        let actual = max(0, afterRounding)

        let compliance = expected == 0
            ? (actual == 0 ? 100 : 0)
            : min(150, max(0, (actual / expected) * 100))

        var flags: [String] = []
        if expected > 0 {
            if compliance < 90 { flags.append("UNDERUSE") }
            if compliance > 110 { flags.append("OVERUSE") }
        }
        if days != effectiveDays { flags.append("HOLD_DAYS:\(i.holdDays)") }

        let breakdown = ComplianceBreakdown(
            expected: .init(
                inclusiveDays: days,
                holdDays: i.holdDays,
                effectiveDays: effectiveDays,
                baseDosesPerDay: i.frequency == .prn ? i.prnTargetPerDay ?? 0 : i.frequency.dosesPerDay,
                prnTargetPerDay: i.frequency == .prn ? i.prnTargetPerDay : nil,
                baseExpected: baseExpected,
                firstDayAdjustment: firstAdjustment,
                lastDayAdjustment: lastAdjustment,
                totalExpected: expected
            ),
            actual: .init(
                dispensed: i.dispensed,
                returned: i.returned,
                missed: i.missedDoses,
                extra: i.extraDoses,
                rawActual: rawActual,
                afterRounding: afterRounding,
                afterClamping: actual,
                partialDosesEnabled: i.partialDoseEnabled
            )
        )

        return .init(expectedDoses: expected, actualDoses: actual, compliancePct: compliance, flags: flags, breakdown: breakdown)
    }

    static func daysBetweenInclusive(from: Date, to: Date, calendar: Calendar) -> Int {
        let s = calendar.startOfDay(for: from)
        let e = calendar.startOfDay(for: to)
        return ((calendar.dateComponents([.day], from: s, to: e).day) ?? 0) + 1
    }
}
