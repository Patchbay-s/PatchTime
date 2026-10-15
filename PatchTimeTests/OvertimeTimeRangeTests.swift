import Foundation
import Testing
@testable import PatchTime

struct OvertimeTimeRangeTests {
    private var utc: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func at(_ day: Int, _ hour: Int, _ minute: Int = 0, month: Int = 1, year: Int = 2026, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func hours(_ range: (start: Date, end: Date)) -> Double {
        range.end.timeIntervalSince(range.start) / 3600
    }

    // MARK: - Résolution début / fin

    @Test func vingtDeuxHeuresADeuxHeuresDureQuatreHeuresSurLeLendemain() {
        let day = at(3, 0, calendar: utc)
        let range = OvertimeTimeRange.resolve(day: day, startClock: at(3, 22, calendar: utc), endClock: at(3, 2, calendar: utc), calendar: utc)
        #expect(hours(range) == 4)
        #expect(range.start == at(3, 22, calendar: utc))
        #expect(range.end == at(4, 2, calendar: utc))
        #expect(OvertimeTimeRange.dayOffset(start: range.start, end: range.end, calendar: utc) == 1)
        #expect(OvertimeTimeRange.validate(start: range.start, end: range.end) == nil)
    }

    @Test func vingtTroisHeuresTrenteAMinuitTrenteDureUneHeure() {
        let day = at(10, 0, calendar: utc)
        let range = OvertimeTimeRange.resolve(day: day, startClock: at(1, 23, 30, calendar: utc), endClock: at(1, 0, 30, calendar: utc), calendar: utc)
        #expect(hours(range) == 1)
        #expect(range.end == at(11, 0, 30, calendar: utc))
    }

    @Test func minuitADeuxHeuresResteLeMemeJour() {
        let day = at(10, 0, calendar: utc)
        let range = OvertimeTimeRange.resolve(day: day, startClock: at(10, 0, calendar: utc), endClock: at(10, 2, calendar: utc), calendar: utc)
        #expect(hours(range) == 2)
        #expect(OvertimeTimeRange.dayOffset(start: range.start, end: range.end, calendar: utc) == 0)
    }

    @Test func huitHeuresADixHuitHeuresInchange() {
        let day = at(10, 0, calendar: utc)
        let range = OvertimeTimeRange.resolve(day: day, startClock: at(10, 8, calendar: utc), endClock: at(10, 18, calendar: utc), calendar: utc)
        #expect(hours(range) == 10)
        #expect(range.start == at(10, 8, calendar: utc))
        #expect(range.end == at(10, 18, calendar: utc))
    }

    @Test func lesHeuresSontPlaceesSurLeJourChoisiMemeSiLesRouesPortentUneAutreDate() {
        // Roues réglées un autre jour (date modifiée après coup) : la saisie suit la date.
        let range = OvertimeTimeRange.resolve(day: at(15, 0, calendar: utc), startClock: at(2, 9, calendar: utc), endClock: at(2, 12, calendar: utc), calendar: utc)
        #expect(range.start == at(15, 9, calendar: utc))
        #expect(range.end == at(15, 12, calendar: utc))
    }

    @Test func debutEgalFinEstRefuse() {
        let day = at(10, 0, calendar: utc)
        let range = OvertimeTimeRange.resolve(day: day, startClock: at(10, 18, calendar: utc), endClock: at(10, 18, calendar: utc), calendar: utc)
        #expect(OvertimeTimeRange.validate(start: range.start, end: range.end) == .zeroDuration)
    }

    @Test func plusDeVingtQuatreHeuresEstRefuse() {
        let start = at(10, 8, calendar: utc)
        #expect(OvertimeTimeRange.validate(start: start, end: start.addingTimeInterval(24 * 3600)) == nil)
        #expect(OvertimeTimeRange.validate(start: start, end: start.addingTimeInterval(24 * 3600 + 60)) == .tooLong)
        #expect(OvertimeTimeRange.validate(start: start, end: start.addingTimeInterval(-60)) == .endBeforeStart)
    }

    @Test func affichageAvecPlusUnJour() {
        let text = OvertimeTimeRange.displayText(start: at(3, 22, calendar: .current), end: at(4, 2, calendar: .current), calendar: .current)
        #expect(text == "22:00 → 02:00 (+1 j)")
        let sameDay = OvertimeTimeRange.displayText(start: at(3, 8, calendar: .current), end: at(3, 18, calendar: .current), calendar: .current)
        #expect(sameDay == "08:00 → 18:00")
    }

    // MARK: - Découpage par jour et majorations

    @Test func decoupageParJourCalendaire() {
        let segments = OvertimeTimeRange.dailySegments(start: at(3, 22, calendar: utc), end: at(4, 2, calendar: utc), calendar: utc)
        #expect(segments.map(\.hours) == [2, 2])
        #expect(segments.map(\.dayOffset) == [0, 1])
        // Fin pile à minuit : pas de tranche vide le lendemain.
        let toMidnight = OvertimeTimeRange.dailySegments(start: at(3, 22, calendar: utc), end: at(4, 0, calendar: utc), calendar: utc)
        #expect(toMidnight.map(\.hours) == [2])
    }

    @Test func vendrediSoirVersSamediNeMajoreQueLaPartDuSamedi() {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Studio")
        profile.weekendSurchargePercentValue = 0.25
        // 2 janvier 2026 = vendredi ; 22:00 → 02:00 = 2 h vendredi (×1) + 2 h samedi (×1,25).
        let friday = at(2, 0, calendar: utc)
        let multiplier = OvertimeSurcharge.multiplier(start: at(2, 22, calendar: utc), end: at(3, 2, calendar: utc), date: friday, profile: profile, holidays: [], calendar: utc)
        #expect(abs(multiplier - 1.125) < 0.000_1)
    }

    @Test func samediSoirVersDimancheResteMajoreEnEntier() {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Studio")
        profile.weekendSurchargePercentValue = 0.25
        let saturday = at(3, 0, calendar: utc)
        let multiplier = OvertimeSurcharge.multiplier(start: at(3, 22, calendar: utc), end: at(4, 2, calendar: utc), date: saturday, profile: profile, holidays: [], calendar: utc)
        #expect(abs(multiplier - 1.25) < 0.000_1)
    }

    @Test func reveillonVersJourFerieMajoreLaPartDuPremierJanvier() {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Studio")
        profile.holidaySurchargePercentValue = 1.0
        let holiday = PublicHoliday(context: context)
        holiday.id = UUID()
        holiday.date = at(1, 0, calendar: utc)
        holiday.label = "1er janvier"
        // 31 décembre 2025 (mercredi) 23:00 → 1er janvier 03:00 : 1 h ×1 + 3 h ×2.
        let start = at(31, 23, month: 12, year: 2025, calendar: utc)
        let end = at(1, 3, calendar: utc)
        let parts = OvertimeSurcharge.segments(start: start, end: end, date: start, profile: profile, holidays: [holiday], calendar: utc)
        #expect(parts.map(\.hours) == [1, 3])
        #expect(parts.map(\.multiplier) == [1, 2])
    }

    @Test func saisieSurUnSeulJourGardeLeComportementHistorique() {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Studio")
        profile.weekendSurchargePercentValue = 0.25
        let saturday = at(3, 0, calendar: utc)
        let split = OvertimeSurcharge.multiplier(start: at(3, 8, calendar: utc), end: at(3, 18, calendar: utc), date: saturday, profile: profile, holidays: [], calendar: utc)
        let legacy = OvertimeSurcharge.multiplier(date: saturday, profile: profile, holidays: [], calendar: utc)
        #expect(split == legacy)
    }

    // MARK: - Rattachement au jour de début

    @Test func totalMensuelRattacheAuJourDeDebut() {
        let calendar = Calendar.current
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Studio")
        let day = calendar.date(from: DateComponents(year: 2026, month: 1, day: 31))!
        let range = OvertimeTimeRange.resolve(
            day: day,
            startClock: calendar.date(from: DateComponents(year: 2026, month: 1, day: 31, hour: 22))!,
            endClock: calendar.date(from: DateComponents(year: 2026, month: 1, day: 31, hour: 2))!,
            calendar: calendar
        )
        let entry = CoreDataTestHelpers.makeOvertimeEntry(context: context, date: day, startTime: range.start, endTime: range.end, type: "sup", profileID: profile.id)

        let january = StatisticsCalculator.monthlyNetHours(overtimeEntries: [entry], year: 2026, month: 1, profiles: [profile], holidays: [], calendar: calendar)
        let february = StatisticsCalculator.monthlyNetHours(overtimeEntries: [entry], year: 2026, month: 2, profiles: [profile], holidays: [], calendar: calendar)
        #expect(january == 4)
        #expect(february == 0)
        #expect(entry.timeRangeText == "22:00 → 02:00 (+1 j)")
    }
}
