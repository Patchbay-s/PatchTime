//
//  OvertimeTimeInput.swift
//  PatchTime
//
//  État du formulaire début / fin (Ajout et Modification d'heures sup) : heures des roues
//  en minutes depuis minuit + choix explicite « Même jour » / « Lendemain (+1 j) ».
//  - Roues : le choix se synchronise (fin ≤ début → Lendemain, sinon Même jour).
//  - Bascule manuelle : les heures ne bougent jamais ; une combinaison invalide est
//    signalée par `problem` et bloque l'enregistrement.
//  - Boutons rapides : avancent la fin dans le temps réel, franchissent minuit, plafonnés
//    sous 24 h. La durée reste calculée par `OvertimeTimeRange` (inchangé).
//

import Foundation

struct OvertimeTimeInput: Equatable {
    static let minutesPerDay = 24 * 60
    /// Pas des roues : la plus longue saisie possible est 24 h moins un pas (début = fin refusé).
    static let step = 15

    enum Problem: Equatable {
        /// Même jour avec fin ≤ début.
        case endNotAfterStart
        /// Lendemain avec fin = début (24 h pile) : refusé comme une durée nulle.
        case sameTime
        /// Lendemain avec fin après le début (ou journée de changement d'heure) : > 24 h.
        case tooLong

        var message: String {
            switch self {
            case .endNotAfterStart:
                return "L'heure de fin doit être après le début, ou choisissez Lendemain (+1 j)."
            case .sameTime:
                return "L'heure de fin est identique à l'heure de début : une saisie doit durer moins de 24 heures."
            case .tooLong:
                return "Une saisie ne peut pas dépasser 24 heures : choisissez Même jour ou une heure de fin plus tôt."
            }
        }
    }

    /// Jour où le service commence (la `date` de l'entrée).
    var day: Date
    private(set) var startMinutes: Int
    private(set) var endMinutes: Int
    private(set) var endsNextDay: Bool

    /// `endsNextDay` nil : déduit des heures (fin ≤ début → lendemain).
    init(day: Date, startMinutes: Int, endMinutes: Int, endsNextDay: Bool? = nil) {
        self.day = day
        self.startMinutes = Self.clamped(startMinutes)
        self.endMinutes = Self.clamped(endMinutes)
        self.endsNextDay = endsNextDay ?? (self.endMinutes <= self.startMinutes)
    }

    /// Depuis une entrée enregistrée : le lendemain est repris tel quel (fin un autre jour que le début).
    init(day: Date, start: Date, end: Date, calendar: Calendar = .current) {
        self.init(
            day: day,
            startMinutes: Self.minutes(of: start, calendar: calendar),
            endMinutes: Self.minutes(of: end, calendar: calendar),
            endsNextDay: OvertimeTimeRange.dayOffset(start: start, end: end, calendar: calendar) > 0
        )
    }

    // MARK: - Actions

    /// Roue de début : resynchronise Même jour / Lendemain.
    mutating func setStart(_ minutes: Int) {
        startMinutes = Self.clamped(minutes)
        syncDayFromClocks()
    }

    /// Roue de fin : resynchronise Même jour / Lendemain.
    mutating func setEnd(_ minutes: Int) {
        endMinutes = Self.clamped(minutes)
        syncDayFromClocks()
    }

    /// Bascule manuelle : ne modifie jamais les heures.
    mutating func setEndsNextDay(_ value: Bool) {
        endsNextDay = value
    }

    /// « +15 min » / « +1 h » : avance la fin réelle, passe minuit si besoin, jamais ≥ 24 h.
    mutating func extendEnd(byMinutes delta: Int) {
        let maxTotal = startMinutes + Self.minutesPerDay - Self.step
        let current = endMinutes + (endsNextDay ? Self.minutesPerDay : 0)
        let total = min(current + delta, max(maxTotal, current))
        endsNextDay = total >= Self.minutesPerDay
        endMinutes = total % Self.minutesPerDay
    }

    /// « Copier début → fin » : même heure, même jour (point de départ pour +15 min / +1 h).
    mutating func copyStartToEnd() {
        endMinutes = startMinutes
        endsNextDay = false
    }

    /// « Réinitialiser la fin » : début + 1 h le même jour, ou 23:59 si cela passerait minuit.
    mutating func resetEnd() {
        let candidate = startMinutes + 60
        endMinutes = candidate < Self.minutesPerDay ? candidate : Self.minutesPerDay - 1
        endsNextDay = false
    }

    // MARK: - Résultat

    var problem: Problem? {
        if !endsNextDay {
            return endMinutes > startMinutes ? nil : .endNotAfterStart
        }
        if endMinutes == startMinutes { return .sameTime }
        if endMinutes > startMinutes { return .tooLong }
        // Changement d'heure : 23:30 → 23:15 (+1 j) peut dépasser 24 h réelles.
        let range = range()
        return OvertimeTimeRange.validate(start: range.start, end: range.end) == nil ? nil : .tooLong
    }

    var isValid: Bool { problem == nil }

    /// Dates complètes à enregistrer.
    func range(calendar: Calendar = .current) -> (start: Date, end: Date) {
        let start = Self.date(minutes: startMinutes, on: day, calendar: calendar)
        var end = Self.date(minutes: endMinutes, on: day, calendar: calendar)
        if endsNextDay, let nextDay = calendar.date(byAdding: .day, value: 1, to: end) {
            end = nextDay
        }
        return (start, end)
    }

    /// Jour calendaire de fin (affiché « fin le … »).
    func endDay(calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: range(calendar: calendar).end)
    }

    /// « 00:30 » ou « 00:30 +1 j ».
    var endText: String {
        let clock = String(format: "%02d:%02d", endMinutes / 60, endMinutes % 60)
        return endsNextDay ? "\(clock) +1 j" : clock
    }

    // MARK: - Utilitaires

    static func minutes(of date: Date, calendar: Calendar = .current) -> Int {
        calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
    }

    private mutating func syncDayFromClocks() {
        endsNextDay = endMinutes <= startMinutes
    }

    private static func clamped(_ minutes: Int) -> Int {
        min(max(minutes, 0), minutesPerDay - 1)
    }

    private static func date(minutes: Int, on day: Date, calendar: Calendar) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = minutes / 60
        components.minute = minutes % 60
        components.second = 0
        return calendar.date(from: components) ?? day
    }
}
