//
//  OvertimeTimeRange.swift
//  PatchTime
//
//  Heures sup qui passent minuit (ex. 22:00 → 02:00). Modèle inchangé : `startTime` et
//  `endTime` sont des dates complètes, la fin est simplement enregistrée le lendemain ; la
//  durée reste `endTime − startTime` partout. Rattachement : `date` = jour où le service
//  commence (calendrier, semaine, totaux mensuels/annuels, exports) — décision V5.
//  Les saisies existantes ne sont pas modifiées.
//

import Foundation

enum OvertimeTimeRange {
    static let maxDuration: TimeInterval = 24 * 3600

    enum ValidationError: Equatable {
        /// Début = fin : refusé plutôt qu'interprété comme 24 h (choix le plus prudent).
        case zeroDuration
        case tooLong
        case endBeforeStart

        var message: String {
            switch self {
            case .zeroDuration:
                return "L'heure de fin est identique à l'heure de début. Pour un service qui passe minuit, choisissez une heure de fin plus tôt (ex. 22:00 → 02:00)."
            case .tooLong:
                return "Une saisie ne peut pas dépasser 24 heures."
            case .endBeforeStart:
                return "L'heure de fin doit être postérieure à l'heure de début."
            }
        }
    }

    /// Construit début et fin sur `day` à partir des heures/minutes des deux roues. Si l'heure
    /// de fin est avant l'heure de début, la fin passe au lendemain. Heures égales : fin = début
    /// (durée nulle, refusée par `validate`).
    static func resolve(day: Date, startClock: Date, endClock: Date, calendar: Calendar = .current) -> (start: Date, end: Date) {
        let start = time(of: startClock, on: day, calendar: calendar)
        var end = time(of: endClock, on: day, calendar: calendar)
        if end < start, let nextDay = calendar.date(byAdding: .day, value: 1, to: end) {
            end = nextDay
        }
        return (start, end)
    }

    static func validate(start: Date, end: Date) -> ValidationError? {
        let duration = end.timeIntervalSince(start)
        if duration == 0 { return .zeroDuration }
        if duration < 0 { return .endBeforeStart }
        if duration > maxDuration { return .tooLong }
        return nil
    }

    /// Nombre de jours calendaires entre le jour du début et celui de la fin (0 = même jour).
    static func dayOffset(start: Date, end: Date, calendar: Calendar = .current) -> Int {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        return calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0
    }

    /// « 22:00 → 02:00 (+1 j) » ; « 08:00 → 18:00 » le même jour.
    static func displayText(start: Date, end: Date, calendar: Calendar = .current) -> String {
        let formatter = SharedFormatters.pdfTime
        let base = "\(formatter.string(from: start)) → \(formatter.string(from: end))"
        let offset = dayOffset(start: start, end: end, calendar: calendar)
        return offset > 0 ? "\(base) (+\(offset) j)" : base
    }

    /// Découpe la plage par jour calendaire : 22:00 samedi → 02:00 dimanche = 2 h samedi + 2 h
    /// dimanche. Les tranches de durée nulle (fin pile à minuit) sont omises.
    static func dailySegments(start: Date, end: Date, calendar: Calendar = .current) -> [(dayOffset: Int, hours: Double)] {
        guard end > start else { return [] }
        var segments: [(Int, Double)] = []
        var cursor = start
        var offset = 0
        while cursor < end {
            let nextMidnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: cursor)) ?? end
            let segmentEnd = min(nextMidnight, end)
            let hours = segmentEnd.timeIntervalSince(cursor) / 3600
            if hours > 0 { segments.append((offset, hours)) }
            cursor = segmentEnd
            offset += 1
        }
        return segments
    }

    private static func time(of clock: Date, on day: Date, calendar: Calendar) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = calendar.component(.hour, from: clock)
        components.minute = calendar.component(.minute, from: clock)
        components.second = 0
        return calendar.date(from: components) ?? clock
    }
}

extension OvertimeEntry {
    /// « 22:00 → 02:00 (+1 j) » pour les listes et exports ; nil si horaires manquants.
    var timeRangeText: String? {
        guard let startTime, let endTime else { return nil }
        return OvertimeTimeRange.displayText(start: startTime, end: endTime)
    }
}
