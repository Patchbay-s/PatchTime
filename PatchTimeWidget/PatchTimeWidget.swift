import WidgetKit
import SwiftUI

// MARK: - Entry

struct WidgetEntry: TimelineEntry {
    let date: Date
    let monthHours: Double
    let monthEarnings: Double
    let monthMeals: Int
    let nonValidated: Int
    let currency: String
}

extension WidgetEntry {
    static let placeholder = WidgetEntry(
        date: .now,
        monthHours: 12.5,
        monthEarnings: 324.5,
        monthMeals: 5,
        nonValidated: 2,
        currency: "€"
    )

    static func fromSharedDefaults() -> WidgetEntry {
        let d = UserDefaults(suiteName: "group.fr.antxis.apple.PatchTime")
        return WidgetEntry(
            date: .now,
            monthHours:    d?.double(forKey: "widget_monthHours")   ?? 0,
            monthEarnings: d?.double(forKey: "widget_monthEarnings") ?? 0,
            monthMeals:    d?.integer(forKey: "widget_monthMeals")   ?? 0,
            nonValidated:  d?.integer(forKey: "widget_nonValidated") ?? 0,
            currency:      d?.string(forKey: "widget_currency")      ?? "€"
        )
    }
}

// MARK: - Provider

struct OvertimeTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        completion(context.isPreview ? .placeholder : .fromSharedDefaults())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        let entry = WidgetEntry.fromSharedDefaults()
        // Expire au début du mois suivant pour réinitialiser les compteurs
        let calendar = Calendar.current
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: entry.date)
            ?? entry.date.addingTimeInterval(30 * 86400)
        let startOfNextMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: nextMonth))
            ?? nextMonth
        completion(Timeline(entries: [entry], policy: .after(startOfNextMonth)))
    }
}

// MARK: - Small Widget View

struct SmallWidgetView: View {
    let entry: WidgetEntry

    private var hoursColor: Color { entry.monthHours >= 0 ? .green : .orange }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "hourglass")
                    .font(.caption.bold())
                    .foregroundColor(.accentColor)
                    .widgetAccentable()
                Text("Ce mois")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(formattedHours(entry.monthHours))
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(hoursColor)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text(formattedEarnings(entry.monthEarnings, currency: entry.currency))
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Spacer()

            if entry.nonValidated > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Text("\(entry.nonValidated) à valider")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            } else {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Text("Tout validé")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
    }
}

// MARK: - Medium Widget View

struct MediumWidgetView: View {
    let entry: WidgetEntry

    private var hoursColor: Color { entry.monthHours >= 0 ? .green : .orange }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "hourglass")
                    .foregroundColor(.accentColor)
                    .widgetAccentable()
                    .font(.subheadline.bold())
                Text("Heures supplémentaires · Ce mois")
                    .font(.subheadline.bold())
                    .foregroundColor(.secondary)
                Spacer()
            }

            Divider()

            // Stats row
            HStack(spacing: 0) {
                StatCell(
                    label: "Heures",
                    value: formattedHours(entry.monthHours),
                    valueColor: hoursColor,
                    valueFontSize: 22
                )

                Divider().frame(height: 44)

                StatCell(
                    label: "Gains",
                    value: formattedEarnings(entry.monthEarnings, currency: entry.currency),
                    valueColor: .primary,
                    valueFontSize: 18
                )
                .padding(.leading, 12)

                Divider().frame(height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Repas")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: "fork.knife")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        Text("\(entry.monthMeals)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 12)
            }

            Divider()

            // Validation status
            if entry.nonValidated > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("\(entry.nonValidated) entrée\(entry.nonValidated > 1 ? "s" : "") non validée\(entry.nonValidated > 1 ? "s" : "")")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                    Text("Toutes les entrées sont validées")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
    }
}

private struct StatCell: View {
    let label: String
    let value: String
    let valueColor: Color
    let valueFontSize: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: valueFontSize, weight: .bold, design: .rounded))
                .foregroundColor(valueColor)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Entry View

struct PatchTimeWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: WidgetEntry

    var body: some View {
        switch family {
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget

struct PatchTimeWidget: Widget {
    let kind = "PatchTimeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OvertimeTimelineProvider()) { entry in
            if #available(iOS 17.0, *) {
                PatchTimeWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                PatchTimeWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("PatchTime")
        .description("Total des heures supplémentaires du mois en cours.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Helpers

private func formattedHours(_ hours: Double) -> String {
    let sign = hours < 0 ? "-" : "+"
    let abs = Swift.abs(hours)
    let h = Int(abs)
    let m = Int((abs - Double(h)) * 60)
    return m == 0 ? "\(sign)\(h)h" : String(format: "\(sign)%dh%02d", h, m)
}

private func formattedEarnings(_ value: Double, currency: String) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 2
    formatter.minimumFractionDigits = 0
    let sign = value < 0 ? "-" : "+"
    let abs = formatter.string(from: NSNumber(value: Swift.abs(value))) ?? "0"
    return "\(sign)\(abs) \(currency)"
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    PatchTimeWidget()
} timeline: {
    WidgetEntry.placeholder
    WidgetEntry(date: .now, monthHours: -2.5, monthEarnings: -65, monthMeals: 0, nonValidated: 0, currency: "€")
}

#Preview(as: .systemMedium) {
    PatchTimeWidget()
} timeline: {
    WidgetEntry.placeholder
}
