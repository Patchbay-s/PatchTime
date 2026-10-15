import Testing
import Foundation
@testable import PatchTime

struct TypicalWeekExpenseEstimatorTests {
    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    @Test func estimeLesFraisAPartirDeLaSemaineTypeActive() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()

        let employer = Employer(context: context)
        employer.id = UUID()
        employer.name = "Compagnie Aparté"
        employer.kmDistanceRoundTripValue = 20.0
        employer.typicalWeekEnabled = true
        employer.setTypicalWeekDay(.monday, isWorked: true, hours: 7.0)
        employer.setTypicalWeekDay(.tuesday, isWorked: true, hours: 7.0)
        employer.setTypicalWeekDay(.wednesday, isWorked: false, hours: nil)
        employer.setTypicalWeekDay(.thursday, isWorked: true, hours: 7.0)
        employer.setTypicalWeekDay(.friday, isWorked: true, hours: 7.0)
        // 4 jours travaillés/semaine.

        let contract = Contract(context: context)
        contract.id = UUID()
        contract.employer = employer
        contract.startDate = utcCalendar.date(from: DateComponents(year: 2020, month: 1, day: 1))!
        // Contrat actif toute l'année 2026 -> ~52.14 semaines.

        let result = TypicalWeekExpenseEstimator.estimate(
            year: 2026, contracts: [contract], kmBareme: .default2026, mealBareme: .default2026,
            fiscalPower: 5, isElectric: false, calendar: utcCalendar
        )

        // ~52.14 semaines * 4 jours ≈ 208.6 jours -> arrondi à 209 pour le comptage (repas),
        // mais totalKm reste calculé sur la valeur non arrondie (365/7 * 4 * 20 ≈ 4171.43).
        #expect(result.workedDaysCount == 209)
        #expect(abs(result.totalKm - (365.0 / 7.0) * 4.0 * 20.0) < 0.01)
        #expect(result.kmDeduction > 0)
        #expect(result.mealDeduction == Double(result.workedDaysCount) * MealBareme.default2026.maxDeduction)
    }

    @Test func ignoreLesEmployeursSansSemaineTypeActive() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()

        let employer = Employer(context: context)
        employer.id = UUID()
        employer.name = "Compagnie Aparté"
        employer.kmDistanceRoundTripValue = 20.0
        employer.typicalWeekEnabled = false // désactivée
        employer.setTypicalWeekDay(.monday, isWorked: true, hours: 7.0)

        let contract = Contract(context: context)
        contract.id = UUID()
        contract.employer = employer
        contract.startDate = utcCalendar.date(from: DateComponents(year: 2020, month: 1, day: 1))!

        let result = TypicalWeekExpenseEstimator.estimate(
            year: 2026, contracts: [contract], kmBareme: .default2026, mealBareme: .default2026,
            fiscalPower: 5, isElectric: false, calendar: utcCalendar
        )

        #expect(result.workedDaysCount == 0)
        #expect(result.totalKm == 0)
        #expect(result.mealDeduction == 0)
    }

    @Test func sommeAdditivementSurPlusieursEmployeurs() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()

        let employerA = Employer(context: context)
        employerA.id = UUID()
        employerA.name = "Employeur A"
        employerA.kmDistanceRoundTripValue = 10.0
        employerA.typicalWeekEnabled = true
        employerA.setTypicalWeekDay(.monday, isWorked: true, hours: 4.0)

        let employerB = Employer(context: context)
        employerB.id = UUID()
        employerB.name = "Employeur B"
        employerB.kmDistanceRoundTripValue = 30.0
        employerB.typicalWeekEnabled = true
        employerB.setTypicalWeekDay(.monday, isWorked: true, hours: 3.0) // même jour, employeur différent

        let contractA = Contract(context: context)
        contractA.id = UUID()
        contractA.employer = employerA
        contractA.startDate = utcCalendar.date(from: DateComponents(year: 2020, month: 1, day: 1))!

        let contractB = Contract(context: context)
        contractB.id = UUID()
        contractB.employer = employerB
        contractB.startDate = utcCalendar.date(from: DateComponents(year: 2020, month: 1, day: 1))!

        let result = TypicalWeekExpenseEstimator.estimate(
            year: 2026, contracts: [contractA, contractB], kmBareme: .default2026, mealBareme: .default2026,
            fiscalPower: 5, isElectric: false, calendar: utcCalendar
        )

        // Additif, pas de déduplication par jour civil : ~52 jours (A) + ~52 jours (B) ≈ 104-105.
        #expect(result.workedDaysCount >= 104 && result.workedDaysCount <= 106)
    }

    @Test func contratSansSemaineTypeConfigureeDonneZero() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()

        let employer = Employer(context: context)
        employer.id = UUID()
        employer.name = "Compagnie Aparté"
        employer.typicalWeekEnabled = true
        // Aucun jour marqué travaillé.

        let contract = Contract(context: context)
        contract.id = UUID()
        contract.employer = employer
        contract.startDate = utcCalendar.date(from: DateComponents(year: 2020, month: 1, day: 1))!

        let result = TypicalWeekExpenseEstimator.estimate(
            year: 2026, contracts: [contract], kmBareme: .default2026, mealBareme: .default2026,
            fiscalPower: 5, isElectric: false, calendar: utcCalendar
        )

        #expect(result.workedDaysCount == 0)
    }

    @Test func unCongePayeSurUnJourDuPatternReduitLesJoursEtLesFrais() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()

        let employer = Employer(context: context)
        employer.id = UUID()
        employer.name = "Compagnie Aparté"
        employer.kmDistanceRoundTripValue = 20.0
        employer.typicalWeekEnabled = true
        employer.setTypicalWeekDay(.monday, isWorked: true, hours: 7.0)

        let contract = Contract(context: context)
        contract.id = UUID()
        contract.employer = employer
        contract.startDate = utcCalendar.date(from: DateComponents(year: 2020, month: 1, day: 1))!

        let withoutLeave = TypicalWeekExpenseEstimator.estimate(
            year: 2026, contracts: [contract], kmBareme: .default2026, mealBareme: .default2026,
            fiscalPower: 5, isElectric: false, calendar: utcCalendar
        )

        // 5 janvier 2026 = lundi, jour du pattern — le CP prend le dessus.
        let leave = LeaveEntry(context: context)
        leave.id = UUID()
        leave.date = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 5))!
        leave.leaveType = .congePaye

        let withLeave = TypicalWeekExpenseEstimator.estimate(
            year: 2026, contracts: [contract], leaveEntries: [leave], kmBareme: .default2026, mealBareme: .default2026,
            fiscalPower: 5, isElectric: false, calendar: utcCalendar
        )

        #expect(withLeave.workedDaysCount == withoutLeave.workedDaysCount - 1)
        #expect(withLeave.totalKm < withoutLeave.totalKm)
        #expect(withLeave.mealDeduction < withoutLeave.mealDeduction)
    }
}
