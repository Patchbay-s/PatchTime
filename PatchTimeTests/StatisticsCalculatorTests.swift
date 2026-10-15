import Testing
import Foundation
@testable import PatchTime

struct StatisticsCalculatorTests {
    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    @Test func monthlyNetHoursSommeUniquementLeMoisDemande() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Taux A", tauxBrut: 20.0)

        let dayInMarch = utcCalendar.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let dayInApril = utcCalendar.date(from: DateComponents(year: 2026, month: 4, day: 1))!

        let marchEntry = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: dayInMarch, startTime: dayInMarch, endTime: dayInMarch.addingTimeInterval(3 * 3600), type: "sup", profileID: profile.id)
        let aprilEntry = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: dayInApril, startTime: dayInApril, endTime: dayInApril.addingTimeInterval(2 * 3600), type: "sup", profileID: profile.id)

        let marchHours = StatisticsCalculator.monthlyNetHours(overtimeEntries: [marchEntry, aprilEntry], year: 2026, month: 3, profiles: [profile], holidays: [], calendar: utcCalendar)

        #expect(marchHours == 3.0)
    }

    @Test func monthlyNetHoursSoustraitLesRecuperations() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Taux A", tauxBrut: 20.0)
        let day = utcCalendar.date(from: DateComponents(year: 2026, month: 3, day: 10))!

        let sup = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: day, startTime: day, endTime: day.addingTimeInterval(5 * 3600), type: "sup", profileID: profile.id)
        let recup = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: day, startTime: day, endTime: day.addingTimeInterval(2 * 3600), type: "recup", profileID: profile.id)

        let hours = StatisticsCalculator.monthlyNetHours(overtimeEntries: [sup, recup], year: 2026, month: 3, profiles: [profile], holidays: [], calendar: utcCalendar)

        #expect(hours == 3.0) // 5h sup - 2h recup
    }

    /// `monthlyNetHours` ne filtre plus par `archived` en interne (l'a fait par le passé via un
    /// paramètre par défaut à `false` — piégeux : un appelant qui pré-filtrait déjà
    /// `overtimeEntries` pour inclure les entrées traitées se les voyait re-exclues
    /// silencieusement à l'intérieur, cause du bug "Évolution mensuelle affiche 0" une fois le
    /// filtre "Inclure les entrées traitées" activé). Le tri est désormais entièrement à la
    /// charge de l'appelant, sur `overtimeEntries` en amont — ces tests documentent ce contrat.
    @Test func monthlyNetHoursSommeLesEntreesArchiveesSiLAppelantNeLesFiltrePas() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Taux A", tauxBrut: 20.0)
        let day = utcCalendar.date(from: DateComponents(year: 2026, month: 3, day: 10))!

        let archived = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: day, startTime: day, endTime: day.addingTimeInterval(3 * 3600), type: "sup", profileID: profile.id, archived: true)

        let hours = StatisticsCalculator.monthlyNetHours(overtimeEntries: [archived], year: 2026, month: 3, profiles: [profile], holidays: [], calendar: utcCalendar)

        #expect(hours == 3.0)
    }

    @Test func monthlyNetHoursSommeUniquementCeQueLAppelantAPreFiltre() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Taux A", tauxBrut: 20.0)
        let day = utcCalendar.date(from: DateComponents(year: 2026, month: 3, day: 10))!

        let active = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: day, startTime: day, endTime: day.addingTimeInterval(2 * 3600), type: "sup", profileID: profile.id, archived: false)
        let archived = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: day, startTime: day, endTime: day.addingTimeInterval(3 * 3600), type: "sup", profileID: profile.id, archived: true)

        let activeOnlyHours = StatisticsCalculator.monthlyNetHours(overtimeEntries: [active], year: 2026, month: 3, profiles: [profile], holidays: [], calendar: utcCalendar)
        let archivedOnlyHours = StatisticsCalculator.monthlyNetHours(overtimeEntries: [archived], year: 2026, month: 3, profiles: [profile], holidays: [], calendar: utcCalendar)
        let combinedHours = StatisticsCalculator.monthlyNetHours(overtimeEntries: [active, archived], year: 2026, month: 3, profiles: [profile], holidays: [], calendar: utcCalendar)

        #expect(activeOnlyHours == 2.0)
        #expect(archivedOnlyHours == 3.0)
        #expect(combinedHours == 5.0)
    }

    @Test func monthlyHoursForYearRetourneLes12MoisDansLOrdre() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Taux A", tauxBrut: 20.0)

        let dayInMarch = utcCalendar.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let entry = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: dayInMarch, startTime: dayInMarch, endTime: dayInMarch.addingTimeInterval(4 * 3600), type: "sup", profileID: profile.id)

        let months = StatisticsCalculator.monthlyHoursForYear(overtimeEntries: [entry], year: 2026, profiles: [profile], holidays: [], calendar: utcCalendar)

        #expect(months.count == 12)
        #expect(months.map { $0.month } == Array(1...12))
        #expect(months[2].hours == 4.0) // index 2 = mars
        #expect(months[0].hours == 0.0)
    }

    /// Reproduit exactement le scénario du bug rapporté : un mois récent actif, plusieurs mois
    /// plus anciens tous archivés (usage normal d'un utilisateur établi qui saisit ses heures en
    /// compta au fil du temps). `monthlyHoursForYear` doit refléter tout ce qu'on lui passe,
    /// sans re-filtrer par archived en interne.
    @Test func monthlyHoursForYearInclutLesMoisArchivesSiLAppelantLesInclut() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Taux A", tauxBrut: 20.0)

        let january = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 10))!
        let march = utcCalendar.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let activeEntry = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: march, startTime: march, endTime: march.addingTimeInterval(3 * 3600), type: "sup", profileID: profile.id, archived: false)
        let archivedEntry = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: january, startTime: january, endTime: january.addingTimeInterval(5 * 3600), type: "sup", profileID: profile.id, archived: true)

        let months = StatisticsCalculator.monthlyHoursForYear(overtimeEntries: [activeEntry, archivedEntry], year: 2026, profiles: [profile], holidays: [], calendar: utcCalendar)
        let total = months.reduce(0.0) { $0 + $1.hours }

        #expect(months[0].hours == 5.0) // janvier, archivé
        #expect(months[2].hours == 3.0) // mars, actif
        #expect(total == 8.0)
    }

    @Test func mealsCountFiltreParAnneeEtOptionnellementParMois() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let dayInMarch = utcCalendar.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let dayInApril = utcCalendar.date(from: DateComponents(year: 2026, month: 4, day: 1))!

        let marchMeal = CoreDataTestHelpers.makeMealEntry(context: context, date: dayInMarch, mealType: "Déjeuner", profileID: nil)
        let aprilMeal = CoreDataTestHelpers.makeMealEntry(context: context, date: dayInApril, mealType: "Déjeuner", profileID: nil)

        let yearCount = StatisticsCalculator.mealsCount(mealEntries: [marchMeal, aprilMeal], year: 2026, calendar: utcCalendar)
        let marchCount = StatisticsCalculator.mealsCount(mealEntries: [marchMeal, aprilMeal], year: 2026, month: 3, calendar: utcCalendar)

        #expect(yearCount == 2)
        #expect(marchCount == 1)
    }
}
