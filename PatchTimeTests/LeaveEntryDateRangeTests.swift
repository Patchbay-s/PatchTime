import Testing
import Foundation
@testable import PatchTime

struct LeaveEntryDateRangeTests {
    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    /// Fixture ancrée tôt dans la journée (00:30 UTC, plutôt que le 22:13 UTC initialement
    /// utilisé) : un décalage de +5h reste garanti dans le même jour civil UTC, quel que soit
    /// le fuseau horaire de la machine qui exécute les tests — `coversDate` par défaut utilise
    /// `Calendar.current`, qui vaut UTC dans cet environnement de test, où le fuseau +22:13+5h
    /// franchissait minuit et rendait le fixture "même jour" faux par construction.
    @Test func journeeUniqueSansEndDate() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let leave = LeaveEntry(context: context)
        leave.id = UUID()
        leave.date = utcCalendar.date(from: DateComponents(year: 2023, month: 11, day: 14, hour: 0, minute: 30))!
        leave.endDate = nil

        let sameDayLater = leave.date!.addingTimeInterval(3600 * 5)
        let nextDay = leave.date!.addingTimeInterval(3600 * 30)

        #expect(leave.coversDate(leave.date!, calendar: utcCalendar))
        #expect(leave.coversDate(sameDayLater, calendar: utcCalendar))
        #expect(!leave.coversDate(nextDay, calendar: utcCalendar))
    }

    @Test func plageMultiJoursInclusive() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let leave = LeaveEntry(context: context)
        leave.id = UUID()
        leave.date = utcCalendar.date(from: DateComponents(year: 2023, month: 11, day: 14, hour: 0, minute: 30))!
        leave.endDate = leave.date!.addingTimeInterval(3600 * 24 * 3) // 3 jours plus tard

        #expect(leave.coversDate(leave.date!, calendar: utcCalendar))
        #expect(leave.coversDate(leave.date!.addingTimeInterval(3600 * 24), calendar: utcCalendar))
        #expect(leave.coversDate(leave.endDate!, calendar: utcCalendar))
        #expect(!leave.coversDate(leave.date!.addingTimeInterval(-3600 * 24), calendar: utcCalendar))
        #expect(!leave.coversDate(leave.endDate!.addingTimeInterval(3600 * 24), calendar: utcCalendar))
    }

    @Test func sansDateDeDebutNeCouvreAucunJour() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let leave = LeaveEntry(context: context)
        leave.id = UUID()
        leave.date = nil

        #expect(!leave.coversDate(Date()))
    }
}
