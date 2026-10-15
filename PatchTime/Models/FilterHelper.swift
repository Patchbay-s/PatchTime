import Foundation

enum FilterHelper {
    static func isDate(_ date: Date, in period: DisplayPeriod,
                       customStart: Date, customEnd: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        switch period {
        case .all:
            return true
        case .year:
            return calendar.isDate(date, equalTo: now, toGranularity: .year)
        case .month:
            return calendar.isDate(date, equalTo: now, toGranularity: .month)
        case .last30Days:
            let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now)
                ?? now.addingTimeInterval(-30 * 86400)
            return date >= thirtyDaysAgo
        case .week:
            return calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear)
        case .custom:
            return date >= customStart && date <= customEnd
        }
    }

    /// Équivalent CoreData de `isDate(_:in:customStart:customEnd:)`, pour pousser le filtre de
    /// période dans le predicate d'un `@FetchRequest` plutôt que de filtrer en mémoire tout
    /// l'historique. `nil` signifie "aucune restriction" (cas `.all`).
    static func datePredicate(for period: DisplayPeriod, customStart: Date, customEnd: Date,
                               dateKey: String = "date") -> NSPredicate? {
        let calendar = Calendar.current
        let now = Date()
        switch period {
        case .all:
            return nil
        case .year:
            guard let interval = calendar.dateInterval(of: .year, for: now) else { return nil }
            return NSPredicate(format: "%K >= %@ AND %K < %@", dateKey, interval.start as NSDate, dateKey, interval.end as NSDate)
        case .month:
            guard let interval = calendar.dateInterval(of: .month, for: now) else { return nil }
            return NSPredicate(format: "%K >= %@ AND %K < %@", dateKey, interval.start as NSDate, dateKey, interval.end as NSDate)
        case .last30Days:
            let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now)
                ?? now.addingTimeInterval(-30 * 86400)
            return NSPredicate(format: "%K >= %@", dateKey, thirtyDaysAgo as NSDate)
        case .week:
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: now) else { return nil }
            return NSPredicate(format: "%K >= %@ AND %K < %@", dateKey, interval.start as NSDate, dateKey, interval.end as NSDate)
        case .custom:
            return NSPredicate(format: "%K >= %@ AND %K <= %@", dateKey, customStart as NSDate, dateKey, customEnd as NSDate)
        }
    }
}
