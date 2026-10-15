import Testing
import Foundation
@testable import PatchTime

struct HolidayAPIParsingTests {
    @Test func parseUneReponseAPIValide() async throws {
        let json = [
            "2026-01-01": "1er janvier",
            "2026-05-01": "1er mai",
            "2026-12-25": "Jour de Noël"
        ]

        let parsed = HolidayManager.parseAPIResponse(json)

        #expect(parsed.count == 3)
        let calendar = Calendar(identifier: .gregorian)
        let jourDeLAn = parsed.first { $0.label == "1er janvier" }
        #expect(jourDeLAn != nil)
        if let date = jourDeLAn?.date {
            #expect(calendar.component(.year, from: date) == 2026)
            #expect(calendar.component(.month, from: date) == 1)
            #expect(calendar.component(.day, from: date) == 1)
        }
    }

    @Test func ignoreLesClesDeDateMalFormees() async throws {
        let json = ["pas-une-date": "Libellé invalide", "2026-05-01": "1er mai"]

        let parsed = HolidayManager.parseAPIResponse(json)

        #expect(parsed.count == 1)
        #expect(parsed.first?.label == "1er mai")
    }

    @Test func reponseVideDonneUneListeVide() async throws {
        #expect(HolidayManager.parseAPIResponse([:]).isEmpty)
    }
}
