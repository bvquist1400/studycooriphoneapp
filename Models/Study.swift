import Foundation
import SwiftData

@Model
final class Study {
    var name: String
    var notes: String?
    var uuid: UUID

    // Defaults for new calculations within this study
    var defaultFrequency: DosingFrequency
    var defaultPartialDoseEnabled: Bool
    var defaultPrnTargetPerDay: Double?

    // Multi-drug support
    var multiDrug: Bool = false

    var createdAt: Date

    @Relationship(deleteRule: .cascade)
    var subjects: [Subject]

    @Relationship(deleteRule: .cascade)
    var drugs: [Drug]

    init(
        name: String,
        notes: String? = nil,
        defaultFrequency: DosingFrequency = .qd,
        defaultPartialDoseEnabled: Bool = false,
        defaultPrnTargetPerDay: Double? = nil,
        multiDrug: Bool = false,
        createdAt: Date = .now,
        uuid: UUID = UUID(),
        subjects: [Subject] = [],
        drugs: [Drug] = []
    ) {
        self.name = name
        self.notes = notes
        self.defaultFrequency = defaultFrequency
        self.defaultPartialDoseEnabled = defaultPartialDoseEnabled
        self.defaultPrnTargetPerDay = defaultPrnTargetPerDay
        self.multiDrug = multiDrug
        self.createdAt = createdAt
        self.uuid = uuid
        self.subjects = subjects
        self.drugs = drugs
    }
}
