import Testing
import Foundation
@testable import PatchTime

struct MealEntryEmployerIDFieldTests {
    @Test func employerIDEstOptionnelEtPersistant() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let meal = MealEntry(context: context)
        meal.id = UUID()
        meal.date = Date()
        let employerID = UUID()
        meal.employerID = employerID

        try context.save()

        #expect(meal.employerID == employerID)
    }

    @Test func employerIDEstNilParDefaut() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let meal = MealEntry(context: context)
        meal.id = UUID()
        meal.date = Date()

        #expect(meal.employerID == nil)
    }
}
