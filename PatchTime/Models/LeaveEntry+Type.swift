import Foundation

enum LeaveType: String, CaseIterable, Identifiable {
    case congePaye = "cp"
    case recuperation = "recuperation"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .congePaye: return "Congé payé"
        case .recuperation: return "Récupération"
        }
    }
}

extension LeaveEntry {
    var leaveType: LeaveType {
        get { type.flatMap(LeaveType.init(rawValue:)) ?? .congePaye }
        set { type = newValue.rawValue }
    }
}
