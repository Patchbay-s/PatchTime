import Testing
import Foundation
@testable import PatchTime

struct FiscalReportCalculatorTests {
    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    @Test func combineToutesLesDonneesDansUnBilanCoherent() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()

        let employer = Employer(context: context)
        employer.id = UUID()
        employer.name = "Compagnie Aparté"

        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Taux A", tauxBrut: 20.0)
        profile.employer = employer

        let contract = Contract(context: context)
        contract.id = UUID()
        contract.employer = employer
        contract.startDate = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        contract.kmDistanceRoundTripValue = 10.0

        let day = utcCalendar.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let entry = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: day, startTime: day, endTime: day.addingTimeInterval(2 * 3600), type: "sup", profileID: profile.id)
        entry.employerID = employer.id

        let cpStart = utcCalendar.date(from: DateComponents(year: 2026, month: 7, day: 1))!
        let leave = LeaveEntry(context: context)
        leave.id = UUID()
        leave.date = cpStart
        leave.leaveType = .congePaye

        let summary = FiscalReportCalculator.summary(
            year: 2026,
            overtimeEntries: [entry],
            profiles: [profile],
            leaveEntries: [leave],
            holidays: [],
            contracts: [contract],
            fiscalPower: 4,
            isElectric: false,
            kmBareme: .default2026,
            mealBareme: .default2026,
            manualNetIncome: nil,
            calendar: utcCalendar
        )

        #expect(summary.workedDaysCount == 1)
        #expect(summary.congesPayesCount == 1)
        #expect(summary.recuperationCount == 0)
        #expect(summary.kmTotalDistance == 10.0) // 1 jour * 10km
        #expect(summary.mealDeduction == 15.65) // 1 jour * 15.65
        #expect(summary.totalFraisReels == summary.kmDeduction + summary.mealDeduction)
        // Sans revenu saisi, l'abattement se base sur totalEarnings (40.0 pour 2h à 20€).
        #expect(summary.abattementForfaitaire == 4.0) // 40.0 * 0.10
    }

    @Test func utiliseLeRevenuSaisiSiFourni() async throws {
        let summary = FiscalReportCalculator.summary(
            year: 2026,
            overtimeEntries: [],
            profiles: [],
            leaveEntries: [],
            holidays: [],
            contracts: [],
            fiscalPower: 5,
            isElectric: false,
            kmBareme: .default2026,
            mealBareme: .default2026,
            manualNetIncome: 20000.0
        )

        #expect(summary.abattementForfaitaire == 2000.0) // 20000 * 0.10
    }

    @Test func recommandeLeRegimeLePlusAvantageux() async throws {
        // Revenu élevé -> abattement forfaitaire nettement supérieur aux frais réels estimés (0 ici).
        let summaryAbattement = FiscalReportCalculator.summary(
            year: 2026, overtimeEntries: [], profiles: [], leaveEntries: [], holidays: [], contracts: [],
            fiscalPower: 5, isElectric: false, kmBareme: .default2026, mealBareme: .default2026,
            manualNetIncome: 50000.0
        )
        #expect(summaryAbattement.recommendedRegime == .abattementForfaitaire)
    }

    @Test func incomeIsManualRefleteSiUnRevenuAEteSaisi() async throws {
        let withIncome = FiscalReportCalculator.summary(
            year: 2026, overtimeEntries: [], profiles: [], leaveEntries: [], holidays: [], contracts: [],
            fiscalPower: 5, isElectric: false, kmBareme: .default2026, mealBareme: .default2026,
            manualNetIncome: 20000.0
        )
        let withoutIncome = FiscalReportCalculator.summary(
            year: 2026, overtimeEntries: [], profiles: [], leaveEntries: [], holidays: [], contracts: [],
            fiscalPower: 5, isElectric: false, kmBareme: .default2026, mealBareme: .default2026,
            manualNetIncome: nil
        )

        #expect(withIncome.incomeIsManual == true)
        #expect(withoutIncome.incomeIsManual == false)
    }

    @Test func daysSourceActualEntriesParDefautIgnoreLaSemaineType() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()

        let employer = Employer(context: context)
        employer.id = UUID()
        employer.name = "Compagnie Aparté"
        employer.kmDistanceRoundTripValue = 50.0
        employer.typicalWeekEnabled = true
        employer.setTypicalWeekDay(.monday, isWorked: true, hours: 7.0)
        employer.setTypicalWeekDay(.tuesday, isWorked: true, hours: 7.0)
        employer.setTypicalWeekDay(.wednesday, isWorked: true, hours: 7.0)
        employer.setTypicalWeekDay(.thursday, isWorked: true, hours: 7.0)
        employer.setTypicalWeekDay(.friday, isWorked: true, hours: 7.0)

        let contract = Contract(context: context)
        contract.id = UUID()
        contract.employer = employer
        contract.startDate = utcCalendar.date(from: DateComponents(year: 2020, month: 1, day: 1))!
        contract.kmDistanceRoundTripValue = 10.0

        let day = utcCalendar.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let entry = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: day, startTime: day, endTime: day.addingTimeInterval(2 * 3600), type: "sup", profileID: nil)
        entry.employerID = employer.id

        // .actualEntries (par défaut) : la Semaine type active de l'employeur (5 jours/semaine,
        // ~50km/jour) ne doit avoir aucune influence — seule l'unique entrée réelle compte.
        let summary = FiscalReportCalculator.summary(
            year: 2026, overtimeEntries: [entry], profiles: [], leaveEntries: [], holidays: [],
            contracts: [contract], fiscalPower: 5, isElectric: false,
            kmBareme: .default2026, mealBareme: .default2026, manualNetIncome: nil,
            calendar: utcCalendar
        )

        #expect(summary.daysSource == .actualEntries)
        #expect(summary.workedDaysCount == 1)
        #expect(summary.kmTotalDistance == 10.0) // distance du contrat, 1 seul jour réel
    }

    @Test func daysSourceTypicalWeekIgnoreLesEntreesReelles() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()

        let employer = Employer(context: context)
        employer.id = UUID()
        employer.name = "Compagnie Aparté"
        employer.typicalWeekEnabled = true
        employer.setTypicalWeekDay(.monday, isWorked: true, hours: 7.0)

        let contract = Contract(context: context)
        contract.id = UUID()
        contract.employer = employer
        contract.startDate = utcCalendar.date(from: DateComponents(year: 2020, month: 1, day: 1))!
        contract.kmDistanceRoundTripValue = 10.0

        // 50 entrées réelles sur l'année — doivent être totalement ignorées en mode .typicalWeek.
        var entries: [OvertimeEntry] = []
        for offset in 0..<50 {
            let day = utcCalendar.date(byAdding: .day, value: offset, to: utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!)!
            let entry = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: day, startTime: day, endTime: day.addingTimeInterval(2 * 3600), type: "sup", profileID: nil)
            entry.employerID = employer.id
            entries.append(entry)
        }

        let summary = FiscalReportCalculator.summary(
            year: 2026, overtimeEntries: entries, profiles: [], leaveEntries: [], holidays: [],
            contracts: [contract], fiscalPower: 5, isElectric: false,
            kmBareme: .default2026, mealBareme: .default2026, manualNetIncome: nil,
            daysSource: .typicalWeek, calendar: utcCalendar
        )

        #expect(summary.daysSource == .typicalWeek)
        // 1 jour/semaine * ~52.14 semaines ≈ 52 jours, sans rapport avec les 50 entrées réelles.
        #expect(summary.workedDaysCount != 50)
        #expect(summary.workedDaysCount == 52)
    }

    /// `summary` ne filtre plus par `archived` en interne (voir sa documentation) — le tri
    /// actif/traité est à la charge de l'appelant sur `overtimeEntries` en amont, comme pour
    /// tous les calculateurs qu'il combine. `FiscalSummaryView` filtre aux entrées actives avant
    /// l'appel (portée historique du Bilan fiscal) ; `StatisticsView` passe ses entrées déjà
    /// scopées par le toggle "Inclure les entrées traitées dans les totaux". Ce test documente
    /// le contrat au niveau de `FiscalReportCalculator` lui-même.
    @Test func summaryIncluTLesEntreesArchiveesSiLAppelantNeLesFiltrePas() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()

        let employer = Employer(context: context)
        employer.id = UUID()
        employer.name = "Compagnie Aparté"

        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Taux A", tauxBrut: 20.0)
        profile.employer = employer

        let contract = Contract(context: context)
        contract.id = UUID()
        contract.employer = employer
        contract.startDate = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        contract.kmDistanceRoundTripValue = 10.0

        let activeDay = utcCalendar.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let archivedDay = utcCalendar.date(from: DateComponents(year: 2026, month: 3, day: 11))!
        let active = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: activeDay, startTime: activeDay, endTime: activeDay.addingTimeInterval(2 * 3600), type: "sup", profileID: profile.id, archived: false)
        active.employerID = employer.id
        let archived = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: archivedDay, startTime: archivedDay, endTime: archivedDay.addingTimeInterval(2 * 3600), type: "sup", profileID: profile.id, archived: true)
        archived.employerID = employer.id

        let activeOnly = FiscalReportCalculator.summary(
            year: 2026, overtimeEntries: [active], profiles: [profile], leaveEntries: [], holidays: [],
            contracts: [contract], fiscalPower: 4, isElectric: false,
            kmBareme: .default2026, mealBareme: .default2026, manualNetIncome: nil, calendar: utcCalendar
        )
        let includingArchived = FiscalReportCalculator.summary(
            year: 2026, overtimeEntries: [active, archived], profiles: [profile], leaveEntries: [], holidays: [],
            contracts: [contract], fiscalPower: 4, isElectric: false,
            kmBareme: .default2026, mealBareme: .default2026, manualNetIncome: nil, calendar: utcCalendar
        )

        #expect(activeOnly.workedDaysCount == 1)
        #expect(includingArchived.workedDaysCount == 2)
        #expect(includingArchived.totalFraisReels > activeOnly.totalFraisReels)
    }
}
