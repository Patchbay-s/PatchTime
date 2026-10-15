import Testing
import Foundation
@testable import PatchTime

struct EmployerTypicalWeekTests {
    @Test func parDefautAucunJourNEstTravaille() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let employer = Employer(context: context)
        employer.id = UUID()
        employer.name = "Compagnie Aparté"

        #expect(employer.typicalWeekDays.allSatisfy { !$0.isWorked })
        #expect(employer.typicalWeekWorkedDaysCount == 0)
        #expect(employer.typicalWeeklyHoursTotal == 0)
    }

    @Test func setTypicalWeekDayRenseigneLeJourCorrect() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let employer = Employer(context: context)
        employer.id = UUID()
        employer.name = "Compagnie Aparté"

        employer.setTypicalWeekDay(.monday, isWorked: true, hours: 7.5)
        employer.setTypicalWeekDay(.wednesday, isWorked: true, hours: 4.0)

        #expect(employer.isTypicalWeekWorked(.monday) == true)
        #expect(employer.typicalWeekHours(.monday) == 7.5)
        #expect(employer.isTypicalWeekWorked(.tuesday) == false)
        #expect(employer.typicalWeekHours(.tuesday) == nil)
        #expect(employer.isTypicalWeekWorked(.wednesday) == true)
        #expect(employer.typicalWeekHours(.wednesday) == 4.0)

        #expect(employer.typicalWeekWorkedDaysCount == 2)
        #expect(employer.typicalWeeklyHoursTotal == 11.5)
    }

    @Test func marquerUnJourNonTravailleEfaceLesHeuresExistantes() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let employer = Employer(context: context)
        employer.id = UUID()
        employer.name = "Compagnie Aparté"

        employer.setTypicalWeekDay(.friday, isWorked: true, hours: 6.0)
        #expect(employer.typicalWeekHours(.friday) == 6.0)

        employer.setTypicalWeekDay(.friday, isWorked: false, hours: nil)
        #expect(employer.isTypicalWeekWorked(.friday) == false)
        #expect(employer.typicalWeekHours(.friday) == nil)
    }

    @Test func jourTravailleSansHeureSaisieNCompePasDansLeTotal() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let employer = Employer(context: context)
        employer.id = UUID()
        employer.name = "Compagnie Aparté"

        employer.setTypicalWeekDay(.tuesday, isWorked: true, hours: nil)

        #expect(employer.typicalWeekWorkedDaysCount == 1)
        #expect(employer.typicalWeeklyHoursTotal == 0) // aucune heure renseignée, pas compté comme 0h explicite
    }

    @Test func typicalWeekDaysRespecteLOrdreLundiDimanche() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let employer = Employer(context: context)
        employer.id = UUID()
        employer.name = "Compagnie Aparté"

        let orderedWeekdays = employer.typicalWeekDays.map { $0.weekday }
        #expect(orderedWeekdays == [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday])
    }

    @Test func typicalWeekEnabledEstFauxParDefaut() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let employer = Employer(context: context)
        employer.id = UUID()
        employer.name = "Compagnie Aparté"

        #expect(employer.typicalWeekEnabled == false)
        employer.typicalWeekEnabled = true
        #expect(employer.typicalWeekEnabled == true)
    }
}
