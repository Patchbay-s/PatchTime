import Foundation

/// Calculs purs pour l'onglet Statistiques — délèguent à `ReportRowCalculator`/`FiscalDayCounts`
/// pour le calcul heure par heure (majoration weekend/férié, signe récup) plutôt que de
/// réimplémenter une 3ᵉ fois cette logique déjà partagée par `AnnualReportCalculator`.
enum StatisticsCalculator {
    struct MonthlyHours: Identifiable {
        let month: Int
        let hours: Double
        var id: Int { month }
    }

    /// Heures nettes (majoration appliquée, récupérations soustraites) pour un mois donné.
    /// Ne filtre plus par `archived` en interne (l'a fait par le passé via un paramètre par
    /// défaut à `false` — piégeux : un appelant qui pré-filtrait déjà `overtimeEntries` pour
    /// inclure les entrées traitées se les voyait re-exclues silencieusement ici, cause du bug
    /// "Évolution mensuelle affiche 0" une fois le filtre activé). Le tri actif/traité est
    /// désormais entièrement à la charge de l'appelant, sur `overtimeEntries` en amont.
    static func monthlyNetHours(
        overtimeEntries: [OvertimeEntry],
        year: Int,
        month: Int,
        profiles: [OvertimeProfile],
        holidays: [PublicHoliday],
        calendar: Calendar = .current
    ) -> Double {
        let profileMap: [UUID: OvertimeProfile] = Dictionary(uniqueKeysWithValues: profiles.compactMap { p in p.id.map { ($0, p) } })
        return overtimeEntries.reduce(0.0) { partial, entry in
            guard let date = entry.date,
                  calendar.component(.year, from: date) == year,
                  calendar.component(.month, from: date) == month
            else { return partial }
            return partial + ReportRowCalculator.makeRow(entry: entry, profileMap: profileMap, holidays: holidays).hours
        }
    }

    /// Les 12 mois de `year`, dans l'ordre janvier → décembre. Même principe que
    /// `monthlyNetHours` : aucun filtre `archived` interne, entièrement à la charge de l'appelant.
    static func monthlyHoursForYear(
        overtimeEntries: [OvertimeEntry],
        year: Int,
        profiles: [OvertimeProfile],
        holidays: [PublicHoliday],
        calendar: Calendar = .current
    ) -> [MonthlyHours] {
        let profileMap: [UUID: OvertimeProfile] = Dictionary(uniqueKeysWithValues: profiles.compactMap { p in p.id.map { ($0, p) } })
        var totals = [Int: Double](uniqueKeysWithValues: (1...12).map { ($0, 0.0) })
        for entry in overtimeEntries {
            guard let date = entry.date, calendar.component(.year, from: date) == year else { continue }
            let month = calendar.component(.month, from: date)
            totals[month, default: 0] += ReportRowCalculator.makeRow(entry: entry, profileMap: profileMap, holidays: holidays).hours
        }
        return (1...12).map { MonthlyHours(month: $0, hours: totals[$0] ?? 0) }
    }

    /// Nombre de repas pour l'année, ou pour un mois précis si `month` est fourni — même principe
    /// que `monthlyNetHours` : aucun filtre `archived` interne, à la charge de l'appelant.
    static func mealsCount(mealEntries: [MealEntry], year: Int, month: Int? = nil, calendar: Calendar = .current) -> Int {
        mealEntries.filter { entry in
            guard let date = entry.date, calendar.component(.year, from: date) == year else { return false }
            if let month { return calendar.component(.month, from: date) == month }
            return true
        }.count
    }
}
