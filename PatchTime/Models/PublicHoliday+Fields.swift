import Foundation

/// `rawValue` = code exact attendu par `calendrier.api.gouv.fr/jours-feries/{zone}/{annee}.json`
/// pour la zone française. `.monaco` n'a pas d'équivalent API (aucune source officielle
/// gratuite équivalente) — voir `HolidayManager.seedMonacoIfNeeded()`.
///
/// Volontairement restreint à France métropolitaine + Monaco (retrait des zones DOM-TOM et
/// Alsace-Moselle, hors périmètre de l'app) — voir le bug B3 du prompt "Bugs + Semaine type +
/// Statistiques".
enum HolidayZone: String, CaseIterable, Identifiable {
    case metropole
    case monaco

    var id: String { rawValue }

    var isFetchableFromAPI: Bool { self != .monaco }

    var label: String {
        switch self {
        case .metropole: return "France"
        case .monaco: return "Monaco"
        }
    }
}

enum HolidaySource: String {
    case api
    case seed
    case custom
}

extension PublicHoliday {
    var zone: HolidayZone {
        get { countryZone.flatMap(HolidayZone.init(rawValue:)) ?? .metropole }
        set { countryZone = newValue.rawValue }
    }

    var sourceValue: HolidaySource {
        get { source.flatMap(HolidaySource.init(rawValue:)) ?? .custom }
        set { source = newValue.rawValue }
    }
}
