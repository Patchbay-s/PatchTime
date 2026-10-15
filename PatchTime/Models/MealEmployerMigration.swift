import Foundation

/// Logique pure (testable indépendamment de Core Data/CoreDataManager) de la migration
/// one-shot qui déduit `MealEntry.employerID` de l'ancien lien `profileID -> OvertimeProfile.employer`.
/// Même découpage que `ProfileRateMigration` : `CoreDataManager.migrateBackfillMealEmployerIDs()`
/// reste privé et fait le fetch/save, seule cette partie pure est exposée pour être testée.
enum MealEmployerMigration {
    static func employerIDsByProfileID(_ profiles: [OvertimeProfile]) -> [UUID: UUID] {
        Dictionary(uniqueKeysWithValues: profiles.compactMap { profile in
            guard let profileID = profile.id, let employerID = profile.employer?.id else { return nil }
            return (profileID, employerID)
        })
    }

    static func mealsNeedingBackfill(
        _ meals: [MealEntry],
        employerIDByProfileID: [UUID: UUID]
    ) -> [(meal: MealEntry, employerID: UUID)] {
        meals.compactMap { meal in
            guard meal.employerID == nil, let profileID = meal.profileID, let employerID = employerIDByProfileID[profileID] else { return nil }
            return (meal, employerID)
        }
    }
}
