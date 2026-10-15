import Foundation

/// Résout le multiplicateur de majoration weekend/jour férié applicable à une entrée
/// d'heures sup. `1.0` = aucune majoration (date/profil manquant, jour ouvré, ou pourcentages
/// non renseignés). Les deux majorations se cumulent par addition simple si les deux
/// s'appliquent le même jour (ex: jour férié tombant un dimanche), pas par composition —
/// décision explicite du design doc V5, chantier 4.
enum OvertimeSurcharge {
    static func multiplier(
        date: Date?,
        profile: OvertimeProfile?,
        holidays: [PublicHoliday],
        calendar: Calendar = .current
    ) -> Double {
        guard let date, let profile else { return 1.0 }

        var total = 1.0
        if date.isWeekend(calendar: calendar), let weekendPercent = profile.weekendSurchargePercentValue {
            total += weekendPercent
        }
        if date.isPublicHoliday(among: holidays, calendar: calendar), let holidayPercent = profile.holidaySurchargePercentValue {
            total += holidayPercent
        }
        return total
    }

    /// Tranches (heures, multiplicateur) d'une saisie. Une saisie qui passe minuit est
    /// découpée par jour calendaire (22:00 samedi → 02:00 dimanche = 2 h au taux du samedi +
    /// 2 h au taux du dimanche) ; la 1re tranche garde le jour de rattachement `date`. Une
    /// saisie sur un seul jour garde exactement le comportement historique (multiplicateur
    /// de `date` sur toute la durée).
    static func segments(
        start: Date?,
        end: Date?,
        date: Date?,
        profile: OvertimeProfile?,
        holidays: [PublicHoliday],
        calendar: Calendar = .current
    ) -> [(hours: Double, multiplier: Double)] {
        guard let start, let end, end > start else { return [] }
        let parts = OvertimeTimeRange.dailySegments(start: start, end: end, calendar: calendar)
        let baseDay = date ?? start
        guard parts.count > 1 else {
            let hours = end.timeIntervalSince(start) / 3600
            return [(hours, multiplier(date: date, profile: profile, holidays: holidays, calendar: calendar))]
        }
        return parts.map { part in
            let day = calendar.date(byAdding: .day, value: part.dayOffset, to: baseDay)
            return (part.hours, multiplier(date: day, profile: profile, holidays: holidays, calendar: calendar))
        }
    }

    /// Multiplicateur moyen pondéré par la durée de chaque tranche : à multiplier par la durée
    /// totale de la saisie. Identique à `multiplier(date:…)` pour une saisie sur un seul jour.
    static func multiplier(
        start: Date?,
        end: Date?,
        date: Date?,
        profile: OvertimeProfile?,
        holidays: [PublicHoliday],
        calendar: Calendar = .current
    ) -> Double {
        let parts = segments(start: start, end: end, date: date, profile: profile, holidays: holidays, calendar: calendar)
        let totalHours = parts.reduce(0) { $0 + $1.hours }
        guard totalHours > 0 else {
            return multiplier(date: date, profile: profile, holidays: holidays, calendar: calendar)
        }
        return parts.reduce(0) { $0 + $1.hours * $1.multiplier } / totalHours
    }

    static func multiplier(
        for entry: OvertimeEntry,
        profile: OvertimeProfile?,
        holidays: [PublicHoliday],
        calendar: Calendar = .current
    ) -> Double {
        multiplier(start: entry.startTime, end: entry.endTime, date: entry.date, profile: profile, holidays: holidays, calendar: calendar)
    }
}
