import Testing
import Foundation
@testable import PatchTime

struct CombinedDaysEstimatorTests {
    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    // 5 janvier 2026 = lundi, 10 janvier 2026 = samedi.
    private var monday: Date { utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 5))! }
    private var saturday: Date { utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 10))! }

    @Test func entreeReelleSurJourDuPatternNAjouteQueLeGabarit() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()

        let employer = Employer(context: context)
        employer.id = UUID()
        employer.kmDistanceRoundTripValue = 20.0
        employer.typicalWeekEnabled = true
        employer.setTypicalWeekDay(.monday, isWorked: true, hours: 7.0)

        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Taux A", tauxBrut: 20.0)
        profile.employer = employer

        let contract = Contract(context: context)
        contract.id = UUID()
        contract.employer = employer
        contract.startDate = utcCalendar.date(from: DateComponents(year: 2020, month: 1, day: 1))!

        let entry = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: monday, startTime: monday, endTime: monday.addingTimeInterval(2 * 3600), type: "sup", profileID: profile.id)

        let result = CombinedDaysEstimator.estimate(
            year: 2026, overtimeEntries: [entry], profiles: [profile], contracts: [contract], leaveEntries: [], calendar: utcCalendar
        )

        // 52 jours de gabarit, l'entrée réelle du lundi ne s'ajoute pas (déjà comptée).
        #expect(result.workedDaysCount == 52)
        #expect(abs(result.totalKm - 52.0 * 20.0) < 0.01)
    }

    @Test func entreeReelleHorsPatternAjouteUnJourEtSaDistance() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()

        let employer = Employer(context: context)
        employer.id = UUID()
        employer.kmDistanceRoundTripValue = 20.0
        employer.typicalWeekEnabled = true
        employer.setTypicalWeekDay(.monday, isWorked: true, hours: 7.0)

        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Taux A", tauxBrut: 20.0)
        profile.employer = employer

        let contract = Contract(context: context)
        contract.id = UUID()
        contract.employer = employer
        contract.startDate = utcCalendar.date(from: DateComponents(year: 2020, month: 1, day: 1))!

        let entry = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: saturday, startTime: saturday, endTime: saturday.addingTimeInterval(2 * 3600), type: "sup", profileID: profile.id)

        let result = CombinedDaysEstimator.estimate(
            year: 2026, overtimeEntries: [entry], profiles: [profile], contracts: [contract], leaveEntries: [], calendar: utcCalendar
        )

        #expect(result.workedDaysCount == 53) // 52 gabarit + 1 samedi hors pattern
        #expect(abs(result.totalKm - 53.0 * 20.0) < 0.01)
    }

    @Test func entreeSansEmployeurUtiliseLeDedoublonnageSansDistance() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let day = utcCalendar.date(from: DateComponents(year: 2026, month: 3, day: 10))!

        let entry = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: day, startTime: day, endTime: day.addingTimeInterval(2 * 3600), type: "sup", profileID: nil)

        let result = CombinedDaysEstimator.estimate(
            year: 2026, overtimeEntries: [entry], profiles: [], contracts: [], leaveEntries: [], calendar: utcCalendar
        )

        #expect(result.workedDaysCount == 1)
        #expect(result.totalKm == 0)
    }

    @Test func plusieursEmployeursSAdditionnent() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()

        let employerA = Employer(context: context)
        employerA.id = UUID()
        employerA.kmDistanceRoundTripValue = 10.0
        employerA.typicalWeekEnabled = true
        employerA.setTypicalWeekDay(.monday, isWorked: true, hours: 4.0)

        let employerB = Employer(context: context)
        employerB.id = UUID()
        employerB.kmDistanceRoundTripValue = 30.0
        employerB.typicalWeekEnabled = true
        employerB.setTypicalWeekDay(.monday, isWorked: true, hours: 3.0)

        let contractA = Contract(context: context)
        contractA.id = UUID()
        contractA.employer = employerA
        contractA.startDate = utcCalendar.date(from: DateComponents(year: 2020, month: 1, day: 1))!

        let contractB = Contract(context: context)
        contractB.id = UUID()
        contractB.employer = employerB
        contractB.startDate = utcCalendar.date(from: DateComponents(year: 2020, month: 1, day: 1))!

        let result = CombinedDaysEstimator.estimate(
            year: 2026, overtimeEntries: [], profiles: [], contracts: [contractA, contractB], leaveEntries: [], calendar: utcCalendar
        )

        // ~52 jours (A) + ~52 jours (B), additif.
        #expect(result.workedDaysCount >= 104 && result.workedDaysCount <= 106)
    }
}
