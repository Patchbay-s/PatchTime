import WidgetKit
import SwiftUI

// MARK: - Views

private struct LockScreenCircularView: View {
    let entry: WidgetEntry

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "hourglass")
                .font(.caption2)
            Text(formattedHoursCompact(entry.monthHours))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .widgetAccentable()
    }
}

private struct LockScreenRectangularView: View {
    let entry: WidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Heures sup — Ce mois")
                .font(.caption2)
                .widgetAccentable()
                .lineLimit(1)
            Text(formattedHoursCompact(entry.monthHours))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            if entry.nonValidated > 0 {
                Text("\(entry.nonValidated) à valider")
                    .font(.caption2)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Entry view

struct LockScreenWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: WidgetEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            LockScreenRectangularView(entry: entry)
        default:
            LockScreenCircularView(entry: entry)
        }
    }
}

// MARK: - Widget

struct LockScreenWidget: Widget {
    let kind = "LockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OvertimeTimelineProvider()) { entry in
            LockScreenWidgetEntryView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Heures Sup")
        .description("Compteur d'heures supplémentaires du mois en cours, sur l'écran verrouillé.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Helpers

private func formattedHoursCompact(_ hours: Double) -> String {
    let sign = hours < 0 ? "-" : ""
    let abs = Swift.abs(hours)
    let h = Int(abs)
    let m = Int((abs - Double(h)) * 60)
    return m == 0 ? "\(sign)\(h)h" : String(format: "\(sign)%dh%02d", h, m)
}

// MARK: - Previews

#Preview(as: .accessoryCircular) {
    LockScreenWidget()
} timeline: {
    WidgetEntry.placeholder
    WidgetEntry(date: .now, monthHours: -2.5, monthEarnings: -65, monthMeals: 0, nonValidated: 0, currency: "€")
}

#Preview(as: .accessoryRectangular) {
    LockScreenWidget()
} timeline: {
    WidgetEntry.placeholder
}
