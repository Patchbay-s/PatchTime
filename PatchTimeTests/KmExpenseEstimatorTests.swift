import Testing
import Foundation
@testable import PatchTime

struct KmExpenseEstimatorTests {
    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    @Test func sommeLaDistanceSurTousLesContratsPuisAppliqueLeBaremeUneSeuleFois() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()

        let employerA = Employer(context: context)
        employerA.id = UUID()
        employerA.name = "Compagnie Aparté"
        let contractA = Contract(context: context)
        contractA.id = UUID()
        contractA.employer = employerA
        contractA.startDate = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        contractA.kmDistanceRoundTripValue = 20.0

        let employerB = Employer(context: context)
        employerB.id = UUID()
        employerB.name = "Studio Zenith"
        let contractB = Contract(context: context)
        contractB.id = UUID()
        contractB.employer = employerB
        contractB.startDate = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        contractB.kmDistanceRoundTripValue = 10.0

        // 2 jours travaillés pour A (20km * 2 = 40km), 1 jour pour B (10km * 1 = 10km) -> 50km total.
        let dayA1 = utcCalendar.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let dayA2 = utcCalendar.date(from: DateComponents(year: 2026, month: 3, day: 11))!
        let dayB1 = utcCalendar.date(from: DateComponents(year: 2026, month: 3, day: 12))!

        let entryA1 = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: dayA1, startTime: dayA1, endTime: dayA1.addingTimeInterval(3600), type: "sup", profileID: nil)
        entryA1.employerID = employerA.id
        let entryA2 = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: dayA2, startTime: dayA2, endTime: dayA2.addingTimeInterval(3600), type: "sup", profileID: nil)
        entryA2.employerID = employerA.id
        let entryB1 = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: dayB1, startTime: dayB1, endTime: dayB1.addingTimeInterval(3600), type: "sup", profileID: nil)
        entryB1.employerID = employerB.id

        let result = KmExpenseEstimator.estimate(
            year: 2026,
            contracts: [contractA, contractB],
            overtimeEntries: [entryA1, entryA2, entryB1],
            fiscalPower: 4,
            isElectric: false,
            calendar: utcCalendar
        )

        #expect(result.totalKm == 50.0)
        #expect(result.deduction == 50.0 * 0.606) // 1re tranche, 4 CV
    }

    @Test func contratSansDistanceEffectiveNContribuePasAuTotal() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let employer = Employer(context: context)
        employer.id = UUID()
        employer.name = "Compagnie Aparté"
        let contract = Contract(context: context)
        contract.id = UUID()
        contract.employer = employer
        contract.startDate = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        // Ni contract.kmDistanceRoundTripValue ni employer.kmDistanceRoundTripValue renseignés.

        let day = utcCalendar.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let entry = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: day, startTime: day, endTime: day.addingTimeInterval(3600), type: "sup", profileID: nil)
        entry.employerID = employer.id

        let result = KmExpenseEstimator.estimate(
            year: 2026, contracts: [contract], overtimeEntries: [entry],
            fiscalPower: 4, isElectric: false, calendar: utcCalendar
        )

        #expect(result.totalKm == 0.0)
        #expect(result.deduction == 0.0)
    }

    @Test func aucunContratDonneUneDeductionNulle() async throws {
        let result = KmExpenseEstimator.estimate(
            year: 2026, contracts: [], overtimeEntries: [],
            fiscalPower: 5, isElectric: false
        )
        #expect(result.totalKm == 0.0)
        #expect(result.deduction == 0.0)
    }
}
