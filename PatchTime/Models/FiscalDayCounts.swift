import Foundation

/// Compteurs de jours pour le bilan fiscal — distincts d'`AnnualReportCalculator.workedDaysCount`
/// (qui compte indifféremment "sup" et "recup") : ici, `workedDaysCount` ne compte que les
/// jours avec au moins une heure "sup" réellement travaillée, car c'est la seule base légitime
/// pour une déduction de frais de repas/km (voir design doc V5, chantiers 5-6).
enum FiscalDayCounts {
    /// Ne filtre plus par `archived` en interne — même contrat que `StatisticsCalculator`/
    /// `TypicalWeekProjectionEstimator`/`AnnualReportCalculator`/`MajorationDetail` (voir leur
    /// documentation) : le tri actif/traité est entièrement à la charge de l'appelant sur
    /// `overtimeEntries` en amont.
    static func workedDaysCount(year: Int, overtimeEntries: [OvertimeEntry], calendar: Calendar = .current) -> Int {
        var days: Set<DateComponents> = []
        for entry in overtimeEntries {
            guard entry.type == "sup", let date = entry.date else { continue }
            guard calendar.component(.year, from: date) == year else { continue }
            days.insert(calendar.dateComponents([.year, .month, .day], from: date))
        }
        return days.count
    }

    /// `employers` restreint le décompte aux jours dont le jour de la semaine fait partie du
    /// gabarit Semaine type d'au moins un employeur actif (voir `isEligibleLeaveDay`) — vide par
    /// défaut, donc aucune restriction pour les appelants qui ne la précisent pas.
    static func leaveDaysCount(year: Int, leaveEntries: [LeaveEntry], type: LeaveType, employers: [Employer] = [], calendar: Calendar = .current) -> Int {
        let yearStart = calendar.yearStart(year)
        let yearEnd = calendar.yearEnd(year)

        var days: Set<DateComponents> = []
        for entry in leaveEntries {
            guard entry.leaveType == type, let start = entry.date else { continue }
            let startDay = calendar.startOfDay(for: start)
            let endDay = entry.endDate.map { calendar.startOfDay(for: $0) } ?? startDay

            var current = startDay
            while current <= endDay {
                if current >= calendar.startOfDay(for: yearStart), current <= calendar.startOfDay(for: yearEnd),
                   employers.isEligibleLeaveDay(current, calendar: calendar) {
                    days.insert(calendar.dateComponents([.year, .month, .day], from: current))
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
                current = next
            }
        }
        return days.count
    }
}
