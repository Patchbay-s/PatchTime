import Foundation

extension LeaveEntry {
    /// Logique de plage de dates (`date`...`endDate`), extraite ici pour être testable et
    /// réutilisée à la fois par `LeaveListView` et `CalendarView`.
    func coversDate(_ date: Date, calendar: Calendar = .current) -> Bool {
        guard let start = self.date else { return false }
        let day = calendar.startOfDay(for: date)
        let startDay = calendar.startOfDay(for: start)
        guard let end = endDate else {
            return day == startDay
        }
        let endDay = calendar.startOfDay(for: end)
        return day >= startDay && day <= endDay
    }
}
