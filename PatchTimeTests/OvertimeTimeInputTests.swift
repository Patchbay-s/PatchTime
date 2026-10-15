import Foundation
import Testing
@testable import PatchTime

struct OvertimeTimeInputTests {
    private var utc: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private var day: Date {
        utc.date(from: DateComponents(year: 2026, month: 10, day: 7))!
    }

    private func m(_ hour: Int, _ minute: Int = 0) -> Int { hour * 60 + minute }

    private func input(_ start: Int, _ end: Int, nextDay: Bool? = nil) -> OvertimeTimeInput {
        OvertimeTimeInput(day: day, startMinutes: start, endMinutes: end, endsNextDay: nextDay)
    }

    private func hours(_ input: OvertimeTimeInput) -> Double {
        let range = input.range(calendar: utc)
        return range.end.timeIntervalSince(range.start) / 3600
    }

    // MARK: - Bascule automatique (roues)

    @Test func rouesFinAvantDebutPassentAuLendemain() {
        var value = input(m(18), m(19))
        #expect(value.endsNextDay == false)
        value.setEnd(m(2))
        #expect(value.endsNextDay == true)
        #expect(value.isValid)
        value.setStart(m(1))
        #expect(value.endsNextDay == false)
        #expect(hours(value) == 1)
    }

    @Test func lendemainAfficheLaDateReelleDeFin() {
        let value = input(m(22), m(2))
        #expect(value.endDay(calendar: utc) == utc.date(from: DateComponents(year: 2026, month: 10, day: 8))!)
        #expect(value.endText == "02:00 +1 j")
        #expect(hours(value) == 4)
    }

    // MARK: - Bascule manuelle

    @Test func basculeManuelleNeModifiePasLesHeures() {
        var value = input(m(22), m(2))
        value.setEndsNextDay(false)
        #expect(value.startMinutes == m(22))
        #expect(value.endMinutes == m(2))
        #expect(value.problem == .endNotAfterStart)
        #expect(value.problem?.message == "L'heure de fin doit être après le début, ou choisissez Lendemain (+1 j).")
        value.setEndsNextDay(true)
        #expect(value.isValid)
    }

    @Test func lendemainManuelAvecPlusDeVingtQuatreHeuresEstRefuse() {
        var value = input(m(8), m(10))
        value.setEndsNextDay(true)
        #expect(value.endMinutes == m(10))
        #expect(value.problem == .tooLong)
    }

    // MARK: - Boutons rapides

    @Test func plusUneHeureFranchitMinuit() {
        var value = input(m(22), m(23, 30))
        value.extendEnd(byMinutes: 60)
        #expect(value.endMinutes == m(0, 30))
        #expect(value.endsNextDay)
        #expect(value.isValid)
        #expect(hours(value) == 2.5)
    }

    @Test func copierPuisPlusUneHeureADeuxHeuresTrente() {
        var value = input(m(23, 30), m(23, 45))
        value.copyStartToEnd()
        #expect(value.endMinutes == m(23, 30))
        #expect(value.endsNextDay == false)
        #expect(value.isValid == false)
        value.extendEnd(byMinutes: 60)
        #expect(value.endText == "00:30 +1 j")
        #expect(hours(value) == 1)
    }

    @Test func plusQuinzeMinutesFranchitMinuit() {
        var value = input(m(20), m(23, 45))
        value.extendEnd(byMinutes: 15)
        #expect(value.endText == "00:00 +1 j")
        #expect(value.isValid)
    }

    @Test func boutonsRapidesNeDepassentJamaisVingtQuatreHeures() {
        var value = input(m(8), m(7))
        #expect(value.endsNextDay)
        value.extendEnd(byMinutes: 60)
        #expect(value.endMinutes == m(7, 45))
        #expect(value.isValid)
        value.extendEnd(byMinutes: 15)
        value.extendEnd(byMinutes: 60)
        #expect(value.endMinutes == m(7, 45))
        #expect(hours(value) < 24)
    }

    // MARK: - Réinitialisation

    @Test func reinitialiserRemetDebutPlusUneHeureLeMemeJour() {
        var value = input(m(9), m(8), nextDay: true)
        value.resetEnd()
        #expect(value.endMinutes == m(10))
        #expect(value.endsNextDay == false)
        #expect(value.isValid)
    }

    @Test func reinitialiserTardLeSoirDonneVingtTroisHeuresCinquanteNeuf() {
        var value = input(m(23, 15), m(2))
        value.resetEnd()
        #expect(value.endMinutes == m(23, 59))
        #expect(value.endsNextDay == false)
        #expect(value.isValid)
    }

    // MARK: - Cas limites

    @Test func minuitLeLendemainEstValide() {
        let value = input(m(22), m(0))
        #expect(value.endsNextDay)
        #expect(value.endText == "00:00 +1 j")
        #expect(value.isValid)
        #expect(hours(value) == 2)
    }

    @Test func debutEgalFinResteRefuse() {
        var value = input(m(18), m(19))
        value.setEnd(m(18))
        #expect(value.endsNextDay)
        #expect(value.problem == .sameTime)
        value.setEndsNextDay(false)
        #expect(value.problem == .endNotAfterStart)
    }

    @Test func dureeMaximaleSousVingtQuatreHeures() {
        let longest = input(m(8), m(7, 45))
        #expect(longest.isValid)
        #expect(hours(longest) == 23.75)
        #expect(input(m(8), m(8, 15), nextDay: true).problem == .tooLong)
    }

    @Test func entreeEnregistreeConserveLeLendemain() {
        let start = utc.date(from: DateComponents(year: 2026, month: 10, day: 7, hour: 22))!
        let end = utc.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: 2))!
        let value = OvertimeTimeInput(day: day, start: start, end: end, calendar: utc)
        #expect(value.endsNextDay)
        #expect(value.range(calendar: utc).end == end)
    }
}
