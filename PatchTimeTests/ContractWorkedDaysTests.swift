import Testing
import Foundation
@testable import PatchTime

struct ContractWorkedDaysTests {
    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    @Test func compteLesJoursDistinctsAvecAuMoinsUneEntreeSup() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let employer = Employer(context: context)
        employer.id = UUID()
        employer.name = "Compagnie Aparté"

        let contract = Contract(context: context)
        contract.id = UUID()
        contract.employer = employer
        contract.startDate = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        contract.endDate = nil

        let day1 = utcCalendar.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let day1Later = day1.addingTimeInterval(3600 * 8) // même jour, 2e entrée
        let day2 = utcCalendar.date(from: DateComponents(year: 2026, month: 3, day: 11))!

        let entry1 = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: day1, startTime: day1, endTime: day1.addingTimeInterval(3600 * 2), type: "sup", profileID: nil)
        entry1.employerID = employer.id
        let entry2 = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: day1Later, startTime: day1Later, endTime: day1Later.addingTimeInterval(3600), type: "sup", profileID: nil)
        entry2.employerID = employer.id
        let entry3 = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: day2, startTime: day2, endTime: day2.addingTimeInterval(3600), type: "sup", profileID: nil)
        entry3.employerID = employer.id

        let count = contract.workedDaysCount(in: 2026, overtimeEntries: [entry1, entry2, entry3], calendar: utcCalendar)

        #expect(count == 2) // day1 (2 entrées, comptées une fois) + day2
    }

    @Test func ignoreLesEntreesRecup() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let employer = Employer(context: context)
        employer.id = UUID()
        employer.name = "Compagnie Aparté"

        let contract = Contract(context: context)
        contract.id = UUID()
        contract.employer = employer
        contract.startDate = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!

        let day = utcCalendar.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let recup = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: day, startTime: day, endTime: day.addingTimeInterval(3600), type: "recup", profileID: nil)
        recup.employerID = employer.id

        let count = contract.workedDaysCount(in: 2026, overtimeEntries: [recup], calendar: utcCalendar)

        #expect(count == 0)
    }

    /// `workedDaysCount` ne filtre plus par `archived` en interne (même contrat que
    /// `FiscalDayCounts.workedDaysCount`/`MajorationDetail.compute`, déjà corrigés pour la même
    /// classe de bug) — le tri actif/traité est à la charge de l'appelant sur `overtimeEntries`
    /// en amont ; ce test documente ce contrat.
    @Test func compteLesEntreesArchiveesSiLAppelantNeLesFiltrePas() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let employer = Employer(context: context)
        employer.id = UUID()
        employer.name = "Compagnie Aparté"

        let contract = Contract(context: context)
        contract.id = UUID()
        contract.employer = employer
        contract.startDate = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!

        let day = utcCalendar.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let archived = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: day, startTime: day, endTime: day.addingTimeInterval(3600), type: "sup", profileID: nil, archived: true)
        archived.employerID = employer.id

        let count = contract.workedDaysCount(in: 2026, overtimeEntries: [archived], calendar: utcCalendar)

        #expect(count == 1)
    }

    @Test func ignoreLesEntreesDunAutreEmployeurOuHorsPeriodeDuContrat() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let employer = Employer(context: context)
        employer.id = UUID()
        employer.name = "Compagnie Aparté"
        let otherEmployer = Employer(context: context)
        otherEmployer.id = UUID()
        otherEmployer.name = "Autre Compagnie"

        let contract = Contract(context: context)
        contract.id = UUID()
        contract.employer = employer
        contract.startDate = utcCalendar.date(from: DateComponents(year: 2026, month: 6, day: 1))!
        contract.endDate = utcCalendar.date(from: DateComponents(year: 2026, month: 6, day: 30))!

        let inRange = utcCalendar.date(from: DateComponents(year: 2026, month: 6, day: 15))!
        let beforeContract = utcCalendar.date(from: DateComponents(year: 2026, month: 5, day: 15))!
        let afterContract = utcCalendar.date(from: DateComponents(year: 2026, month: 7, day: 15))!

        let matching = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: inRange, startTime: inRange, endTime: inRange.addingTimeInterval(3600), type: "sup", profileID: nil)
        matching.employerID = employer.id
        let wrongEmployer = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: inRange.addingTimeInterval(3600 * 24), startTime: inRange, endTime: inRange.addingTimeInterval(3600), type: "sup", profileID: nil)
        wrongEmployer.employerID = otherEmployer.id
        let tooEarly = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: beforeContract, startTime: beforeContract, endTime: beforeContract.addingTimeInterval(3600), type: "sup", profileID: nil)
        tooEarly.employerID = employer.id
        let tooLate = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: afterContract, startTime: afterContract, endTime: afterContract.addingTimeInterval(3600), type: "sup", profileID: nil)
        tooLate.employerID = employer.id

        let count = contract.workedDaysCount(in: 2026, overtimeEntries: [matching, wrongEmployer, tooEarly, tooLate], calendar: utcCalendar)

        #expect(count == 1)
    }

    @Test func sansEmployeurNeCompteAucunJour() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let contract = Contract(context: context)
        contract.id = UUID()
        contract.startDate = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!

        let day = utcCalendar.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let entry = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: day, startTime: day, endTime: day.addingTimeInterval(3600), type: "sup", profileID: nil)

        let count = contract.workedDaysCount(in: 2026, overtimeEntries: [entry], calendar: utcCalendar)

        #expect(count == 0)
    }
}
