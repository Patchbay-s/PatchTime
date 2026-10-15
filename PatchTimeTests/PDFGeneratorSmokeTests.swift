import Testing
import Foundation
@testable import PatchTime

struct PDFGeneratorSmokeTests {

    @Test func genereUnPDFValideAvecUneEntreeSupEtUnRepas() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Studio Zenith", hourlyRate: 20.0)
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let entry = CoreDataTestHelpers.makeOvertimeEntry(
            context: context,
            date: day,
            startTime: day,
            endTime: day.addingTimeInterval(2 * 3600),
            type: "sup",
            profileID: profile.id,
            isValidated: true
        )
        let meal = CoreDataTestHelpers.makeMealEntry(
            context: context, date: day, mealType: "Déjeuner", profileID: profile.id
        )

        let data = PDFGenerator.generateMonthlyReport(
            month: day,
            entries: [entry],
            meals: [meal],
            profiles: [profile],
            holidays: [],
            filterProfile: nil,
            currency: "€"
        )

        #expect(data.count > 0)
        let magicBytes = data.prefix(5)
        #expect(magicBytes == Data("%PDF-".utf8))
    }
}
