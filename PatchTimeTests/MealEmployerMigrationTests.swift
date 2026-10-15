import Testing
import Foundation
@testable import PatchTime

struct MealEmployerMigrationTests {

    @Test func employerIDsByProfileIDIgnoreLesProfilsSansEmployeur() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let employer = Employer(context: context)
        employer.id = UUID()
        employer.name = "Compagnie Aparté"

        let profileAvecEmployeur = CoreDataTestHelpers.makeProfile(context: context, name: "A")
        profileAvecEmployeur.employer = employer
        let profileSansEmployeur = CoreDataTestHelpers.makeProfile(context: context, name: "B")

        let map = MealEmployerMigration.employerIDsByProfileID([profileAvecEmployeur, profileSansEmployeur])

        #expect(map.count == 1)
        #expect(map[profileAvecEmployeur.id!] == employer.id)
        #expect(map[profileSansEmployeur.id!] == nil)
    }

    @Test func mealsNeedingBackfillSelectionneUniquementCeuxAvecProfileIDConnuEtSansEmployerID() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let employerID = UUID()
        let profileID = UUID()
        let map = [profileID: employerID]

        let mealAMigrer = CoreDataTestHelpers.makeMealEntry(context: context, date: Date(), mealType: "Déjeuner", profileID: profileID)
        let mealDejaMigre = CoreDataTestHelpers.makeMealEntry(context: context, date: Date(), mealType: "Déjeuner", profileID: profileID)
        mealDejaMigre.employerID = UUID()
        let mealSansProfil = CoreDataTestHelpers.makeMealEntry(context: context, date: Date(), mealType: "Déjeuner", profileID: nil)
        let mealProfilInconnu = CoreDataTestHelpers.makeMealEntry(context: context, date: Date(), mealType: "Déjeuner", profileID: UUID())

        let toMigrate = MealEmployerMigration.mealsNeedingBackfill(
            [mealAMigrer, mealDejaMigre, mealSansProfil, mealProfilInconnu],
            employerIDByProfileID: map
        )

        #expect(toMigrate.count == 1)
        #expect(toMigrate.first?.meal.id == mealAMigrer.id)
        #expect(toMigrate.first?.employerID == employerID)
    }
}
