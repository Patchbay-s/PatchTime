import Testing
import Foundation
@testable import PatchTime

struct PublicHolidayModelTests {
    @Test func creerUnJourFerieOfficielFrancais() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()

        let holiday = PublicHoliday(context: context)
        holiday.id = UUID()
        holiday.date = Date(timeIntervalSince1970: 1_767_225_600) // 2026-01-01
        holiday.label = "1er janvier"
        holiday.countryZone = "metropole"
        holiday.source = "api"
        holiday.isUserEdited = false

        try context.save()

        #expect(holiday.label == "1er janvier")
        #expect(holiday.countryZone == "metropole")
        #expect(holiday.source == "api")
        #expect(holiday.isUserEdited == false)
    }
}
