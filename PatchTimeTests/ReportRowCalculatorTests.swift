import Testing
import Foundation
@testable import PatchTime

struct ReportRowCalculatorTests {

    @Test func heureSupPositiveAvecTauxBrutEtNet() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Studio Zenith", tauxBrut: 20.0, tauxNet: 15.6)
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
        let profileMap = [profile.id!: profile]

        let row = ReportRowCalculator.makeRow(entry: entry, profileMap: profileMap, holidays: [])

        #expect(row.isRecup == false)
        #expect(row.hours == 2.0)
        #expect(row.earningsBrut == 40.0)
        #expect(row.earningsNet == 31.2)
        #expect(row.earnings == 31.2) // meilleur taux disponible = net en priorité
        #expect(row.isValidated == true)
        #expect(row.profileName == "Studio Zenith")
    }

    @Test func recupHeuresEtGainsNegatifs() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Compagnie Aparté", tauxBrut: 15.0)
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let entry = CoreDataTestHelpers.makeOvertimeEntry(
            context: context,
            date: day,
            startTime: day,
            endTime: day.addingTimeInterval(1.5 * 3600),
            type: "recup",
            profileID: profile.id,
            isValidated: false
        )
        let profileMap = [profile.id!: profile]

        let row = ReportRowCalculator.makeRow(entry: entry, profileMap: profileMap, holidays: [])

        #expect(row.isRecup == true)
        #expect(row.hours == -1.5)
        #expect(row.earningsBrut == -22.5)
        #expect(row.earningsNet == nil) // tauxNet inconnu pour ce profil
        #expect(row.earnings == -22.5)  // repli sur brut, seul connu
        #expect(row.isValidated == false)
    }

    @Test func sansProfilCorrespondantGainsNulsEtNomPlaceholder() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let entry = CoreDataTestHelpers.makeOvertimeEntry(
            context: context,
            date: day,
            startTime: day,
            endTime: day.addingTimeInterval(3600),
            type: "sup",
            profileID: UUID() // ne correspond à aucun profil du profileMap
        )

        let row = ReportRowCalculator.makeRow(entry: entry, profileMap: [:], holidays: [])

        #expect(row.earnings == 0.0)
        #expect(row.earningsBrut == nil)
        #expect(row.earningsNet == nil)
        #expect(row.profileName == "—")
    }

    @Test func bestEffortRatePrivilegieLeNet() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profileBrutSeul = CoreDataTestHelpers.makeProfile(context: context, name: "A", tauxBrut: 20.0)
        let profileNetSeul = CoreDataTestHelpers.makeProfile(context: context, name: "B", tauxNet: 15.6)
        let profileLesDeux = CoreDataTestHelpers.makeProfile(context: context, name: "C", tauxBrut: 20.0, tauxNet: 15.6)
        let profileAucun = CoreDataTestHelpers.makeProfile(context: context, name: "D")

        #expect(ReportRowCalculator.bestEffortRate(for: profileBrutSeul) == 20.0)
        #expect(ReportRowCalculator.bestEffortRate(for: profileNetSeul) == 15.6)
        #expect(ReportRowCalculator.bestEffortRate(for: profileLesDeux) == 15.6)
        #expect(ReportRowCalculator.bestEffortRate(for: profileAucun) == 0.0)
        #expect(ReportRowCalculator.bestEffortRate(for: nil) == 0.0)
    }

    @Test func majorationWeekendAppliqueeAUneEntreeSupUnSamedi() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Studio Zenith", tauxBrut: 20.0, tauxNet: 15.6)
        profile.weekendSurchargePercentValue = 0.25

        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        let saturday = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 3))!

        let entry = CoreDataTestHelpers.makeOvertimeEntry(
            context: context, date: saturday, startTime: saturday, endTime: saturday.addingTimeInterval(2 * 3600),
            type: "sup", profileID: profile.id
        )
        let profileMap = [profile.id!: profile]

        let row = ReportRowCalculator.makeRow(entry: entry, profileMap: profileMap, holidays: [])

        #expect(row.earningsBrut == 50.0)  // 2h * 20 * 1.25
        #expect(row.earningsNet == 39.0)   // 2h * 15.6 * 1.25
    }

    @Test func majorationNAppliqueJamaisSurUneEntreeRecup() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Studio Zenith", tauxBrut: 20.0)
        profile.weekendSurchargePercentValue = 0.25

        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        let saturday = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 3))!

        let entry = CoreDataTestHelpers.makeOvertimeEntry(
            context: context, date: saturday, startTime: saturday, endTime: saturday.addingTimeInterval(2 * 3600),
            type: "recup", profileID: profile.id
        )
        let profileMap = [profile.id!: profile]

        let row = ReportRowCalculator.makeRow(entry: entry, profileMap: profileMap, holidays: [])

        #expect(row.earningsBrut == -40.0)  // -(2h * 20), pas de majoration sur une récup
    }
}
