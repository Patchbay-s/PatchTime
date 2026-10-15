import Testing
import Foundation
@testable import PatchTime

struct OvertimeSurchargeTests {
    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    @Test func sansDateOuSansProfilRetourneUnMultiplicateurDeUn() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Studio Zenith")
        profile.weekendSurchargePercentValue = 0.25

        #expect(OvertimeSurcharge.multiplier(date: nil, profile: profile, holidays: [], calendar: utcCalendar) == 1.0)
        #expect(OvertimeSurcharge.multiplier(date: Date(), profile: nil, holidays: [], calendar: utcCalendar) == 1.0)
    }

    @Test func joursOuvresSansFerieRetourneUn() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Studio Zenith")
        profile.weekendSurchargePercentValue = 0.25
        profile.holidaySurchargePercentValue = 0.5

        let monday = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 5))! // lundi, pas férié
        #expect(OvertimeSurcharge.multiplier(date: monday, profile: profile, holidays: [], calendar: utcCalendar) == 1.0)
    }

    @Test func weekendSeulAppliqueLaMajorationWeekend() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Studio Zenith")
        profile.weekendSurchargePercentValue = 0.25
        profile.holidaySurchargePercentValue = 0.5

        let saturday = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 3))!
        #expect(OvertimeSurcharge.multiplier(date: saturday, profile: profile, holidays: [], calendar: utcCalendar) == 1.25)
    }

    @Test func ferieSeulAppliqueLaMajorationFerie() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Studio Zenith")
        profile.weekendSurchargePercentValue = 0.25
        profile.holidaySurchargePercentValue = 0.5

        let jourDeLAn = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 1))! // jeudi
        let holiday = PublicHoliday(context: context)
        holiday.id = UUID()
        holiday.date = jourDeLAn
        holiday.label = "1er janvier"

        #expect(OvertimeSurcharge.multiplier(date: jourDeLAn, profile: profile, holidays: [holiday], calendar: utcCalendar) == 1.5)
    }

    @Test func weekendEtFerieSeCumulentParAddition() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Studio Zenith")
        profile.weekendSurchargePercentValue = 0.25
        profile.holidaySurchargePercentValue = 0.5

        // 1er novembre 2026 est un dimanche.
        let ferieEtWeekend = utcCalendar.date(from: DateComponents(year: 2026, month: 11, day: 1))!
        let holiday = PublicHoliday(context: context)
        holiday.id = UUID()
        holiday.date = ferieEtWeekend
        holiday.label = "Toussaint"

        #expect(OvertimeSurcharge.multiplier(date: ferieEtWeekend, profile: profile, holidays: [holiday], calendar: utcCalendar) == 1.75)
    }

    @Test func pourcentageNonRenseigneNeContribuePasAuMultiplicateur() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Studio Zenith")
        // Aucun des deux champs renseigné (nil par défaut).

        let saturday = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 3))!
        #expect(OvertimeSurcharge.multiplier(date: saturday, profile: profile, holidays: [], calendar: utcCalendar) == 1.0)
    }
}
