import Testing
import Foundation
@testable import PatchTime

struct MajorationDetailTests {
    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    @Test func calculeLesHeuresEtLeSurcoutDesEntreesMajorees() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Studio Zenith", tauxBrut: 20.0)
        profile.weekendSurchargePercentValue = 0.25

        let saturday = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 3))!
        let monday = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 5))!

        let majoredEntry = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: saturday, startTime: saturday, endTime: saturday.addingTimeInterval(2 * 3600), type: "sup", profileID: profile.id)
        let normalEntry = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: monday, startTime: monday, endTime: monday.addingTimeInterval(3 * 3600), type: "sup", profileID: profile.id)

        let profileMap = [profile.id!: profile]
        let result = MajorationDetail.compute(year: 2026, overtimeEntries: [majoredEntry, normalEntry], profileMap: profileMap, holidays: [], calendar: utcCalendar)

        #expect(result.hoursCount == 2.0) // seule l'entrée du samedi est majorée
        #expect(abs(result.surcharge - 10.0) < 0.001) // 2h * 20 * (1.25 - 1) = 10
    }

    @Test func ignoreLesEntreesRecup() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Studio Zenith", tauxBrut: 20.0)
        profile.weekendSurchargePercentValue = 0.25

        let saturday = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 3))!
        let recup = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: saturday, startTime: saturday, endTime: saturday.addingTimeInterval(2 * 3600), type: "recup", profileID: profile.id)

        let profileMap = [profile.id!: profile]
        let result = MajorationDetail.compute(year: 2026, overtimeEntries: [recup], profileMap: profileMap, holidays: [], calendar: utcCalendar)

        #expect(result.hoursCount == 0.0)
        #expect(result.surcharge == 0.0)
    }

    /// `compute` ne filtre plus par `archived` en interne (même contrat que
    /// `StatisticsCalculator`/`TypicalWeekProjectionEstimator`/`AnnualReportCalculator`, déjà
    /// corrigés pour la même classe de bug) — le tri actif/traité est à la charge de l'appelant
    /// sur `overtimeEntries` en amont ; ce test documente ce contrat.
    @Test func compteLesEntreesArchiveesSiLAppelantNeLesFiltrePas() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Studio Zenith", tauxBrut: 20.0)
        profile.weekendSurchargePercentValue = 0.25

        let saturday = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 3))!
        let archived = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: saturday, startTime: saturday, endTime: saturday.addingTimeInterval(2 * 3600), type: "sup", profileID: profile.id, archived: true)

        let profileMap = [profile.id!: profile]
        let result = MajorationDetail.compute(year: 2026, overtimeEntries: [archived], profileMap: profileMap, holidays: [], calendar: utcCalendar)

        #expect(result.hoursCount == 2.0)
        #expect(abs(result.surcharge - 10.0) < 0.001)
    }

    @Test func aucuneMajorationDonneUnResultatNul() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Studio Zenith", tauxBrut: 20.0)
        // Aucun pourcentage de majoration renseigné.

        let monday = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 5))!
        let entry = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: monday, startTime: monday, endTime: monday.addingTimeInterval(3 * 3600), type: "sup", profileID: profile.id)

        let profileMap = [profile.id!: profile]
        let result = MajorationDetail.compute(year: 2026, overtimeEntries: [entry], profileMap: profileMap, holidays: [], calendar: utcCalendar)

        #expect(result.hoursCount == 0.0)
        #expect(result.surcharge == 0.0)
    }
}
