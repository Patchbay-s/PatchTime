import Foundation

enum ContractType: String, CaseIterable, Identifiable {
    case cdi = "cdi"
    case cdd = "cdd"
    case cddu = "cddu"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cdi: return "CDI"
        case .cdd: return "CDD"
        case .cddu: return "CDDU (contrat d'usage)"
        }
    }
}

extension Contract {
    /// Bridge type-safe au-dessus de l'attribut `type: String?` brut, avec repli sur `.cdi`
    /// si la valeur est absente ou inconnue (ex: donnée corrompue) — jamais de crash sur
    /// une valeur inattendue, cohérent avec le reste de l'app qui ne bloque jamais l'affichage
    /// pour une valeur de statut manquante.
    var contractType: ContractType {
        get { type.flatMap(ContractType.init(rawValue:)) ?? .cdi }
        set { type = newValue.rawValue }
    }

    /// Core Data génère `NSNumber?` pour ces attributs (optionnels, `usesScalarValueType="NO"`) ;
    /// même pattern que `OvertimeProfile.tauxBrutValue` (voir `OvertimeProfile+Rate.swift`).
    var weeklyContractHoursValue: Double? {
        get { weeklyContractHours?.doubleValue }
        set { weeklyContractHours = newValue.map { NSNumber(value: $0) } }
    }
    var weeklyContractDaysValue: Double? {
        get { weeklyContractDays?.doubleValue }
        set { weeklyContractDays = newValue.map { NSNumber(value: $0) } }
    }
    var kmDistanceRoundTripValue: Double? {
        get { kmDistanceRoundTrip?.doubleValue }
        set { kmDistanceRoundTrip = newValue.map { NSNumber(value: $0) } }
    }
}
