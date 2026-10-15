import Foundation

/// Logique pure (testable indépendamment de Core Data/CoreDataManager) de la migration
/// one-shot du 3ème champ de taux (`tauxPourcentage`) : il est passé de la sémantique
/// "ratio net/brut" à "taux de prélèvement" (voir `TauxCalculator.computed`). Toute valeur déjà
/// stockée doit être inversée : nouvelleValeur = 1 - ancienneValeur (fraction 0-1).
/// `CoreDataManager.migratePourcentageNetBrutToPrelevement()` s'occupe du fetch/save et reste
/// privé, comme les autres migrations — seule cette partie pure est exposée pour être testée.
enum PourcentageSemanticsMigration {
    /// Profils dont le `tauxPourcentage` stocké doit être inversé (ancienne sémantique
    /// net/brut -> nouvelle sémantique taux de prélèvement).
    static func profilesNeedingConversion(_ profiles: [OvertimeProfile]) -> [OvertimeProfile] {
        profiles.filter { $0.tauxPourcentageValue != nil }
    }

    /// Inverse une valeur stockée sous l'ancienne sémantique (ratio net/brut) pour obtenir la
    /// nouvelle (taux de prélèvement). Cette conversion est sa propre inverse : ne jamais
    /// l'appliquer deux fois à la même donnée.
    static func convertedValue(from oldValue: Double) -> Double {
        1 - oldValue
    }
}
