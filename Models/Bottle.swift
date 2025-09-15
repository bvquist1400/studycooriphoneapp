import Foundation
import SwiftData

@Model
final class Bottle {
    var label: String
    var dispensed: Double
    var returned: Double

    init(label: String = "Bottle", dispensed: Double = 0, returned: Double = 0) {
        self.label = label
        self.dispensed = dispensed
        self.returned = returned
    }
}

