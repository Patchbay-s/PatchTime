import Foundation

/// Revenu net imposable saisi manuellement par année, pour le comparatif frais réels vs
/// abattement forfaitaire (design doc V5, chantier 7). Clé par année plutôt que `@AppStorage`
/// statique car l'année consultée change dynamiquement dans l'écran Bilan fiscal.
enum FiscalIncomeStore {
    private static func key(forYear year: Int) -> String { "fiscalIncome_\(year)" }

    static func value(forYear year: Int) -> Double? {
        let stored = UserDefaults.standard.double(forKey: key(forYear: year))
        return stored == 0 ? nil : stored
    }

    static func setValue(_ value: Double?, forYear year: Int) {
        if let value {
            UserDefaults.standard.set(value, forKey: key(forYear: year))
        } else {
            UserDefaults.standard.removeObject(forKey: key(forYear: year))
        }
    }
}
