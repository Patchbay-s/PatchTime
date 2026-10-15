import Foundation

/// Mode "Combiner les 2" du Bilan fiscal (`FiscalDaysSource.combined`) : applique la même règle
/// de priorité que partout ailleurs dans l'app (entrée réelle prime, Semaine type comble les
/// jours non couverts, pas de double-comptage) plutôt que de forcer un choix exclusif entre
/// "Heures saisies" et "Semaine type". Réutilise `TypicalWeekProjectionEstimator` (déjà
/// testé pour cette règle) une fois par contrat, avec les entrées/profils restreints à
/// l'employeur de ce contrat — sans ce filtrage, appeler l'estimateur plusieurs fois
/// compterait les entrées des autres employeurs à chaque itération.
enum CombinedDaysEstimator {
    struct Result {
        let workedDaysCount: Int
        let totalKm: Double
    }

    static func estimate(
        year: Int,
        overtimeEntries: [OvertimeEntry],
        profiles: [OvertimeProfile],
        contracts: [Contract],
        leaveEntries: [LeaveEntry],
        calendar: Calendar = .current
    ) -> Result {
        var totalDays = 0
        var totalKm = 0.0
        var assignedProfileIDs: Set<UUID> = []

        for contract in contracts {
            guard let employer = contract.employer else { continue }
            let employerProfiles = profiles.filter { $0.employer == employer }
            assignedProfileIDs.formUnion(employerProfiles.compactMap { $0.id })
            let employerProfileIDs = Set(employerProfiles.compactMap { $0.id })
            let employerEntries = overtimeEntries.filter { entry in
                guard let pid = entry.profileID else { return false }
                return employerProfileIDs.contains(pid)
            }

            let projection = TypicalWeekProjectionEstimator.estimate(
                year: year, overtimeEntries: employerEntries, profiles: employerProfiles,
                contracts: [contract], leaveEntries: leaveEntries, calendar: calendar
            )
            totalDays += projection.totalDaysCount
            if let distance = contract.effectiveKmDistanceRoundTrip {
                totalKm += distance * Double(projection.totalDaysCount)
            }
        }

        // Entrées sans profil assigné à un employeur ayant un contrat : pas de gabarit possible
        // (pas de contrat = pas de distance de trajet), donc traitées comme le mode "Heures
        // saisies" pour le seul comptage de jours — aucune distance ajoutée.
        let unassignedEntries = overtimeEntries.filter { entry in
            guard let pid = entry.profileID else { return true }
            return !assignedProfileIDs.contains(pid)
        }
        if !unassignedEntries.isEmpty {
            totalDays += FiscalDayCounts.workedDaysCount(year: year, overtimeEntries: unassignedEntries, calendar: calendar)
        }

        return Result(workedDaysCount: totalDays, totalKm: totalKm)
    }
}
