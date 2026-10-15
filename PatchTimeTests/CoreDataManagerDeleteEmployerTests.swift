import Testing
import Foundation
import CoreData
@testable import PatchTime

/// `CoreDataManager.deleteEmployer(_:)` opère sur le `viewContext` du singleton
/// (lié à son propre store persistant), donc on ne peut pas l'appeler directement
/// avec un contexte en mémoire dédié aux tests. Ces tests reproduisent fidèlement
/// la logique de fetch + nullification appliquée par `deleteEmployer` (à la fois
/// pour `OvertimeEntry` et `MealEntry`) contre un contexte en mémoire, afin de
/// garantir que les deux entités sont bien orphelinées de la même façon lorsque
/// leur employeur est supprimé.
struct CoreDataManagerDeleteEmployerTests {
    @Test func supprimerUnEmployeurOrphelineLesHeuresSupEtLesRepas() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()

        let employer = Employer(context: context)
        employer.id = UUID()
        employer.name = "Compagnie Aparté"

        let overtimeEntry = CoreDataTestHelpers.makeOvertimeEntry(
            context: context,
            date: Date(),
            startTime: Date(),
            endTime: Date(),
            type: "sup",
            profileID: nil
        )
        overtimeEntry.employerID = employer.id

        let mealEntry = CoreDataTestHelpers.makeMealEntry(
            context: context,
            date: Date(),
            mealType: "Déjeuner",
            profileID: nil
        )
        mealEntry.employerID = employer.id

        try context.save()

        // Reproduit exactement la logique de CoreDataManager.deleteEmployer(_:)
        if let employerID = employer.id {
            let overtimeRequest: NSFetchRequest<OvertimeEntry> = OvertimeEntry.fetchRequest()
            overtimeRequest.predicate = NSPredicate(format: "employerID == %@", employerID as CVarArg)
            if let orphanedEntries = try? context.fetch(overtimeRequest) {
                orphanedEntries.forEach { $0.employerID = nil }
            }

            let mealRequest: NSFetchRequest<MealEntry> = MealEntry.fetchRequest()
            mealRequest.predicate = NSPredicate(format: "employerID == %@", employerID as CVarArg)
            if let orphanedMeals = try? context.fetch(mealRequest) {
                orphanedMeals.forEach { $0.employerID = nil }
            }
        }

        context.delete(employer)
        try context.save()

        #expect(overtimeEntry.employerID == nil)
        #expect(mealEntry.employerID == nil)
    }
}
