import Foundation

/// Estimation frais km/repas à partir de la Semaine type de chaque employeur, plutôt que des
/// entrées réelles — mode alternatif explicite (`FiscalDaysSource.typicalWeek`), jamais mélangé
/// avec `FiscalDayCounts`/`KmExpenseEstimator`/`MealExpenseEstimator` (seule source pour le mode
/// "Heures saisies"). Somme par contrat (semaines actives × jours travaillés/semaine), sans
/// déduplication inter-employeurs par jour civil contrairement au mode entrées réelles : la
/// Semaine type n'a pas de date calendaire à laquelle rattacher un jour pour le dédupliquer —
/// deux employeurs actifs la même semaine avec chacun leur Semaine type génèrent chacun leurs
/// propres frais, ce qui reflète correctement deux trajets/repas distincts ce jour-là.
enum TypicalWeekExpenseEstimator {
    struct Result {
        let totalKm: Double
        let kmDeduction: Double
        let workedDaysCount: Int
        let mealDeduction: Double
    }

    static func estimate(
        year: Int,
        contracts: [Contract],
        leaveEntries: [LeaveEntry] = [],
        kmBareme: KmBareme,
        mealBareme: MealBareme,
        fiscalPower: Int,
        isElectric: Bool,
        calendar: Calendar = .current
    ) -> Result {
        var totalKm = 0.0
        var totalWorkedDays = 0.0

        for contract in contracts {
            let rawWorkedDays = contract.typicalWeekWorkedDays(in: year, calendar: calendar)
            guard rawWorkedDays > 0 else { continue }
            // Un jour de CP/Récup prend le dessus sur le statut "jour travaillé" projeté — ce
            // jour ne doit générer ni km ni repas estimés via la Semaine type.
            let excludedDays = contract.typicalWeekDaysExcludedByLeave(in: year, leaveEntries: leaveEntries, calendar: calendar)
            let contractWorkedDays = max(0, rawWorkedDays - Double(excludedDays))
            guard contractWorkedDays > 0 else { continue }

            let distance = contract.effectiveKmDistanceRoundTrip ?? 0

            totalWorkedDays += contractWorkedDays
            totalKm += contractWorkedDays * distance
        }

        let roundedWorkedDays = Int(totalWorkedDays.rounded())
        let kmDeduction = kmBareme.deduction(distanceKm: totalKm, fiscalPower: fiscalPower, isElectric: isElectric)
        let mealDeduction = MealExpenseEstimator.estimate(workedDaysCount: roundedWorkedDays, bareme: mealBareme)

        return Result(totalKm: totalKm, kmDeduction: kmDeduction, workedDaysCount: roundedWorkedDays, mealDeduction: mealDeduction)
    }
}
