import Foundation

enum DosingFrequency: String, Codable, CaseIterable, Identifiable {
    case qd = "QD", bid = "BID", tid = "TID", qid = "QID", prn = "PRN"
    var id: String { rawValue }

    var dosesPerDay: Double {
        switch self {
        case .qd:  return 1
        case .bid: return 2
        case .tid: return 3
        case .qid: return 4
        case .prn: return 0   // expected only if you supply a PRN target
        }
    }
}
