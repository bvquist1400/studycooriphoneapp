import Foundation
import SwiftData

@Model
final class Calculation {
    // Inputs
    var subjectId: String?
    var startDate: Date
    var endDate: Date
    var frequency: DosingFrequency
    var dispensed: Double
    var returned: Double
    var missedDoses: Double
    var extraDoses: Double
    var holdDays: Int
    var partialDoseEnabled: Bool
    var prnTargetPerDay: Double?
    var firstDayExpectedOverride: Int?
    var lastDayExpectedOverride: Int?

    // Outputs
    var expectedDoses: Double
    var actualDoses: Double
    var compliancePct: Double
    var flags: [String]

    // Metadata
    var createdAt: Date

    // Optional: tag by drug name for multi-drug studies
    var drugName: String?

    // Relationships
    @Relationship(deleteRule: .cascade)
    var bottles: [Bottle]

    init(
        subjectId: String? = nil,
        startDate: Date = Date(),
        endDate: Date = Date(),
        frequency: DosingFrequency = .qd,
        dispensed: Double = 0,
        returned: Double = 0,
        missedDoses: Double = 0,
        extraDoses: Double = 0,
        holdDays: Int = 0,
        partialDoseEnabled: Bool = false,
        prnTargetPerDay: Double? = nil,
        firstDayExpectedOverride: Int? = nil,
        lastDayExpectedOverride: Int? = nil,
        expectedDoses: Double = 0,
        actualDoses: Double = 0,
        compliancePct: Double = 0,
        flags: [String] = [],
        createdAt: Date = Date(),
        drugName: String? = nil,
        bottles: [Bottle] = []
    ) {
        self.subjectId = subjectId
        self.startDate = startDate
        self.endDate = endDate
        self.frequency = frequency
        self.dispensed = dispensed
        self.returned = returned
        self.missedDoses = missedDoses
        self.extraDoses = extraDoses
        self.holdDays = holdDays
        self.partialDoseEnabled = partialDoseEnabled
        self.prnTargetPerDay = prnTargetPerDay
        self.firstDayExpectedOverride = firstDayExpectedOverride
        self.lastDayExpectedOverride = lastDayExpectedOverride
        self.expectedDoses = expectedDoses
        self.actualDoses = actualDoses
        self.compliancePct = compliancePct
        self.flags = flags
        self.createdAt = createdAt
        self.drugName = drugName
        self.bottles = bottles
    }
}
