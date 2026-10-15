import AppIntents
import WidgetKit
import SwiftUI

// MARK: - Shared data (mirrors WidgetDataStore.WidgetEmployerData)

private struct EmployerData: Codable {
    let id: String
    let name: String
    var hours: Double
    var earnings: Double
    var entryCount: Int
    var nonValidatedCount: Int
}

private let appGroupSuite = "group.fr.antxis.apple.PatchTime"

private func loadEmployerData() -> [EmployerData] {
    guard let raw = UserDefaults(suiteName: appGroupSuite)?.data(forKey: "widget_employers"),
          let list = try? JSONDecoder().decode([EmployerData].self, from: raw)
    else { return [] }
    return list
}

// MARK: - AppEntity  (iOS 17+)

@available(iOS 17.0, *)
struct EmployerEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Employeur"
    static var defaultQuery = EmployerEntityQuery()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

@available(iOS 17.0, *)
struct EmployerEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [EmployerEntity] {
        loadEmployerData()
            .filter { identifiers.contains($0.id) }
            .map { EmployerEntity(id: $0.id, name: $0.name) }
    }

    func suggestedEntities() async throws -> [EmployerEntity] {
        loadEmployerData().map { EmployerEntity(id: $0.id, name: $0.name) }
    }

    func defaultResult() async -> EmployerEntity? {
        loadEmployerData().first.map { EmployerEntity(id: $0.id, name: $0.name) }
    }
}

// MARK: - Intent

@available(iOS 17.0, *)
struct EmployerSelectionIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Employeur"
    static var description = IntentDescription("Choisissez un employeur à afficher.")

    @Parameter(title: "Employeur", optionsProvider: EmployerOptionsProvider())
    var employer: EmployerEntity?

    struct EmployerOptionsProvider: DynamicOptionsProvider {
        func results() async throws -> [EmployerEntity] {
            try await EmployerEntityQuery().suggestedEntities()
        }
    }
}

// MARK: - Entry

@available(iOS 17.0, *)
struct EmployerWidgetEntry: TimelineEntry {
    let date: Date
    let employerName: String
    let hours: Double
    let earnings: Double
    let entryCount: Int
    let nonValidatedCount: Int
    let currency: String
    let hasData: Bool

    static let placeholder = EmployerWidgetEntry(
        date: .now,
        employerName: "Entreprise ABC",
        hours: 8.5,
        earnings: 212.5,
        entryCount: 3,
        nonValidatedCount: 1,
        currency: "€",
        hasData: true
    )

    static func fromSharedDefaults(employerID: String?) -> EmployerWidgetEntry {
        let d = UserDefaults(suiteName: appGroupSuite)
        let currency = d?.string(forKey: "widget_currency") ?? "€"
        let employers = loadEmployerData()

        if let eid = employerID {
            if let match = employers.first(where: { $0.id == eid }) {
                return EmployerWidgetEntry(
                    date: .now, employerName: match.name,
                    hours: match.hours, earnings: match.earnings,
                    entryCount: match.entryCount, nonValidatedCount: match.nonValidatedCount,
                    currency: currency, hasData: true
                )
            } else {
                return EmployerWidgetEntry(
                    date: .now, employerName: "Employeur introuvable",
                    hours: 0, earnings: 0, entryCount: 0, nonValidatedCount: 0,
                    currency: currency, hasData: false
                )
            }
        } else {
            let totalHours         = employers.reduce(0.0) { $0 + $1.hours }
            let totalEarnings      = employers.reduce(0.0) { $0 + $1.earnings }
            let totalCount         = employers.reduce(0)   { $0 + $1.entryCount }
            let totalNonValidated  = employers.reduce(0)   { $0 + $1.nonValidatedCount }
            return EmployerWidgetEntry(
                date: .now, employerName: "Tous les employeurs",
                hours: totalHours, earnings: totalEarnings,
                entryCount: totalCount, nonValidatedCount: totalNonValidated,
                currency: currency, hasData: !employers.isEmpty
            )
        }
    }
}

// MARK: - Provider

@available(iOS 17.0, *)
struct EmployerTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> EmployerWidgetEntry { .placeholder }

    func snapshot(for configuration: EmployerSelectionIntent, in context: Context) async -> EmployerWidgetEntry {
        context.isPreview
            ? .placeholder
            : .fromSharedDefaults(employerID: configuration.employer?.id)
    }

    func timeline(for configuration: EmployerSelectionIntent, in context: Context) async -> Timeline<EmployerWidgetEntry> {
        let entry = EmployerWidgetEntry.fromSharedDefaults(employerID: configuration.employer?.id)
        let cal = Calendar.current
        let nextMonth = cal.date(byAdding: .month, value: 1, to: entry.date) ?? entry.date.addingTimeInterval(30 * 86400)
        let refresh = cal.date(from: cal.dateComponents([.year, .month], from: nextMonth)) ?? nextMonth
        return Timeline(entries: [entry], policy: .after(refresh))
    }
}

// MARK: - Views

@available(iOS 17.0, *)
private struct EmployerSmallView: View {
    let entry: EmployerWidgetEntry
    private var hoursColor: Color { entry.hours >= 0 ? .green : .orange }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "building.2")
                    .font(.caption.bold())
                    .foregroundColor(.accentColor)
                    .widgetAccentable()
                Text(entry.employerName)
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(formatHours(entry.hours))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(hoursColor)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text(formatEarnings(entry.earnings, currency: entry.currency))
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Spacer()

            Text("\(entry.entryCount) entrée\(entry.entryCount > 1 ? "s" : "")")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
    }
}

@available(iOS 17.0, *)
private struct EmployerMediumView: View {
    let entry: EmployerWidgetEntry
    private var hoursColor: Color { entry.hours >= 0 ? .green : .orange }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "building.2")
                    .foregroundColor(.accentColor)
                    .widgetAccentable()
                    .font(.subheadline.bold())
                Text(entry.employerName)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Spacer()
                Text("Ce mois")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            HStack(spacing: 0) {
                EmpStatCell(label: "Heures",
                            value: formatHours(entry.hours),
                            color: hoursColor, size: 22)

                Divider().frame(height: 44)

                EmpStatCell(label: "Gains",
                            value: formatEarnings(entry.earnings, currency: entry.currency),
                            color: .primary, size: 18)
                    .padding(.leading, 12)

                Divider().frame(height: 44)

                EmpStatCell(label: "Entrées",
                            value: "\(entry.entryCount)",
                            color: .primary, size: 22)
                    .padding(.leading, 12)
            }

            Divider()

            if entry.hasData {
                if entry.nonValidatedCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("\(entry.nonValidatedCount) entrée\(entry.nonValidatedCount > 1 ? "s" : "") non validée\(entry.nonValidatedCount > 1 ? "s" : "")")
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
            } else {
                Text("Aucune entrée ce mois")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
    }
}

@available(iOS 17.0, *)
private struct EmpStatCell: View {
    let label: String
    let value: String
    let color: Color
    let size: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: size, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@available(iOS 17.0, *)
struct EmployerWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: EmployerWidgetEntry

    var body: some View {
        switch family {
        case .systemMedium:
            EmployerMediumView(entry: entry)
        default:
            EmployerSmallView(entry: entry)
        }
    }
}

// MARK: - Widget

@available(iOS 17.0, *)
struct EmployerWidget: Widget {
    let kind = "EmployerWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: EmployerSelectionIntent.self,
            provider: EmployerTimelineProvider()
        ) { entry in
            EmployerWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("PatchTime — Par employeur")
        .description("Heures et gains du mois en cours pour un employeur sélectionné.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Helpers

private func formatHours(_ hours: Double) -> String {
    let sign = hours < 0 ? "-" : "+"
    let abs  = Swift.abs(hours)
    let h    = Int(abs)
    let m    = Int((abs - Double(h)) * 60)
    return m == 0 ? "\(sign)\(h)h" : String(format: "\(sign)%dh%02d", h, m)
}

private func formatEarnings(_ value: Double, currency: String) -> String {
    let fmt = NumberFormatter()
    fmt.numberStyle           = .decimal
    fmt.maximumFractionDigits = 2
    fmt.minimumFractionDigits = 0
    let sign = value < 0 ? "-" : "+"
    let abs  = fmt.string(from: NSNumber(value: Swift.abs(value))) ?? "0"
    return "\(sign)\(abs) \(currency)"
}

// MARK: - Previews

@available(iOS 17.0, *)
#Preview(as: .systemSmall) {
    EmployerWidget()
} timeline: {
    EmployerWidgetEntry.placeholder
}

@available(iOS 17.0, *)
#Preview(as: .systemMedium) {
    EmployerWidget()
} timeline: {
    EmployerWidgetEntry.placeholder
}
