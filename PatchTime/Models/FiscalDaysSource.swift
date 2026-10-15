import Foundation

/// Source des jours travaillés utilisée par le Bilan fiscal pour estimer frais km/repas — un
/// choix explicite par utilisateur et par année, jamais une bascule automatique :
/// `.actualEntries` (comportement historique, `FiscalDayCounts`/`KmExpenseEstimator`/
/// `MealExpenseEstimator`) et `.typicalWeek` (`TypicalWeekExpenseEstimator`) restent deux
/// chemins de calcul entièrement séparés. `.combined` applique la même règle de priorité que
/// partout ailleurs dans l'app (entrée réelle prime, Semaine type comble les jours non
/// couverts, pas de double-comptage) plutôt que de forcer un choix exclusif entre les deux.
enum FiscalDaysSource: String, CaseIterable, Identifiable {
    case actualEntries
    case typicalWeek
    case combined

    var id: String { rawValue }

    var label: String {
        switch self {
        case .actualEntries: return "Heures saisies"
        case .typicalWeek: return "Semaine type"
        case .combined: return "Combiner les 2"
        }
    }
}

/// Persistance du choix par année, même pattern que `FiscalIncomeStore`.
enum FiscalDaysSourceStore {
    private static func key(forYear year: Int) -> String { "fiscalDaysSource_\(year)" }

    static func value(forYear year: Int) -> FiscalDaysSource {
        guard let raw = UserDefaults.standard.string(forKey: key(forYear: year)),
              let source = FiscalDaysSource(rawValue: raw) else {
            return .actualEntries
        }
        return source
    }

    static func setValue(_ source: FiscalDaysSource, forYear year: Int) {
        UserDefaults.standard.set(source.rawValue, forKey: key(forYear: year))
    }
}
