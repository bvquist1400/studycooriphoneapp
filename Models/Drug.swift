import Foundation
import SwiftData

@Model
final class Drug {
    var name: String
    var notes: String?

    // Defaults for new calculations with this drug
    var defaultFrequency: DosingFrequency
    var defaultPartialDoseEnabled: Bool
    var defaultPrnTargetPerDay: Double?

    @Relationship(inverse: \Study.drugs)
    var study: Study?

    init(
        name: String,
        notes: String? = nil,
        defaultFrequency: DosingFrequency = .qd,
        defaultPartialDoseEnabled: Bool = false,
        defaultPrnTargetPerDay: Double? = nil,
        study: Study? = nil
    ) {
        self.name = name
        self.notes = notes
        self.defaultFrequency = defaultFrequency
        self.defaultPartialDoseEnabled = defaultPartialDoseEnabled
        self.defaultPrnTargetPerDay = defaultPrnTargetPerDay
        self.study = study
    }
}

