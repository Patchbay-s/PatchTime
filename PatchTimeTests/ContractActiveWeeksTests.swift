import Testing
import Foundation
@testable import PatchTime

struct ContractActiveWeeksTests {
    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    @Test func contratActifTouteLAnneeDonneEnviron52Semaines() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let contract = Contract(context: context)
        contract.id = UUID()
        contract.startDate = utcCalendar.date(from: DateComponents(year: 2020, month: 1, day: 1))!
        // Pas de endDate : contrat toujours actif.

        let weeks = contract.activeWeeksCount(in: 2026, calendar: utcCalendar)

        #expect(abs(weeks - 365.0 / 7.0) < 0.1) // ~52.14 semaines (2026 n'est pas bissextile)
    }

    @Test func contratDemarreEnCoursDAnneeEstProratise() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let contract = Contract(context: context)
        contract.id = UUID()
        contract.startDate = utcCalendar.date(from: DateComponents(year: 2026, month: 7, day: 1))! // 1er juillet

        let weeks = contract.activeWeeksCount(in: 2026, calendar: utcCalendar)

        // Du 1er juillet au 31 décembre 2026 inclus : 184 jours -> ~26.3 semaines.
        #expect(weeks > 25.0 && weeks < 27.0)
    }

    @Test func contratTermineAvantLAnneeDonneZero() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let contract = Contract(context: context)
        contract.id = UUID()
        contract.startDate = utcCalendar.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        contract.endDate = utcCalendar.date(from: DateComponents(year: 2025, month: 6, day: 30))!

        let weeks = contract.activeWeeksCount(in: 2026, calendar: utcCalendar)

        #expect(weeks == 0)
    }

    @Test func contratSansDateDeDebutDonneZero() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let contract = Contract(context: context)
        contract.id = UUID()

        let weeks = contract.activeWeeksCount(in: 2026, calendar: utcCalendar)

        #expect(weeks == 0)
    }

    @Test func coversDateDansLaPeriodeSansEndDate() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let contract = Contract(context: context)
        contract.id = UUID()
        contract.startDate = utcCalendar.date(from: DateComponents(year: 2026, month: 3, day: 1))!

        let before = utcCalendar.date(from: DateComponents(year: 2026, month: 2, day: 28))!
        let onStart = utcCalendar.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        let farAfter = utcCalendar.date(from: DateComponents(year: 2027, month: 1, day: 1))!

        #expect(contract.covers(date: before, calendar: utcCalendar) == false)
        #expect(contract.covers(date: onStart, calendar: utcCalendar) == true)
        #expect(contract.covers(date: farAfter, calendar: utcCalendar) == true) // pas de fin
    }

    @Test func coversDateRespecteLaDateDeFin() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let contract = Contract(context: context)
        contract.id = UUID()
        contract.startDate = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        contract.endDate = utcCalendar.date(from: DateComponents(year: 2026, month: 6, day: 30))!

        let withinPeriod = utcCalendar.date(from: DateComponents(year: 2026, month: 3, day: 15))!
        let onEndDate = utcCalendar.date(from: DateComponents(year: 2026, month: 6, day: 30))!
        let afterEndDate = utcCalendar.date(from: DateComponents(year: 2026, month: 7, day: 1))!

        #expect(contract.covers(date: withinPeriod, calendar: utcCalendar) == true)
        #expect(contract.covers(date: onEndDate, calendar: utcCalendar) == true)
        #expect(contract.covers(date: afterEndDate, calendar: utcCalendar) == false)
    }

    @Test func coversDateSansDateDeDebutRetourneFaux() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let contract = Contract(context: context)
        contract.id = UUID()

        let anyDate = utcCalendar.date(from: DateComponents(year: 2026, month: 3, day: 15))!

        #expect(contract.covers(date: anyDate, calendar: utcCalendar) == false)
    }

    @Test func excludedByLeaveCompteUnJourDeCongeSurUnJourDuPattern() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()

        let employer = Employer(context: context)
        employer.id = UUID()
        employer.typicalWeekEnabled = true
        employer.setTypicalWeekDay(.monday, isWorked: true, hours: 7.0)

        let contract = Contract(context: context)
        contract.id = UUID()
        contract.employer = employer
        contract.startDate = utcCalendar.date(from: DateComponents(year: 2020, month: 1, day: 1))!

        // 5 janvier 2026 = lundi (jour du pattern).
        let monday = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 5))!
        let leave = LeaveEntry(context: context)
        leave.id = UUID()
        leave.date = monday
        leave.leaveType = .congePaye

        let excluded = contract.typicalWeekDaysExcludedByLeave(in: 2026, leaveEntries: [leave], calendar: utcCalendar)

        #expect(excluded == 1)
    }

    @Test func excludedByLeaveIgnoreUnCongeUnJourHorsPattern() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()

        let employer = Employer(context: context)
        employer.id = UUID()
        employer.typicalWeekEnabled = true
        employer.setTypicalWeekDay(.monday, isWorked: true, hours: 7.0)
        // Samedi non marqué travaillé.

        let contract = Contract(context: context)
        contract.id = UUID()
        contract.employer = employer
        contract.startDate = utcCalendar.date(from: DateComponents(year: 2020, month: 1, day: 1))!

        // 10 janvier 2026 = samedi (hors pattern).
        let saturday = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 10))!
        let leave = LeaveEntry(context: context)
        leave.id = UUID()
        leave.date = saturday
        leave.leaveType = .recuperation

        let excluded = contract.typicalWeekDaysExcludedByLeave(in: 2026, leaveEntries: [leave], calendar: utcCalendar)

        #expect(excluded == 0)
    }

    @Test func excludedByLeaveCompteChaqueJourDUnCongeMultiJours() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()

        let employer = Employer(context: context)
        employer.id = UUID()
        employer.typicalWeekEnabled = true
        employer.setTypicalWeekDay(.monday, isWorked: true, hours: 7.0)
        employer.setTypicalWeekDay(.tuesday, isWorked: true, hours: 7.0)

        let contract = Contract(context: context)
        contract.id = UUID()
        contract.employer = employer
        contract.startDate = utcCalendar.date(from: DateComponents(year: 2020, month: 1, day: 1))!

        // 5-6 janvier 2026 = lundi + mardi, tous deux dans le pattern.
        let leave = LeaveEntry(context: context)
        leave.id = UUID()
        leave.date = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 5))!
        leave.endDate = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 6))!
        leave.leaveType = .congePaye

        let excluded = contract.typicalWeekDaysExcludedByLeave(in: 2026, leaveEntries: [leave], calendar: utcCalendar)

        #expect(excluded == 2)
    }
}
