import Foundation
import SwiftData

@Model
final class Subject {
    // Human‑friendly subject identifier (used to match Calculation.subjectId)
    var code: String
    var displayName: String?
    var notes: String?
    var createdAt: Date

    @Relationship(inverse: \Study.subjects)
    var study: Study?

    @Relationship(deleteRule: .cascade, inverse: \Calculation.subject)
    var calculations: [Calculation]

    init(code: String, displayName: String? = nil, notes: String? = nil, createdAt: Date = .now, study: Study? = nil, calculations: [Calculation] = []) {
        self.code = code
        self.displayName = displayName
        self.notes = notes
        self.createdAt = createdAt
        self.study = study
        self.calculations = calculations
    }
}
