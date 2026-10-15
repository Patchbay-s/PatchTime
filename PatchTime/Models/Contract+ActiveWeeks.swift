import Foundation

extension Contract {
    /// Nombre de semaines (fractionnaire) du contrat effectivement actives dans `year` —
    /// bornées à la fois par l'année et par la période du contrat (`startDate`...`endDate`,
    /// ou `startDate`... si `endDate` est nil). Base du mode "Semaine type" pour estimer un
    /// volume annuel de jours travaillés à partir d'un patron hebdomadaire (voir
    /// `TypicalWeekExpenseEstimator`) : une approximation par semaines pleines, jamais un
    /// prorata jour-par-jour — le croisement avec les congés (`LeaveEntry`) se fait séparément
    /// via `typicalWeekDaysExcludedByLeave(in:leaveEntries:calendar:)`, pas ici.
    func activeWeeksCount(in year: Int, calendar: Calendar = .current) -> Double {
        guard let contractStart = startDate else { return 0 }

        let yearStart = calendar.yearStart(year)
        let yearEnd = calendar.yearEnd(year)

        let periodStart = max(calendar.startOfDay(for: contractStart), yearStart)
        let periodEnd = min(endDate.map { calendar.startOfDay(for: $0) } ?? yearEnd, yearEnd)

        guard periodStart <= periodEnd else { return 0 }

        let daysBetween = calendar.dateComponents([.day], from: periodStart, to: periodEnd).day ?? -1
        guard daysBetween >= 0 else { return 0 }

        return Double(daysBetween + 1) / 7.0
    }

    /// `true` si `date` tombe dans la période active du contrat (`startDate`...`endDate`, ou
    /// `startDate`... si `endDate` est nil) — même borne que `workedDaysCount`/`activeWeeksCount`.
    /// Base du filtrage par contrat de la pastille "jour travaillé" projetée sur le calendrier
    /// (Chantier A) : sans ce filtre, le gabarit de Semaine type s'appliquait à toutes les dates
    /// sans respecter les dates réelles du contrat.
    func covers(date: Date, calendar: Calendar = .current) -> Bool {
        guard let contractStart = startDate else { return false }
        let day = calendar.startOfDay(for: date)
        guard day >= calendar.startOfDay(for: contractStart) else { return false }
        if let contractEnd = endDate, day > calendar.startOfDay(for: contractEnd) { return false }
        return true
    }

    /// Jours travaillés "assumés" par le gabarit de Semaine type sur la période active du
    /// contrat dans `year` — agrégat fractionnaire (`activeWeeksCount × jours travaillés/
    /// semaine`), 0 si la Semaine type n'est pas active pour l'employeur de ce contrat. Base
    /// commune à `TypicalWeekExpenseEstimator` (frais km/repas) et
    /// `TypicalWeekProjectionEstimator` (comptage jours fiscal/statistiques).
    func typicalWeekWorkedDays(in year: Int, calendar: Calendar = .current) -> Double {
        guard let employer, employer.typicalWeekEnabled else { return 0 }
        let workedDaysPerWeek = Double(employer.typicalWeekWorkedDaysCount)
        guard workedDaysPerWeek > 0 else { return 0 }
        let weeks = activeWeeksCount(in: year, calendar: calendar)
        guard weeks > 0 else { return 0 }
        return weeks * workedDaysPerWeek
    }

    /// Nombre de dates distinctes, dans `year` et sur la période active du contrat, qui tombent
    /// un jour de semaine marqué travaillé dans la Semaine type de l'employeur ET sont couvertes
    /// par une `LeaveEntry` (CP/Récup) — à soustraire de `typicalWeekWorkedDays` : le CP/Récup
    /// prend le dessus sur le statut "jour travaillé" projeté, ce jour ne doit plus être compté
    /// nulle part comme travaillé via la Semaine type. Borné au nombre de congés saisis (pas une
    /// énumération de toute l'année), donc pas de coût comparable à celui écarté au chantier
    /// précédent pour le comptage jours réels/pattern.
    func typicalWeekDaysExcludedByLeave(in year: Int, leaveEntries: [LeaveEntry], calendar: Calendar = .current) -> Int {
        guard let employer, employer.typicalWeekEnabled else { return 0 }

        var excludedDates: Set<DateComponents> = []
        for leave in leaveEntries {
            guard let start = leave.date else { continue }
            let startDay = calendar.startOfDay(for: start)
            let endDay = leave.endDate.map { calendar.startOfDay(for: $0) } ?? startDay
            guard startDay <= endDay else { continue }

            var current = startDay
            while current <= endDay {
                if calendar.component(.year, from: current) == year,
                   covers(date: current, calendar: calendar),
                   let weekday = Weekday.from(calendarWeekday: calendar.component(.weekday, from: current)),
                   employer.isTypicalWeekWorked(weekday) {
                    excludedDates.insert(calendar.dateComponents([.year, .month, .day], from: current))
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
                current = next
            }
        }
        return excludedDates.count
    }
}
