import Foundation

enum FiscalRegime: String {
    case fraisReels
    case abattementForfaitaire
}

struct FiscalSummary {
    let year: Int
    let workedDaysCount: Int
    let congesPayesCount: Int
    let recuperationCount: Int
    let totalHours: Double
    let totalEarnings: Double
    let majoratedHoursCount: Double
    let majorationSurcharge: Double
    let kmTotalDistance: Double
    let kmDeduction: Double
    let mealDeduction: Double
    let totalFraisReels: Double
    let abattementForfaitaire: Double
    let recommendedRegime: FiscalRegime
    /// `false` quand `abattementForfaitaire` est basé sur `totalEarnings` (gains heures sup
    /// suivis par l'app, une base très partielle) faute de revenu net imposable saisi —
    /// dans ce cas `recommendedRegime` n'est pas une recommandation fiable, l'UI doit
    /// l'indiquer plutôt que d'afficher une conclusion catégorique.
    let incomeIsManual: Bool
    /// Source ayant produit `workedDaysCount`/`kmTotalDistance`/`kmDeduction`/`mealDeduction` —
    /// n'affecte jamais `totalHours`/`totalEarnings`/`majoratedHoursCount`/`majorationSurcharge`
    /// (toujours basés sur les entrées réelles, la Semaine type ne concerne que frais km/repas).
    let daysSource: FiscalDaysSource
    /// Jours "assumés" par le gabarit de Semaine type (agrégat) — 0 si `includeTypicalWeekDays`
    /// est resté à `false` (défaut) ou si aucun employeur n'a de Semaine type active. Distinct
    /// de `workedDaysCount`, jamais fusionné dedans (voir `TypicalWeekProjectionEstimator`).
    let typicalWeekTemplateDaysCount: Int
    /// Jours réels au-delà du gabarit (heures sup un jour hors pattern, ou employeur sans
    /// Semaine type) — comptabilisés séparément de `workedDaysCount`.
    let typicalWeekExtraDaysCount: Int
}

/// Combine tous les calculateurs V5 (heures/gains, majoration, frais km/repas, jours de
/// congés) en un seul bilan — aide à la déclaration, pas un conseil fiscal (voir le bandeau
/// de non-responsabilité affiché par `FiscalSummaryView`).
///
/// Ne filtre plus par `archived` en interne — même contrat que tous les calculateurs qu'il
/// combine (`AnnualReportCalculator`, `MajorationDetail`, `FiscalDayCounts`,
/// `Contract+WorkedDays`, `CombinedDaysEstimator`, `TypicalWeekProjectionEstimator`, tous déjà
/// corrigés pour ne plus avoir de filtre par défaut caché) : le tri actif/traité sur
/// `overtimeEntries` est entièrement à la charge de l'appelant. `FiscalSummaryView` (Bilan
/// fiscal, aucun réglage d'inclusion) filtre aux entrées actives avant l'appel, pour préserver
/// sa portée historique ; `StatisticsView` (bloc "Frais réels estimés") passe ses entrées déjà
/// scopées par le toggle "Inclure les entrées traitées dans les totaux", pour rester cohérent
/// avec le reste de l'écran.
enum FiscalReportCalculator {
    static func summary(
        year: Int,
        overtimeEntries: [OvertimeEntry],
        profiles: [OvertimeProfile],
        leaveEntries: [LeaveEntry],
        holidays: [PublicHoliday],
        contracts: [Contract],
        fiscalPower: Int,
        isElectric: Bool,
        kmBareme: KmBareme,
        mealBareme: MealBareme,
        manualNetIncome: Double?,
        daysSource: FiscalDaysSource = .actualEntries,
        includeTypicalWeekDays: Bool = false,
        calendar: Calendar = .current
    ) -> FiscalSummary {
        let annual = AnnualReportCalculator.summary(year: year, entries: overtimeEntries, profiles: profiles, holidays: holidays)

        let leaveEmployers = contracts.compactMap { $0.employer }
        let congesPayes = FiscalDayCounts.leaveDaysCount(year: year, leaveEntries: leaveEntries, type: .congePaye, employers: leaveEmployers, calendar: calendar)
        let recuperation = FiscalDayCounts.leaveDaysCount(year: year, leaveEntries: leaveEntries, type: .recuperation, employers: leaveEmployers, calendar: calendar)

        let profileMap: [UUID: OvertimeProfile] = Dictionary(uniqueKeysWithValues: profiles.compactMap { p in p.id.map { ($0, p) } })
        let majoration = MajorationDetail.compute(year: year, overtimeEntries: overtimeEntries, profileMap: profileMap, holidays: holidays, calendar: calendar)

        // Les deux sources restent des chemins de calcul entièrement séparés, jamais combinés
        // au sein d'un même bilan — voir FiscalDaysSource et TypicalWeekExpenseEstimator.
        let workedDays: Int
        let kmTotalDistance: Double
        let kmDeduction: Double
        let mealDeduction: Double

        switch daysSource {
        case .actualEntries:
            workedDays = FiscalDayCounts.workedDaysCount(year: year, overtimeEntries: overtimeEntries, calendar: calendar)
            let km = KmExpenseEstimator.estimate(
                year: year, contracts: contracts, overtimeEntries: overtimeEntries,
                bareme: kmBareme, fiscalPower: fiscalPower, isElectric: isElectric, calendar: calendar
            )
            kmTotalDistance = km.totalKm
            kmDeduction = km.deduction
            mealDeduction = MealExpenseEstimator.estimate(workedDaysCount: workedDays, bareme: mealBareme)
        case .typicalWeek:
            let typical = TypicalWeekExpenseEstimator.estimate(
                year: year, contracts: contracts, leaveEntries: leaveEntries, kmBareme: kmBareme, mealBareme: mealBareme,
                fiscalPower: fiscalPower, isElectric: isElectric, calendar: calendar
            )
            workedDays = typical.workedDaysCount
            kmTotalDistance = typical.totalKm
            kmDeduction = typical.kmDeduction
            mealDeduction = typical.mealDeduction
        case .combined:
            let combined = CombinedDaysEstimator.estimate(
                year: year, overtimeEntries: overtimeEntries, profiles: profiles, contracts: contracts,
                leaveEntries: leaveEntries, calendar: calendar
            )
            workedDays = combined.workedDaysCount
            kmTotalDistance = combined.totalKm
            kmDeduction = kmBareme.deduction(distanceKm: combined.totalKm, fiscalPower: fiscalPower, isElectric: isElectric)
            mealDeduction = MealExpenseEstimator.estimate(workedDaysCount: combined.workedDaysCount, bareme: mealBareme)
        }

        let totalFraisReels = kmDeduction + mealDeduction
        let revenueBase = manualNetIncome ?? annual.totalEarnings
        let abattement = revenueBase * 0.10
        let regime: FiscalRegime = totalFraisReels > abattement ? .fraisReels : .abattementForfaitaire

        let typicalWeekProjection = includeTypicalWeekDays
            ? TypicalWeekProjectionEstimator.estimate(year: year, overtimeEntries: overtimeEntries, profiles: profiles, contracts: contracts, leaveEntries: leaveEntries, calendar: calendar)
            : nil

        return FiscalSummary(
            year: year,
            workedDaysCount: workedDays,
            congesPayesCount: congesPayes,
            recuperationCount: recuperation,
            totalHours: annual.totalHours,
            totalEarnings: annual.totalEarnings,
            majoratedHoursCount: majoration.hoursCount,
            majorationSurcharge: majoration.surcharge,
            kmTotalDistance: kmTotalDistance,
            kmDeduction: kmDeduction,
            mealDeduction: mealDeduction,
            totalFraisReels: totalFraisReels,
            abattementForfaitaire: abattement,
            recommendedRegime: regime,
            incomeIsManual: manualNetIncome != nil,
            daysSource: daysSource,
            typicalWeekTemplateDaysCount: typicalWeekProjection?.templateDaysCount ?? 0,
            typicalWeekExtraDaysCount: typicalWeekProjection?.extraRealDaysCount ?? 0
        )
    }
}
