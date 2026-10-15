import Foundation

extension Date {
    /// `weekday` : 1 = dimanche, 7 = samedi dans un `Calendar` grégorien standard, quel que
    /// soit `firstWeekday` configuré (contrairement à `CalendarView` qui, lui, réordonne
    /// l'affichage pour commencer le lundi — sans effet sur cette valeur numérique).
    func isWeekend(calendar: Calendar = .current) -> Bool {
        let weekday = calendar.component(.weekday, from: self)
        return weekday == 1 || weekday == 7
    }

    /// `PublicHoliday.date` est toujours encodée en UTC (`HolidayManager.parseAPIResponse` et
    /// `monacoSeedHolidays` forcent explicitement UTC pour lever toute ambiguïté lors du
    /// parsing d'une chaîne "2026-01-01") — comparée ici via ses seuls composants année/mois/jour
    /// UTC, jamais via `calendar.isDate(_:inSameDayAs:)` sur les deux dates brutes : cette
    /// dernière approche dépend du fuseau horaire de `calendar`, qui pour un appareil dont le
    /// fuseau système a un décalage négatif par rapport à UTC (Martinique, Guadeloupe, Guyane,
    /// Polynésie française...) décale le jour férié d'une journée entière et le fait disparaître
    /// du mois affiché.
    func isPublicHoliday(among holidays: [PublicHoliday], calendar: Calendar = .current) -> Bool {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!

        let selfComponents = calendar.dateComponents([.year, .month, .day], from: self)
        return holidays.contains { holiday in
            guard let holidayDate = holiday.date else { return false }
            let holidayComponents = utcCalendar.dateComponents([.year, .month, .day], from: holidayDate)
            return selfComponents.year == holidayComponents.year &&
                   selfComponents.month == holidayComponents.month &&
                   selfComponents.day == holidayComponents.day
        }
    }
}
