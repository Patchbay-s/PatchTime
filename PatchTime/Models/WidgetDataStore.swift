import CoreData
import WidgetKit

// Données par employeur partagées avec le widget via App Group
struct WidgetEmployerData: Codable {
    let id: String        // UUID string ou "unassigned"
    let name: String
    var hours: Double
    var earnings: Double
    var entryCount: Int
    var nonValidatedCount: Int
}

enum WidgetDataStore {
    static let appGroupID = "group.fr.antxis.apple.PatchTime"

    // Appelé après chaque save du viewContext pour maintenir le snapshot widget à jour.
    static func updateSnapshot(context: NSManagedObjectContext) {
        let calendar = Calendar.current
        let now = Date()
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else { return }
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, second: -1), to: startOfMonth) ?? now

        let overtimeRequest: NSFetchRequest<OvertimeEntry> = OvertimeEntry.fetchRequest()
        overtimeRequest.predicate = NSPredicate(
            format: "archived == NO AND date >= %@ AND date <= %@",
            startOfMonth as NSDate, endOfMonth as NSDate
        )

        let mealRequest: NSFetchRequest<MealEntry> = MealEntry.fetchRequest()
        mealRequest.predicate = NSPredicate(
            format: "archived == NO AND date >= %@ AND date <= %@",
            startOfMonth as NSDate, endOfMonth as NSDate
        )

        let profileRequest: NSFetchRequest<OvertimeProfile> = OvertimeProfile.fetchRequest()
        let employerRequest: NSFetchRequest<Employer> = Employer.fetchRequest()
        let holidayRequest: NSFetchRequest<PublicHoliday> = PublicHoliday.fetchRequest()

        guard let overtimes = try? context.fetch(overtimeRequest),
              let meals = try? context.fetch(mealRequest),
              let profiles = try? context.fetch(profileRequest),
              let employers = try? context.fetch(employerRequest),
              let holidays = try? context.fetch(holidayRequest) else { return }

        let profileByID: [UUID: OvertimeProfile] = Dictionary(uniqueKeysWithValues: profiles.compactMap { p in p.id.map { ($0, p) } })
        let rateByID: [UUID: Double] = Dictionary(uniqueKeysWithValues: profiles.compactMap { p in
            p.id.map { ($0, ReportRowCalculator.bestEffortRate(for: p)) }
        })

        var totalHours = 0.0
        var totalEarnings = 0.0
        var nonValidated = 0

        // Agrégation par employeur
        var employerMap: [String: WidgetEmployerData] = [:]
        for employer in employers {
            guard let eid = employer.id else { continue }
            employerMap[eid.uuidString] = WidgetEmployerData(
                id: eid.uuidString,
                name: employer.name ?? "Employeur",
                hours: 0, earnings: 0, entryCount: 0, nonValidatedCount: 0
            )
        }
        var unassigned = WidgetEmployerData(
            id: "unassigned", name: "Sans employeur", hours: 0, earnings: 0, entryCount: 0, nonValidatedCount: 0
        )

        for entry in overtimes {
            guard let start = entry.startTime, let end = entry.endTime else { continue }
            let hours = end.timeIntervalSince(start) / 3600
            let rate = entry.profileID.flatMap { rateByID[$0] } ?? 0
            let isRecup = entry.type == "recup"
            let profile = entry.profileID.flatMap { profileByID[$0] }
            let multiplier = isRecup ? 1.0 : OvertimeSurcharge.multiplier(for: entry, profile: profile, holidays: holidays)
            let (h, e): (Double, Double) = isRecup
                ? (-hours, -(hours * rate))
                : (hours, hours * rate * multiplier)
            totalHours += h
            totalEarnings += e

            let entryNonValidated = !(entry.value(forKey: "isValidated") as? Bool ?? false)
            if entryNonValidated { nonValidated += 1 }

            if let eid = entry.employerID, var data = employerMap[eid.uuidString] {
                data.hours += h; data.earnings += e; data.entryCount += 1
                if entryNonValidated { data.nonValidatedCount += 1 }
                employerMap[eid.uuidString] = data
            } else {
                unassigned.hours += h; unassigned.earnings += e; unassigned.entryCount += 1
                if entryNonValidated { unassigned.nonValidatedCount += 1 }
            }
        }

        // Construire la liste : employeurs avec au moins 1 entrée + unassigned si non vide
        var employerList = employerMap.values.filter { $0.entryCount > 0 }.sorted { $0.name < $1.name }
        if unassigned.entryCount > 0 { employerList.append(unassigned) }

        let currency = UserDefaults.standard.string(forKey: "currency") ?? "€"
        let shared = UserDefaults(suiteName: appGroupID)
        shared?.set(totalHours,    forKey: "widget_monthHours")
        shared?.set(totalEarnings, forKey: "widget_monthEarnings")
        shared?.set(meals.count,   forKey: "widget_monthMeals")
        shared?.set(nonValidated,  forKey: "widget_nonValidated")
        shared?.set(currency,      forKey: "widget_currency")
        shared?.set(now,           forKey: "widget_updatedAt")
        if let data = try? JSONEncoder().encode(employerList) {
            shared?.set(data, forKey: "widget_employers")
        }

        WidgetCenter.shared.reloadAllTimelines()
    }
}
