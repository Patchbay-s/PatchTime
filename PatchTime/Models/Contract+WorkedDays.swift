import Foundation

extension Contract {
    /// Nombre de jours civils distincts, dans `year`, où au moins une `OvertimeEntry` de type
    /// `"sup"` (jamais `"recup"`), appartenant à l'employeur de ce contrat et tombant dans sa
    /// période active (`startDate`...`endDate`, ou `startDate`... si `endDate` est nil), a été
    /// saisie. Dérivé des données réelles — jamais une estimation, per design doc V5 chantier 5.
    /// Ne filtre plus par `archived` en interne — même contrat que les autres calculateurs
    /// (voir `FiscalDayCounts.workedDaysCount`) : le tri actif/traité est à la charge de
    /// l'appelant sur `overtimeEntries` en amont.
    func workedDaysCount(in year: Int, overtimeEntries: [OvertimeEntry], calendar: Calendar = .current) -> Int {
        guard let employerID = employer?.id, let contractStart = startDate else { return 0 }
        let contractStartDay = calendar.startOfDay(for: contractStart)
        let contractEndDay = endDate.map { calendar.startOfDay(for: $0) }

        var workedDays: Set<DateComponents> = []
        for entry in overtimeEntries {
            guard entry.type == "sup", entry.employerID == employerID, let date = entry.date else { continue }
            guard calendar.component(.year, from: date) == year else { continue }
            let day = calendar.startOfDay(for: date)
            guard day >= contractStartDay else { continue }
            if let contractEndDay, day > contractEndDay { continue }
            workedDays.insert(calendar.dateComponents([.year, .month, .day], from: day))
        }
        return workedDays.count
    }
}
