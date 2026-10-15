import Testing
import Foundation
@testable import PatchTime

struct DateHolidayDetectionTests {
    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    @Test func detecteSamediEtDimancheCommeWeekend() async throws {
        let saturday = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 3))! // samedi
        let sunday = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 4))!    // dimanche
        let monday = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 5))!    // lundi

        #expect(saturday.isWeekend(calendar: utcCalendar))
        #expect(sunday.isWeekend(calendar: utcCalendar))
        #expect(!monday.isWeekend(calendar: utcCalendar))
    }

    @Test func detecteUnJourFerieParmiUneListe() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let jourDeLAn = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let holiday = PublicHoliday(context: context)
        holiday.id = UUID()
        holiday.date = jourDeLAn
        holiday.label = "1er janvier"

        let sameDayLater = jourDeLAn.addingTimeInterval(3600 * 10)
        let differentDay = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 2))!

        #expect(jourDeLAn.isPublicHoliday(among: [holiday], calendar: utcCalendar))
        #expect(sameDayLater.isPublicHoliday(among: [holiday], calendar: utcCalendar))
        #expect(!differentDay.isPublicHoliday(among: [holiday], calendar: utcCalendar))
        #expect(!differentDay.isPublicHoliday(among: [], calendar: utcCalendar))
    }

    /// Régression B2 : `PublicHoliday.date` est toujours stockée en UTC minuit
    /// (`HolidayManager.parseAPIResponse`/`monacoSeedHolidays`), mais `CalendarMonthGrid`
    /// compare avec le calendrier local de l'appareil. Sur un fuseau à décalage négatif
    /// (Martinique UTC-4 ici), le minuit local du 1er janvier correspond à un instant UTC qui
    /// tombe encore le 31 décembre — une comparaison naïve par instant (`isDate(inSameDayAs:)`)
    /// ratait le jour férié ; la comparaison doit porter uniquement sur les composants
    /// année/mois/jour UTC de la date stockée, indépendamment du calendrier de comparaison.
    @Test func detecteUnJourFerieMemeAvecUnFuseauLocalADecalageNegatif() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let jourDeLAnUTC = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let holiday = PublicHoliday(context: context)
        holiday.id = UUID()
        holiday.date = jourDeLAnUTC
        holiday.label = "1er janvier"

        var martiniqueCalendar = Calendar(identifier: .gregorian)
        martiniqueCalendar.timeZone = TimeZone(identifier: "America/Martinique")! // UTC-4

        // Minuit local en Martinique le 1er janvier 2026 == 04:00 UTC le 1er janvier (même jour
        // UTC que la date stockée) : doit matcher avec un calendrier de comparaison local.
        let localMidnightJan1 = martiniqueCalendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        #expect(localMidnightJan1.isPublicHoliday(among: [holiday], calendar: martiniqueCalendar))

        // Minuit local en Martinique le 31 décembre 2025 == 04:00 UTC le 31 décembre (jour UTC
        // différent) : ne doit pas matcher le jour férié du 1er janvier.
        let localMidnightDec31 = martiniqueCalendar.date(from: DateComponents(year: 2025, month: 12, day: 31))!
        #expect(!localMidnightDec31.isPublicHoliday(among: [holiday], calendar: martiniqueCalendar))
    }
}
