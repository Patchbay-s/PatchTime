import Foundation

/// Logique pure (testable indépendamment de Core Data/CoreDataManager) de la migration
/// one-shot `hourlyRate -> tauxBrut`. `CoreDataManager.migrateHourlyRateToTauxBrut()` s'occupe
/// du fetch/save et reste privé, comme `migrateBackfillEmployerIDs` — seule cette partie pure
/// est exposée pour être testée.
enum ProfileRateMigration {
    /// Profils dont le taux brut doit être renseigné depuis l'ancien `hourlyRate` (valeur
    /// unique historique, remplacée par les 3 champs liés brut/net/%).
    static func profilesNeedingBackfill(_ profiles: [OvertimeProfile]) -> [OvertimeProfile] {
        profiles.filter { $0.tauxBrut == nil && $0.hourlyRate > 0 }
    }
}
