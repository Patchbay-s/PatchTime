import Testing
import Foundation
@testable import PatchTime

// .serialized : exécuter ces tests en parallèle (comportement par défaut de Swift Testing)
// provoque un crash intermittent (signal abrt) quand plusieurs manipulent simultanément des
// relations CoreData (OvertimeProfile.employer) sur des contextes NSPersistentContainer.viewContext
// distincts mais confinés au thread principal — reproductible en environ 1 run sur 2.
@Suite(.serialized)
struct AnnualReportCalculatorTests {

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func totauxHeureSupSimple() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Studio Zenith", tauxBrut: 20.0)
        let day = makeDate(2025, 6, 3)
        let entry = CoreDataTestHelpers.makeOvertimeEntry(
            context: context, date: day,
            startTime: day, endTime: day.addingTimeInterval(2 * 3600),
            type: "sup", profileID: profile.id
        )

        let summary = AnnualReportCalculator.summary(year: 2025, entries: [entry], profiles: [profile], holidays: [])

        #expect(summary.totalHours == 2.0)
        #expect(summary.totalEarnings == 40.0)
        #expect(summary.entryCount == 1)
        #expect(summary.workedDaysCount == 1)
    }

    @Test func recupSoustraitDuTotal() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "P", tauxBrut: 15.0)
        let day = makeDate(2025, 3, 10)
        let sup = CoreDataTestHelpers.makeOvertimeEntry(
            context: context, date: day,
            startTime: day, endTime: day.addingTimeInterval(4 * 3600),
            type: "sup", profileID: profile.id
        )
        let recup = CoreDataTestHelpers.makeOvertimeEntry(
            context: context, date: day.addingTimeInterval(86400),
            startTime: day, endTime: day.addingTimeInterval(1 * 3600),
            type: "recup", profileID: profile.id
        )

        let summary = AnnualReportCalculator.summary(year: 2025, entries: [sup, recup], profiles: [profile], holidays: [])

        #expect(summary.totalHours == 3.0)       // 4h - 1h
        #expect(summary.totalEarnings == 45.0)   // (4×15) - (1×15)
        #expect(summary.entryCount == 2)
        #expect(summary.workedDaysCount == 2)    // 2 jours distincts
    }

    /// Avec `validationMode` à `nil` (défaut), `summary` n'applique plus aucun filtre `archived`
    /// en interne (l'a fait par le passé — cause du bug "Répartition par employeur exclut les
    /// heures traitées" : un appelant qui pré-filtrait déjà `entries` pour inclure les entrées
    /// traitées se les voyait re-exclues silencieusement ici). Le tri actif/traité est
    /// désormais entièrement à la charge de l'appelant, sur `entries` en amont.
    @Test func sansValidationModeAucunFiltreArchivedInterneEntreesSommeesTelQuelles() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "P", tauxBrut: 10.0)
        let day = makeDate(2025, 1, 15)
        let active = CoreDataTestHelpers.makeOvertimeEntry(
            context: context, date: day, startTime: day, endTime: day.addingTimeInterval(3600),
            type: "sup", profileID: profile.id, archived: false
        )
        let archived = CoreDataTestHelpers.makeOvertimeEntry(
            context: context, date: day, startTime: day, endTime: day.addingTimeInterval(2 * 3600),
            type: "sup", profileID: profile.id, archived: true
        )

        let activeOnlySummary = AnnualReportCalculator.summary(year: 2025, entries: [active], profiles: [profile], holidays: [])
        let bothSummary = AnnualReportCalculator.summary(year: 2025, entries: [active, archived], profiles: [profile], holidays: [])

        #expect(activeOnlySummary.entryCount == 1)
        #expect(activeOnlySummary.totalHours == 1.0)
        #expect(bothSummary.entryCount == 2)
        #expect(bothSummary.totalHours == 3.0) // 1h active + 2h traitée
    }

    @Test func anneeDifferenteExclue() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "P", tauxBrut: 10.0)
        let inYear = makeDate(2025, 5, 1)
        let outOfYear = makeDate(2024, 12, 31)
        let entryIn = CoreDataTestHelpers.makeOvertimeEntry(
            context: context, date: inYear, startTime: inYear, endTime: inYear.addingTimeInterval(3600),
            type: "sup", profileID: profile.id
        )
        let entryOut = CoreDataTestHelpers.makeOvertimeEntry(
            context: context, date: outOfYear, startTime: outOfYear, endTime: outOfYear.addingTimeInterval(3600),
            type: "sup", profileID: profile.id
        )

        let summary = AnnualReportCalculator.summary(year: 2025, entries: [entryIn, entryOut], profiles: [profile], holidays: [])

        #expect(summary.entryCount == 1)
    }

    @Test func repartitionParEmployeurEtSansEmployeur() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()

        let employer = Employer(context: context)
        employer.id = UUID()
        employer.name = "Compagnie Aparté"

        let profileWithEmployer = CoreDataTestHelpers.makeProfile(context: context, name: "Taux A", tauxBrut: 20.0)
        profileWithEmployer.employer = employer

        let profileWithoutEmployer = CoreDataTestHelpers.makeProfile(context: context, name: "Taux B", tauxBrut: 15.0)

        let day = makeDate(2025, 4, 1)
        let entryWithEmployer = CoreDataTestHelpers.makeOvertimeEntry(
            context: context, date: day, startTime: day, endTime: day.addingTimeInterval(2 * 3600),
            type: "sup", profileID: profileWithEmployer.id
        )
        let entryWithoutEmployer = CoreDataTestHelpers.makeOvertimeEntry(
            context: context, date: day, startTime: day, endTime: day.addingTimeInterval(1 * 3600),
            type: "sup", profileID: profileWithoutEmployer.id
        )

        let summary = AnnualReportCalculator.summary(
            year: 2025,
            entries: [entryWithEmployer, entryWithoutEmployer],
            profiles: [profileWithEmployer, profileWithoutEmployer],
            holidays: []
        )

        #expect(summary.employerBreakdown.count == 2)
        let named = summary.employerBreakdown.first { $0.employer != nil }
        let unassigned = summary.employerBreakdown.first { $0.employer == nil }
        #expect(named?.displayName == "Compagnie Aparté")
        #expect(named?.hours == 2.0)
        #expect(named?.earnings == 40.0)
        #expect(unassigned?.hours == 1.0)
        #expect(unassigned?.earnings == 15.0)
    }

    /// Reproduit exactement le scénario diagnostiqué empiriquement (seed réel dans le
    /// simulateur) : un employeur avec une entrée active + une traitée doit voir sa répartition
    /// (`employerBreakdown`) totaliser les deux quand l'appelant les inclut toutes les deux
    /// (équivalent de StatisticsView.scopedOvertimeEntries avec le toggle "Inclure les entrées
    /// traitées" activé).
    @Test func repartitionParEmployeurInclutLesEntreesTraiteesSiLAppelantLesInclut() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()

        let employer = Employer(context: context)
        employer.id = UUID()
        employer.name = "DIAG Employeur"

        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Taux A", tauxBrut: 20.0)
        profile.employer = employer

        let day = makeDate(2025, 4, 1)
        let active = CoreDataTestHelpers.makeOvertimeEntry(
            context: context, date: day, startTime: day, endTime: day.addingTimeInterval(2 * 3600),
            type: "sup", profileID: profile.id, archived: false
        )
        let archived = CoreDataTestHelpers.makeOvertimeEntry(
            context: context, date: day, startTime: day, endTime: day.addingTimeInterval(3 * 3600),
            type: "sup", profileID: profile.id, archived: true
        )

        let summary = AnnualReportCalculator.summary(year: 2025, entries: [active, archived], profiles: [profile], holidays: [])

        #expect(summary.totalHours == 5.0) // 2h active + 3h traitée
        let breakdown = summary.employerBreakdown.first { $0.employer == employer }
        #expect(breakdown?.hours == 5.0)
    }

    @Test func coherenceAvecReportRowCalculator() async throws {
        // Vérifie que le montant calculé pour une entrée individuelle est identique à celui
        // que produirait ReportRowCalculator (même formule, même source de vérité).
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "P", tauxBrut: 18.0)
        let day = makeDate(2025, 9, 9)
        let entry = CoreDataTestHelpers.makeOvertimeEntry(
            context: context, date: day, startTime: day, endTime: day.addingTimeInterval(3 * 3600 + 1800),
            type: "recup", profileID: profile.id
        )

        let summary = AnnualReportCalculator.summary(year: 2025, entries: [entry], profiles: [profile], holidays: [])

        let profileMap: [UUID: OvertimeProfile] = [profile.id!: profile]
        let row = ReportRowCalculator.makeRow(entry: entry, profileMap: profileMap, holidays: [])

        #expect(summary.totalEarnings == row.earnings)
        #expect(summary.totalHours == row.hours)
    }

    @Test func majorationWeekendIncluseDansLeTotalAnnuel() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Studio Zenith", tauxBrut: 20.0)
        profile.weekendSurchargePercentValue = 0.25

        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        let saturday = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 3))!

        let entry = CoreDataTestHelpers.makeOvertimeEntry(
            context: context, date: saturday, startTime: saturday, endTime: saturday.addingTimeInterval(2 * 3600),
            type: "sup", profileID: profile.id
        )

        let summary = AnnualReportCalculator.summary(year: 2026, entries: [entry], profiles: [profile], holidays: [])

        #expect(summary.totalEarnings == 50.0) // 2h * 20 * 1.25, bestEffortRate = tauxBrut ici (pas de tauxNet)
    }

    @Test func validationModeCompleteIncluValideeActiveMaisExclutAValider() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "P", tauxBrut: 10.0)
        let day = makeDate(2025, 5, 1)

        let validatedActive = CoreDataTestHelpers.makeOvertimeEntry(
            context: context, date: day, startTime: day, endTime: day.addingTimeInterval(3600),
            type: "sup", profileID: profile.id, isValidated: true, archived: false
        )
        let toValidate = CoreDataTestHelpers.makeOvertimeEntry(
            context: context, date: day, startTime: day, endTime: day.addingTimeInterval(2 * 3600),
            type: "sup", profileID: profile.id, isValidated: false, archived: false
        )
        let archived = CoreDataTestHelpers.makeOvertimeEntry(
            context: context, date: day, startTime: day, endTime: day.addingTimeInterval(3 * 3600),
            type: "sup", profileID: profile.id, isValidated: true, archived: true
        )

        let summary = AnnualReportCalculator.summary(
            year: 2025, entries: [validatedActive, toValidate, archived], profiles: [profile], holidays: [],
            validationMode: .complete
        )

        // validée-active (1h) + archivée (3h) incluses ; à valider (2h) exclue.
        #expect(summary.totalHours == 4.0)
        #expect(summary.entryCount == 2)
    }

    @Test func validationModeValidatedAndArchivedNIncludeQueLesArchivees() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "P", tauxBrut: 10.0)
        let day = makeDate(2025, 5, 1)

        let validatedActive = CoreDataTestHelpers.makeOvertimeEntry(
            context: context, date: day, startTime: day, endTime: day.addingTimeInterval(3600),
            type: "sup", profileID: profile.id, isValidated: true, archived: false
        )
        let archived = CoreDataTestHelpers.makeOvertimeEntry(
            context: context, date: day, startTime: day, endTime: day.addingTimeInterval(3 * 3600),
            type: "sup", profileID: profile.id, isValidated: true, archived: true
        )

        let summary = AnnualReportCalculator.summary(
            year: 2025, entries: [validatedActive, archived], profiles: [profile], holidays: [],
            validationMode: .validatedAndArchived
        )

        // Seule l'entrée archivée compte — la validée-mais-active (1h) est exclue de ce mode.
        #expect(summary.totalHours == 3.0)
        #expect(summary.entryCount == 1)
    }
}
