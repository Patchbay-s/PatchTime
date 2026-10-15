import Foundation
import CoreData

/// Compte les jours travaillés (fiscal + statistiques) en tenant compte du rythme de la
/// Semaine type, sans énumérer les dates calendaires du gabarit — règle simplifiée basée
/// uniquement sur le jour de la semaine (weekday) d'une entrée réelle comparé au patron de
/// l'employeur concerné :
/// - Entrée réelle un jour de la semaine MARQUÉ TRAVAILLÉ dans la Semaine type de son
///   employeur → ce jour est déjà compté par `templateDaysCount` (l'agrégat du gabarit), donc
///   aucun +1 supplémentaire (éviterait un doublon) ; les heures restent comptées comme
///   toujours dans `AnnualSummary`/`FiscalSummary.totalHours`, inchangé par ce calculateur.
/// - Entrée réelle un jour de la semaine NON marqué travaillé dans le gabarit (ex: heures sup
///   un samedi alors que le rythme habituel est du lundi au vendredi) → +1 jour dans
///   `extraRealDaysCount`, comptabilisé à part comme jour supplémentaire réel au-delà du
///   rythme habituel.
/// - Employeur sans Semaine type active (ou entrée sans employeur résolvable) : comportement
///   inchangé, dédoublonnage global par date calendaire (même logique que
///   `FiscalDayCounts.workedDaysCount`).
/// - Jour couvert par une `LeaveEntry` (CP/Récup) : le CP/Récup prend le dessus sur le gabarit —
///   ce jour est retiré de `templateDaysCount` (voir `Contract.typicalWeekDaysExcludedByLeave`).
///   Cas limite : une entrée réelle "sup" tombant malgré tout sur ce jour-là n'est alors plus
///   couverte par le gabarit (qui l'exclut désormais) et bascule dans `extraRealDaysCount`
///   plutôt que d'être silencieusement absorbée.
/// Aucun filtre `archived` interne (en avait un par le passé, en dur dans le guard de la
/// boucle — pas même un paramètre : une entrée "sup" archivée hors gabarit ne comptait jamais
/// comme jour supplémentaire, quel que soit l'appelant, cause du bug "jours travaillés toujours
/// incorrect" une fois `StatisticsCalculator.monthlyNetHours`/`monthlyHoursForYear` corrigés).
/// Le tri actif/traité est entièrement à la charge de l'appelant sur `overtimeEntries` en amont.
enum TypicalWeekProjectionEstimator {
    struct Result {
        /// Jours "assumés" par le gabarit de Semaine type (agrégat, indépendant de toute date
        /// calendaire précise) — voir `Contract.typicalWeekWorkedDays(in:calendar:)`.
        let templateDaysCount: Int
        /// Jours réels au-delà du gabarit : entrées "sup" un jour de semaine hors pattern, ou
        /// entrées d'employeurs sans Semaine type active.
        let extraRealDaysCount: Int
        var totalDaysCount: Int { templateDaysCount + extraRealDaysCount }
    }

    static func estimate(
        year: Int,
        overtimeEntries: [OvertimeEntry],
        profiles: [OvertimeProfile],
        contracts: [Contract],
        leaveEntries: [LeaveEntry] = [],
        calendar: Calendar = .current
    ) -> Result {
        let profileEmployerMap: [UUID: Employer] = Dictionary(uniqueKeysWithValues:
            profiles.compactMap { p in
                guard let pid = p.id, let employer = p.employer else { return nil }
                return (pid, employer)
            }
        )

        var templateDaysTotal = 0.0
        for contract in contracts {
            let rawDays = contract.typicalWeekWorkedDays(in: year, calendar: calendar)
            let excludedDays = contract.typicalWeekDaysExcludedByLeave(in: year, leaveEntries: leaveEntries, calendar: calendar)
            templateDaysTotal += max(0, rawDays - Double(excludedDays))
        }

        var extraDatesByEmployer: [NSManagedObjectID: Set<DateComponents>] = [:]
        var noPatternDates: Set<DateComponents> = []

        for entry in overtimeEntries {
            guard entry.type == "sup", let date = entry.date else { continue }
            guard calendar.component(.year, from: date) == year else { continue }

            guard let employer = entry.profileID.flatMap({ profileEmployerMap[$0] }), employer.typicalWeekEnabled else {
                noPatternDates.insert(calendar.dateComponents([.year, .month, .day], from: date))
                continue
            }

            guard let weekday = Weekday.from(calendarWeekday: calendar.component(.weekday, from: date)) else { continue }

            let dayHasLeave = leaveEntries.contains { $0.coversDate(date, calendar: calendar) }
            if employer.isTypicalWeekWorked(weekday) && !dayHasLeave {
                continue // déjà compté via templateDaysTotal, pas de +1
            }
            extraDatesByEmployer[employer.objectID, default: []].insert(calendar.dateComponents([.year, .month, .day], from: date))
        }

        let extraRealDays = extraDatesByEmployer.values.reduce(0) { $0 + $1.count } + noPatternDates.count

        return Result(templateDaysCount: Int(templateDaysTotal.rounded()), extraRealDaysCount: extraRealDays)
    }
}
