import Foundation

enum MajorationDetail {
    /// Ne filtre plus par `archived` en interne — même contrat que `StatisticsCalculator`/
    /// `TypicalWeekProjectionEstimator`/`AnnualReportCalculator` (voir leur documentation) :
    /// un filtre par défaut ici pourrait silencieusement ignorer un pré-filtrage déjà fait par
    /// l'appelant. Le tri actif/traité est entièrement à la charge de l'appelant sur
    /// `overtimeEntries` en amont.
    static func compute(
        year: Int,
        overtimeEntries: [OvertimeEntry],
        profileMap: [UUID: OvertimeProfile],
        holidays: [PublicHoliday],
        calendar: Calendar = .current
    ) -> (hoursCount: Double, surcharge: Double) {
        var hoursCount = 0.0
        var surcharge = 0.0

        for entry in overtimeEntries {
            guard entry.type == "sup",
                  let start = entry.startTime, let end = entry.endTime, let date = entry.date,
                  calendar.component(.year, from: date) == year else { continue }

            let profile = entry.profileID.flatMap { profileMap[$0] }
            let rate = ReportRowCalculator.bestEffortRate(for: profile)
            // Par tranche de jour : une saisie qui passe minuit ne compte comme majorée que
            // pour la part tombant un week-end ou un jour férié.
            for segment in OvertimeSurcharge.segments(start: start, end: end, date: date, profile: profile, holidays: holidays, calendar: calendar)
            where segment.multiplier > 1.0 {
                hoursCount += segment.hours
                surcharge += segment.hours * rate * (segment.multiplier - 1.0)
            }
        }

        return (hoursCount, surcharge)
    }
}
