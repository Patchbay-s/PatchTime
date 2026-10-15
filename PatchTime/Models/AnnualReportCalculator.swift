import Foundation
import CoreData

struct AnnualEmployerBreakdown: Identifiable {
    let employer: Employer?   // nil = "Sans employeur affecté"
    let hours: Double         // signé : négatif si récupérations nettes
    let earnings: Double      // signé
    let entryCount: Int

    var id: NSManagedObjectID? { employer?.objectID }
    var displayName: String { employer?.name ?? "Sans employeur affecté" }
}

struct AnnualSummary {
    let year: Int
    let totalHours: Double
    let totalEarnings: Double
    let workedDaysCount: Int
    let entryCount: Int
    let employerBreakdown: [AnnualEmployerBreakdown]
}

/// Mode d'affichage du Bilan annuel (`AnnualSummaryView`) — `isValidated` et `archived` ne sont
/// pas synchronisés à sens unique : archiver force `isValidated = true`, donc
/// `.validatedAndArchived` (intersection stricte) équivaut à "archivées uniquement", tandis que
/// `.complete` (l'un ou l'autre) équivaut à "toutes les entrées validées" — un sur-ensemble qui
/// inclut aussi les entrées validées mais pas encore archivées. Les deux modes sont donc bien
/// distincts et observables dans les données (validée-et-active est un état réel et courant :
/// heures sup approuvées mais pas encore saisies en compta).
enum AnnualReportValidationMode {
    case validatedAndArchived
    case complete
}

/// Calcule le bilan annuel à partir des mêmes données et de la même formule de gains que
/// ReportRowCalculator (utilisée par CSVExporter et PDFGenerator) — pas de 3e réimplémentation
/// du calcul des montants.
enum AnnualReportCalculator {
    /// `validationMode` à `nil` (défaut, utilisé par StatisticsView) n'applique **aucun** filtre
    /// archived/validé supplémentaire — le tri actif/traité est entièrement à la charge de
    /// l'appelant sur `entries` en amont (même principe que `StatisticsCalculator`/
    /// `TypicalWeekProjectionEstimator`, déjà corrigés pour la même classe de bug : un filtre
    /// interne par défaut, ici `!entry.archived`, qui ignorait silencieusement le pré-filtrage
    /// déjà fait par l'appelant — voir "Répartition par employeur exclut les heures traitées").
    /// Un mode explicite (utilisé par AnnualSummaryView) applique le filtre validée/traitée
    /// décrit ci-dessus à la place, ce qui exclut aussi les entrées "à valider".
    static func summary(
        year: Int,
        entries: [OvertimeEntry],
        profiles: [OvertimeProfile],
        holidays: [PublicHoliday],
        validationMode: AnnualReportValidationMode? = nil
    ) -> AnnualSummary {
        let calendar = Calendar.current

        let yearEntries = entries.filter { entry in
            guard let date = entry.date, calendar.component(.year, from: date) == year else { return false }
            guard let validationMode else { return true }
            let isValidated = entry.value(forKey: "isValidated") as? Bool ?? false
            switch validationMode {
            case .validatedAndArchived: return isValidated && entry.archived
            case .complete: return isValidated || entry.archived
            }
        }

        let rateMap: [UUID: Double] = Dictionary(uniqueKeysWithValues:
            profiles.compactMap { p in p.id.map { ($0, ReportRowCalculator.bestEffortRate(for: p)) } }
        )
        let profileByID: [UUID: OvertimeProfile] = Dictionary(uniqueKeysWithValues:
            profiles.compactMap { p in p.id.map { ($0, p) } }
        )
        let profileEmployerMap: [UUID: Employer] = Dictionary(uniqueKeysWithValues:
            profiles.compactMap { p in
                guard let pid = p.id, let employer = p.employer else { return nil }
                return (pid, employer)
            }
        )

        var totalHours = 0.0
        var totalEarnings = 0.0
        var workedDays: Set<DateComponents> = []
        var byEmployer: [NSManagedObjectID: (employer: Employer, hours: Double, earnings: Double, count: Int)] = [:]
        var unassigned = (hours: 0.0, earnings: 0.0, count: 0)

        for entry in yearEntries {
            guard let start = entry.startTime, let end = entry.endTime else { continue }
            let rawHours = end.timeIntervalSince(start) / 3600
            let isRecup = entry.type == "recup"
            let rate = entry.profileID.flatMap { rateMap[$0] } ?? 0
            let profile = entry.profileID.flatMap { profileByID[$0] }
            let multiplier = isRecup ? 1.0 : OvertimeSurcharge.multiplier(for: entry, profile: profile, holidays: holidays)
            let earnings = ReportRowCalculator.computeEarnings(hours: rawHours, rate: rate * multiplier, isRecup: isRecup)
            let signedHours = isRecup ? -rawHours : rawHours

            totalHours += signedHours
            totalEarnings += earnings
            if let date = entry.date {
                workedDays.insert(calendar.dateComponents([.year, .month, .day], from: date))
            }

            if let pid = entry.profileID, let employer = profileEmployerMap[pid] {
                var current = byEmployer[employer.objectID] ?? (employer, 0, 0, 0)
                current.hours += signedHours
                current.earnings += earnings
                current.count += 1
                byEmployer[employer.objectID] = current
            } else {
                unassigned.hours += signedHours
                unassigned.earnings += earnings
                unassigned.count += 1
            }
        }

        var breakdown = byEmployer.values
            .map { AnnualEmployerBreakdown(employer: $0.employer, hours: $0.hours, earnings: $0.earnings, entryCount: $0.count) }
            .sorted { ($0.employer?.name ?? "") < ($1.employer?.name ?? "") }

        if unassigned.count > 0 {
            breakdown.append(AnnualEmployerBreakdown(employer: nil, hours: unassigned.hours, earnings: unassigned.earnings, entryCount: unassigned.count))
        }

        return AnnualSummary(
            year: year,
            totalHours: totalHours,
            totalEarnings: totalEarnings,
            workedDaysCount: workedDays.count,
            entryCount: yearEntries.count,
            employerBreakdown: breakdown
        )
    }
}
