import Testing
import Foundation
@testable import PatchTime

struct HolidayManagerSeedTests {
    @Test func laListeMonacoContientLes12JoursFeries2026() async throws {
        let holidays = HolidayManager.monacoSeedHolidays(forYear: 2026)

        #expect(holidays.count == 12)
        let calendar = Calendar(identifier: .gregorian)
        let labels = Set(holidays.map { $0.label })
        #expect(labels.contains("Jour de l'An"))
        #expect(labels.contains("Sainte Dévote"))
        #expect(labels.contains("Fête Nationale"))

        let saintDevote = holidays.first { $0.label == "Sainte Dévote" }
        if let date = saintDevote?.date {
            #expect(calendar.component(.month, from: date) == 1)
            #expect(calendar.component(.day, from: date) == 27)
        }
    }

    /// Couvre le correctif "Finding 2" (dédoublonnage CloudKit multi-appareils) : la logique
    /// pure `HolidayManager.isDuplicate` doit détecter un doublon uniquement quand le jour
    /// civil, la zone ET la source correspondent tous les trois — c'est exactement le contrôle
    /// appliqué dans `seedMonacoIfNeeded()`/`syncIfNeeded(...)` avant chaque
    /// `CoreDataManager.addPublicHoliday`, sans passer par `CoreDataManager.shared` (pattern
    /// `DateHolidayDetectionTests.detecteUnJourFerieParmiUneListe`).
    @Test func isDuplicateDetecteUneEntreeExistanteParJourZoneEtSource() async throws {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!

        let context = CoreDataTestHelpers.makeInMemoryContext()
        let jourDeLAn = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!

        let existing = PublicHoliday(context: context)
        existing.id = UUID()
        existing.date = jourDeLAn
        existing.label = "Jour de l'An"
        existing.zone = .monaco
        existing.sourceValue = .seed
        existing.isUserEdited = false

        let sameDayLater = jourDeLAn.addingTimeInterval(3600 * 10) // même jour, heure différente
        let nextDay = utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 2))!

        // Même jour, même zone, même source -> doublon
        #expect(HolidayManager.isDuplicate(
            date: jourDeLAn, zone: .monaco, source: .seed, among: [existing], calendar: utcCalendar
        ))
        #expect(HolidayManager.isDuplicate(
            date: sameDayLater, zone: .monaco, source: .seed, among: [existing], calendar: utcCalendar
        ))

        // Zone différente -> pas un doublon
        #expect(!HolidayManager.isDuplicate(
            date: jourDeLAn, zone: .metropole, source: .seed, among: [existing], calendar: utcCalendar
        ))

        // Source différente -> pas un doublon (ex : un seed ne masque pas un futur sync API)
        #expect(!HolidayManager.isDuplicate(
            date: jourDeLAn, zone: .monaco, source: .api, among: [existing], calendar: utcCalendar
        ))

        // Jour différent -> pas un doublon
        #expect(!HolidayManager.isDuplicate(
            date: nextDay, zone: .monaco, source: .seed, among: [existing], calendar: utcCalendar
        ))

        // Liste vide -> jamais un doublon
        #expect(!HolidayManager.isDuplicate(
            date: jourDeLAn, zone: .monaco, source: .seed, among: [], calendar: utcCalendar
        ))
    }
}
