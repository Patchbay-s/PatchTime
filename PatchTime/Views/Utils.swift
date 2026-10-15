import Foundation

/// Réutilise le NumberFormatter partagé (voir SharedFormatters.currencyAmount) au lieu d'en
/// instancier un nouveau à chaque appel. Usage main-thread uniquement (comme tout le reste
/// de l'UI SwiftUI) : le formatter est mutable et n'est pas thread-safe.
func formattedCurrency(_ value: Double, currency: String) -> String {
    let formatter = SharedFormatters.currencyAmount
    formatter.currencySymbol = currency
    return formatter.string(from: NSNumber(value: value)) ?? "\(value) \(currency)"
}

extension Date {
    func isInSameDay(as date: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: date)
    }

    func isInSameMonth(as date: Date) -> Bool {
        Calendar.current.isDate(self, equalTo: date, toGranularity: .month)
    }

    func isInSameYear(as date: Date) -> Bool {
        Calendar.current.isDate(self, equalTo: date, toGranularity: .year)
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

func roundedMinute(_ minute: Int) -> Int {
    let allowedMinutes = [0, 15, 30, 45]
    return allowedMinutes.min(by: { abs($0 - minute) < abs($1 - minute) }) ?? 0
}

func roundedToAllowedMinute(date: Date) -> Date {
    let calendar = Calendar.current
    let minutes = calendar.component(.minute, from: date)
    let rounded = roundedMinute(minutes)
    var components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
    components.minute = rounded
    return calendar.date(from: components) ?? date
}

func overtimeDuration(from start: Date, to end: Date) -> TimeInterval {
    end.timeIntervalSince(start)
}

func formattedDuration(from interval: TimeInterval) -> String {
    let clamped = max(0, Int(interval))
    let hours = clamped / 3600
    let minutes = (clamped % 3600) / 60
    return String(format: "%dh%02d", hours, minutes)
}

// MARK: - Shared DateFormatters (instanciés une seule fois, réutilisés partout)
enum SharedFormatters {
    static let frenchLongDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }()

    static let frenchMonthYear: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    static let frenchShortTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    static let pdfDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "dd/MM/yyyy"
        return f
    }()

    static let pdfTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "HH:mm"
        return f
    }()

    static let frenchDateTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateStyle = .long
        f.timeStyle = .short
        return f
    }()

    static let yearMonth: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f
    }()

    static let frenchDayAbbrev: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "E"
        return f
    }()

    // MARK: - Shared NumberFormatters (mêmes raisons : éviter une réinstanciation à chaque appel)

    /// Formatter monétaire générique ; `currencySymbol` est mutable et doit être défini par
    /// l'appelant avant usage (voir `formattedCurrency`).
    static let currencyAmount: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f
    }()

    /// Décimal, virgule FR, 2 décimales — utilisé par les écrans d'export/rapport qui
    /// affichent le symbole de devise séparément (ex. "40,00 €").
    static let frenchDecimalAmount: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "fr_FR")
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f
    }()
}
