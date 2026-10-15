import Testing
import Foundation
@testable import PatchTime

struct TypicalWeekProjectionEstimatorTests {
    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    // Dates de référence 2026, jour de semaine connu : 5 janvier = lundi, 10 janvier = samedi.
    private var monday: Date { utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 5))! }
    private var saturday: Date { utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 10))! }

    @Test func entreeReelleUnJourDuPatternNAjoutePasDeJourSupplementaire() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()

        let employer = Employer(context: context)
        employer.id = UUID()
        employer.name = "Compagnie Aparté"
        employer.typicalWeekEnabled = true
        employer.setTypicalWeekDay(.monday, isWorked: true, hours: 7.0)

        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Taux A", tauxBrut: 20.0)
        profile.employer = employer

        let contract = Contract(context: context)
        contract.id = UUID()
        contract.employer = employer
        contract.startDate = utcCalendar.date(from: DateComponents(year: 2020, month: 1, day: 1))!

        let entry = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: monday, startTime: monday, endTime: monday.addingTimeInterval(2 * 3600), type: "sup", profileID: profile.id)

        let result = TypicalWeekProjectionEstimator.estimate(
            year: 2026, overtimeEntries: [entry], profiles: [profile], contracts: [contract], calendar: utcCalendar
        )

        // 1 jour/semaine * ~52.14 semaines ≈ 52 jours de gabarit, aucun +1 pour l'entrée réelle
        // qui tombe un lundi (jour du pattern) — déjà comptée via le gabarit.
        #expect(result.templateDaysCount == 52)
        #expect(result.extraRealDaysCount == 0)
        #expect(result.totalDaysCount == 52)
    }

    @Test func entreeReelleHorsPatternAjouteUnJourSupplementaire() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()

        let employer = Employer(context: context)
        employer.id = UUID()
        employer.name = "Compagnie Aparté"
        employer.typicalWeekEnabled = true
        employer.setTypicalWeekDay(.monday, isWorked: true, hours: 7.0)
        // Samedi non marqué travaillé.

        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Taux A", tauxBrut: 20.0)
        profile.employer = employer

        let contract = Contract(context: context)
        contract.id = UUID()
        contract.employer = employer
        contract.startDate = utcCalendar.date(from: DateComponents(year: 2020, month: 1, day: 1))!

        let entry = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: saturday, startTime: saturday, endTime: saturday.addingTimeInterval(2 * 3600), type: "sup", profileID: profile.id)

        let result = TypicalWeekProjectionEstimator.estimate(
            year: 2026, overtimeEntries: [entry], profiles: [profile], contracts: [contract], calendar: utcCalendar
        )

        #expect(result.templateDaysCount == 52)
        #expect(result.extraRealDaysCount == 1)
        #expect(result.totalDaysCount == 53)
    }

    @Test func employeurSansSemaineTypeUtiliseLeDedoublonnageParDate() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()

        let employer = Employer(context: context)
        employer.id = UUID()
        employer.name = "Compagnie Aparté"
        employer.typicalWeekEnabled = false

        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Taux A", tauxBrut: 20.0)
        profile.employer = employer

        let entry1 = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: monday, startTime: monday, endTime: monday.addingTimeInterval(2 * 3600), type: "sup", profileID: profile.id)
        let entry2 = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: monday, startTime: monday, endTime: monday.addingTimeInterval(4 * 3600), type: "sup", profileID: profile.id)

        let result = TypicalWeekProjectionEstimator.estimate(
            year: 2026, overtimeEntries: [entry1, entry2], profiles: [profile], contracts: [], calendar: utcCalendar
        )

        #expect(result.templateDaysCount == 0)
        // Même date, même employeur sans Semaine type : dédoublonné, compte pour 1 seul jour.
        #expect(result.extraRealDaysCount == 1)
    }

    @Test func deuxEntreesMemeDateHorsPatternMemeEmployeurNeComptentQuUneFois() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()

        let employer = Employer(context: context)
        employer.id = UUID()
        employer.name = "Compagnie Aparté"
        employer.typicalWeekEnabled = true
        employer.setTypicalWeekDay(.monday, isWorked: true, hours: 7.0)

        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Taux A", tauxBrut: 20.0)
        profile.employer = employer

        let contract = Contract(context: context)
        contract.id = UUID()
        contract.employer = employer
        contract.startDate = utcCalendar.date(from: DateComponents(year: 2020, month: 1, day: 1))!

        let entry1 = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: saturday, startTime: saturday, endTime: saturday.addingTimeInterval(2 * 3600), type: "sup", profileID: profile.id)
        let entry2 = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: saturday, startTime: saturday, endTime: saturday.addingTimeInterval(4 * 3600), type: "sup", profileID: profile.id)

        let result = TypicalWeekProjectionEstimator.estimate(
            year: 2026, overtimeEntries: [entry1, entry2], profiles: [profile], contracts: [contract], calendar: utcCalendar
        )

        #expect(result.extraRealDaysCount == 1)
    }

    @Test func aucuneEntreeEtAucunContratDonneZero() async throws {
        let result = TypicalWeekProjectionEstimator.estimate(
            year: 2026, overtimeEntries: [], profiles: [], contracts: [], calendar: utcCalendar
        )

        #expect(result.templateDaysCount == 0)
        #expect(result.extraRealDaysCount == 0)
        #expect(result.totalDaysCount == 0)
    }

    @Test func congePayeSurJourDuPatternExcluDuTemplateDaysCount() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()

        let employer = Employer(context: context)
        employer.id = UUID()
        employer.typicalWeekEnabled = true
        employer.setTypicalWeekDay(.monday, isWorked: true, hours: 7.0)

        let contract = Contract(context: context)
        contract.id = UUID()
        contract.employer = employer
        contract.startDate = utcCalendar.date(from: DateComponents(year: 2020, month: 1, day: 1))!

        let leave = LeaveEntry(context: context)
        leave.id = UUID()
        leave.date = monday
        leave.leaveType = .congePaye

        let result = TypicalWeekProjectionEstimator.estimate(
            year: 2026, overtimeEntries: [], profiles: [], contracts: [contract], leaveEntries: [leave], calendar: utcCalendar
        )

        // 52 jours de gabarit - 1 jour de CP tombant sur un lundi (pattern) = 51.
        #expect(result.templateDaysCount == 51)
        #expect(result.extraRealDaysCount == 0)
    }

    @Test func entreeReelleSurJourDePatternMaisAvecCongeBascuLeEnJourSupplementaire() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()

        let employer = Employer(context: context)
        employer.id = UUID()
        employer.typicalWeekEnabled = true
        employer.setTypicalWeekDay(.monday, isWorked: true, hours: 7.0)

        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Taux A", tauxBrut: 20.0)
        profile.employer = employer

        let contract = Contract(context: context)
        contract.id = UUID()
        contract.employer = employer
        contract.startDate = utcCalendar.date(from: DateComponents(year: 2020, month: 1, day: 1))!

        // Cas limite : un CP posé le même jour qu'une entrée réelle "sup".
        let leave = LeaveEntry(context: context)
        leave.id = UUID()
        leave.date = monday
        leave.leaveType = .congePaye
        let entry = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: monday, startTime: monday, endTime: monday.addingTimeInterval(2 * 3600), type: "sup", profileID: profile.id)

        let result = TypicalWeekProjectionEstimator.estimate(
            year: 2026, overtimeEntries: [entry], profiles: [profile], contracts: [contract], leaveEntries: [leave], calendar: utcCalendar
        )

        // Le gabarit n'inclut plus ce lundi (exclu par le CP) : l'entrée réelle n'est donc plus
        // "déjà comptée" par le gabarit et bascule en jour supplémentaire, pas silencieusement perdue.
        #expect(result.templateDaysCount == 51)
        #expect(result.extraRealDaysCount == 1)
    }

    /// Reproduit exactement le scénario diagnostiqué empiriquement (seed réel dans le
    /// simulateur) : une entrée "sup" archivée hors gabarit doit compter comme jour
    /// supplémentaire au même titre qu'une entrée active — `estimate` ne doit plus la rejeter
    /// silencieusement via un filtre `archived` interne (l'a fait par le passé, en dur dans le
    /// guard, ce qui était la cause du bug "jours travaillés toujours incorrect").
    @Test func entreeArchiveeHorsPatternCompteAussiCommeJourSupplementaire() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()

        let employer = Employer(context: context)
        employer.id = UUID()
        employer.typicalWeekEnabled = true
        employer.setTypicalWeekDay(.monday, isWorked: true, hours: 7.0)
        // Samedi non marqué travaillé.

        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Taux A", tauxBrut: 20.0)
        profile.employer = employer

        let contract = Contract(context: context)
        contract.id = UUID()
        contract.employer = employer
        contract.startDate = utcCalendar.date(from: DateComponents(year: 2020, month: 1, day: 1))!

        let saturday2 = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 17))! // samedi suivant

        let activeEntry = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: saturday, startTime: saturday, endTime: saturday.addingTimeInterval(2 * 3600), type: "sup", profileID: profile.id, archived: false)
        let archivedEntry = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: saturday2, startTime: saturday2, endTime: saturday2.addingTimeInterval(2 * 3600), type: "sup", profileID: profile.id, archived: true)

        let result = TypicalWeekProjectionEstimator.estimate(
            year: 2026, overtimeEntries: [activeEntry, archivedEntry], profiles: [profile], contracts: [contract], calendar: utcCalendar
        )

        // 2 samedis distincts hors pattern, un actif + un traité : les deux doivent compter.
        #expect(result.extraRealDaysCount == 2)
        #expect(result.totalDaysCount == 54) // 52 gabarit + 2
    }
}
