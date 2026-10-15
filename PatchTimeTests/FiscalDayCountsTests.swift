import Testing
import Foundation
@testable import PatchTime

struct FiscalDayCountsTests {
    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    @Test func workedDaysCountExclutLesEntreesRecup() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let day1 = utcCalendar.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let day2 = utcCalendar.date(from: DateComponents(year: 2026, month: 3, day: 11))!

        let sup = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: day1, startTime: day1, endTime: day1.addingTimeInterval(3600), type: "sup", profileID: nil)
        let recup = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: day2, startTime: day2, endTime: day2.addingTimeInterval(3600), type: "recup", profileID: nil)

        let count = FiscalDayCounts.workedDaysCount(year: 2026, overtimeEntries: [sup, recup], calendar: utcCalendar)

        #expect(count == 1)
    }

    /// `workedDaysCount` ne filtre plus par `archived` en interne (même contrat que
    /// `MajorationDetail.compute`/`StatisticsCalculator`/`TypicalWeekProjectionEstimator`,
    /// déjà corrigés pour la même classe de bug) — le tri actif/traité est à la charge de
    /// l'appelant sur `overtimeEntries` en amont ; ce test documente ce contrat.
    @Test func workedDaysCountCompteLesJoursArchivesSiLAppelantNeLesFiltrePas() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let day1 = utcCalendar.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let day2 = utcCalendar.date(from: DateComponents(year: 2026, month: 3, day: 11))!

        let sup = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: day1, startTime: day1, endTime: day1.addingTimeInterval(3600), type: "sup", profileID: nil)
        let archivedSup = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: day2, startTime: day2, endTime: day2.addingTimeInterval(3600), type: "sup", profileID: nil, archived: true)

        let count = FiscalDayCounts.workedDaysCount(year: 2026, overtimeEntries: [sup, archivedSup], calendar: utcCalendar)

        #expect(count == 2)
    }

    @Test func workedDaysCountDedupliqueLesJoursMemeAvecPlusieursEmployeurs() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let day = utcCalendar.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let employerA = UUID()
        let employerB = UUID()

        let entryA = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: day, startTime: day, endTime: day.addingTimeInterval(3600), type: "sup", profileID: nil)
        entryA.employerID = employerA
        let entryB = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: day, startTime: day, endTime: day.addingTimeInterval(3600), type: "sup", profileID: nil)
        entryB.employerID = employerB

        let count = FiscalDayCounts.workedDaysCount(year: 2026, overtimeEntries: [entryA, entryB], calendar: utcCalendar)

        #expect(count == 1) // un seul jour civil, même si 2 employeurs différents
    }

    @Test func leaveDaysCountCompteLesJoursDistinctsParType() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()

        let cpStart = utcCalendar.date(from: DateComponents(year: 2026, month: 7, day: 1))!
        let cpEnd = utcCalendar.date(from: DateComponents(year: 2026, month: 7, day: 5))! // 5 jours inclus
        let cp = LeaveEntry(context: context)
        cp.id = UUID()
        cp.date = cpStart
        cp.endDate = cpEnd
        cp.leaveType = .congePaye

        let recupDay = utcCalendar.date(from: DateComponents(year: 2026, month: 8, day: 10))!
        let recup = LeaveEntry(context: context)
        recup.id = UUID()
        recup.date = recupDay
        recup.leaveType = .recuperation

        let cpCount = FiscalDayCounts.leaveDaysCount(year: 2026, leaveEntries: [cp, recup], type: .congePaye, calendar: utcCalendar)
        let recupCount = FiscalDayCounts.leaveDaysCount(year: 2026, leaveEntries: [cp, recup], type: .recuperation, calendar: utcCalendar)

        #expect(cpCount == 5)
        #expect(recupCount == 1)
    }

    @Test func leaveDaysCountExcluLesJoursHorsAnnee() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let outOfYear = utcCalendar.date(from: DateComponents(year: 2025, month: 12, day: 31))!
        let entry = LeaveEntry(context: context)
        entry.id = UUID()
        entry.date = outOfYear
        entry.leaveType = .congePaye

        let count = FiscalDayCounts.leaveDaysCount(year: 2026, leaveEntries: [entry], type: .congePaye, calendar: utcCalendar)

        #expect(count == 0)
    }

    @Test func leaveDaysCountExcluUnJourHorsPatternQuandUnEmployeurAUneSemaineTypeActive() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()

        let employer = Employer(context: context)
        employer.id = UUID()
        employer.typicalWeekEnabled = true
        employer.setTypicalWeekDay(.monday, isWorked: true, hours: 7.0)
        // Mardi non marqué travaillé.

        // 5 janvier 2026 = lundi (pattern), 6 janvier 2026 = mardi (hors pattern).
        let cp = LeaveEntry(context: context)
        cp.id = UUID()
        cp.date = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 5))!
        cp.endDate = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 6))!
        cp.leaveType = .congePaye

        let count = FiscalDayCounts.leaveDaysCount(year: 2026, leaveEntries: [cp], type: .congePaye, employers: [employer], calendar: utcCalendar)

        #expect(count == 1) // seul le lundi compte, le mardi est hors pattern
    }

    @Test func leaveDaysCountSansSemaineTypeActiveNAppliqueAucuneRestriction() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()

        let employer = Employer(context: context)
        employer.id = UUID()
        employer.typicalWeekEnabled = false

        let cp = LeaveEntry(context: context)
        cp.id = UUID()
        cp.date = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 6))! // mardi
        cp.leaveType = .congePaye

        let count = FiscalDayCounts.leaveDaysCount(year: 2026, leaveEntries: [cp], type: .congePaye, employers: [employer], calendar: utcCalendar)

        #expect(count == 1) // aucune Semaine type active -> aucune restriction
    }
}
