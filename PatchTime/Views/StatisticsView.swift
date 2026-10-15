import SwiftUI

struct StatisticsView: View {
    @AppStorage("currency") private var currency: String = "€"
    @AppStorage("vehicleFiscalPower") private var vehicleFiscalPower: Int = 5
    @AppStorage("vehicleMotorisation") private var vehicleMotorisation: String = "thermique"

    @AppStorage("statsShowTotalHours") private var showTotalHours = true
    @AppStorage("statsShowEmployerBreakdown") private var showEmployerBreakdown = true
    @AppStorage("statsShowMonthlyEvolution") private var showMonthlyEvolution = true
    @AppStorage("statsShowFiscalEstimate") private var showFiscalEstimate = true
    @AppStorage("statsShowMealsCount") private var showMealsCount = true
    @AppStorage("statsShowLeaveDaysCount") private var showLeaveDaysCount = true
    @AppStorage("statsShowArchivedHours") private var showArchivedHours = true

    @AppStorage("statsIncludeArchivedHoursInTotals") private var includeArchivedHoursInTotals = false

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \OvertimeEntry.date, ascending: true)])
    private var overtimeEntries: FetchedResults<OvertimeEntry>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \MealEntry.date, ascending: true)])
    private var mealEntries: FetchedResults<MealEntry>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \OvertimeProfile.name, ascending: true)])
    private var profiles: FetchedResults<OvertimeProfile>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \PublicHoliday.date, ascending: true)])
    private var holidays: FetchedResults<PublicHoliday>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \LeaveEntry.date, ascending: true)])
    private var leaveEntries: FetchedResults<LeaveEntry>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Employer.name, ascending: true)])
    private var employers: FetchedResults<Employer>

    @AppStorage("includeTypicalWeekDaysProjection") private var includeTypicalWeekProjection = false

    @State private var showPreferences = false

    private var currentYear: Int { Calendar.current.component(.year, from: Date()) }
    private var currentMonth: Int { Calendar.current.component(.month, from: Date()) }
    private var isElectric: Bool { vehicleMotorisation == "electrique" }

    private var allContracts: [Contract] {
        employers.flatMap { CoreDataManager.shared.fetchContracts(for: $0) }
    }

    /// Entrées d'heures sup soumises au filtre "Inclure les entrées traitées dans les totaux" —
    /// source commune à `annualSummary` (donc `totalHoursSection`/`employerBreakdownSection`),
    /// `monthlyEvolutionSection` et `fiscalSummary` (`fiscalEstimateSection`), pour que ces blocs
    /// restent cohérents entre eux plutôt que de répéter le même filtre par bloc (source du bug :
    /// "Évolution mensuelle", "Répartition par employeur" puis "Frais réels estimés" avaient été
    /// oubliés lors du premier câblage du filtre).
    private var scopedOvertimeEntries: [OvertimeEntry] {
        includeArchivedHoursInTotals ? Array(overtimeEntries) : overtimeEntries.filter { !$0.archived }
    }

    private var scopedMealEntries: [MealEntry] {
        includeArchivedHoursInTotals ? Array(mealEntries) : mealEntries.filter { !$0.archived }
    }

    private var annualSummary: AnnualSummary {
        AnnualReportCalculator.summary(year: currentYear, entries: scopedOvertimeEntries, profiles: Array(profiles), holidays: Array(holidays))
    }

    private var typicalWeekProjection: TypicalWeekProjectionEstimator.Result {
        TypicalWeekProjectionEstimator.estimate(year: currentYear, overtimeEntries: scopedOvertimeEntries, profiles: Array(profiles), contracts: allContracts, leaveEntries: Array(leaveEntries))
    }

    private var fiscalSummary: FiscalSummary {
        FiscalReportCalculator.summary(
            year: currentYear,
            overtimeEntries: scopedOvertimeEntries,
            profiles: Array(profiles),
            leaveEntries: Array(leaveEntries),
            holidays: Array(holidays),
            contracts: allContracts,
            fiscalPower: vehicleFiscalPower,
            isElectric: isElectric,
            kmBareme: BaremeStore.kmBareme,
            mealBareme: BaremeStore.mealBareme,
            manualNetIncome: FiscalIncomeStore.value(forYear: currentYear),
            daysSource: FiscalDaysSourceStore.value(forYear: currentYear)
        )
    }

    private func formattedHours(_ hours: Double) -> String {
        String(format: "%.1fh", hours)
    }

    // MARK: - Blocks

    private var archivedOvertimeEntries: [OvertimeEntry] {
        overtimeEntries.filter { $0.archived }
    }

    private var monthlyArchivedHours: Double {
        StatisticsCalculator.monthlyNetHours(overtimeEntries: archivedOvertimeEntries, year: currentYear, month: currentMonth, profiles: Array(profiles), holidays: Array(holidays))
    }

    private var annualArchivedHours: Double {
        StatisticsCalculator.monthlyHoursForYear(overtimeEntries: archivedOvertimeEntries, year: currentYear, profiles: Array(profiles), holidays: Array(holidays))
            .reduce(0.0) { $0 + $1.hours }
    }

    @ViewBuilder
    private var totalHoursSection: some View {
        Section(header: Text("Heures travaillées")) {
            LabeledContent("Ce mois") {
                Text(formattedHours(StatisticsCalculator.monthlyNetHours(overtimeEntries: scopedOvertimeEntries, year: currentYear, month: currentMonth, profiles: Array(profiles), holidays: Array(holidays))))
            }
            LabeledContent("Cette année") {
                Text(formattedHours(annualSummary.totalHours))
            }
            if includeTypicalWeekProjection {
                LabeledContent("Jours travaillés (dont Semaine type)") {
                    Text("\(typicalWeekProjection.totalDaysCount)")
                }
                if typicalWeekProjection.extraRealDaysCount > 0 {
                    LabeledContent("dont jours sup au-delà du rythme habituel") {
                        Text("\(typicalWeekProjection.extraRealDaysCount)").foregroundColor(.orange)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var archivedHoursSection: some View {
        Section(header: Text("Heures traitées"), footer: Text("Entrées déjà saisies en comptabilité — distinctes des heures actives ci-dessus, jamais mélangées sauf si le filtre \"Inclure les entrées traitées dans les totaux\" est activé.")) {
            LabeledContent("Ce mois") {
                Text(formattedHours(monthlyArchivedHours))
            }
            LabeledContent("Cette année") {
                Text(formattedHours(annualArchivedHours))
            }
        }
    }

    @ViewBuilder
    private var employerBreakdownSection: some View {
        if !annualSummary.employerBreakdown.isEmpty {
            Section(header: Text("Répartition par employeur (année)")) {
                ForEach(annualSummary.employerBreakdown) { breakdown in
                    LabeledContent(breakdown.displayName) {
                        Text(formattedHours(breakdown.hours))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var monthlyEvolutionSection: some View {
        Section(header: Text("Évolution mensuelle (année)")) {
            let months = StatisticsCalculator.monthlyHoursForYear(overtimeEntries: scopedOvertimeEntries, year: currentYear, profiles: Array(profiles), holidays: Array(holidays))
            let maxValue = max(months.map { abs($0.hours) }.max() ?? 1, 1)
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(months) { entry in
                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(entry.hours >= 0 ? Color.blue.opacity(0.7) : Color.orange.opacity(0.7))
                            .frame(height: max(4, CGFloat(abs(entry.hours) / maxValue) * 80))
                        Text(monthAbbreviation(entry.month))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var fiscalEstimateSection: some View {
        Section(header: Text("Frais réels estimés (année)"), footer: Text("Estimation, voir le Bilan fiscal pour le détail complet.")) {
            LabeledContent("Total") {
                Text(formattedCurrency(fiscalSummary.totalFraisReels, currency: currency))
                    .fontWeight(.semibold)
            }
        }
    }

    @ViewBuilder
    private var mealsCountSection: some View {
        Section(header: Text("Repas")) {
            LabeledContent("Ce mois") {
                Text("\(StatisticsCalculator.mealsCount(mealEntries: scopedMealEntries, year: currentYear, month: currentMonth))")
            }
            LabeledContent("Cette année") {
                Text("\(StatisticsCalculator.mealsCount(mealEntries: scopedMealEntries, year: currentYear))")
            }
        }
    }

    @ViewBuilder
    private var leaveDaysCountSection: some View {
        Section(header: Text("Congés & récup (année)")) {
            LabeledContent("Congés payés") {
                Text("\(FiscalDayCounts.leaveDaysCount(year: currentYear, leaveEntries: Array(leaveEntries), type: .congePaye, employers: Array(employers)))")
            }
            LabeledContent("Récupération") {
                Text("\(FiscalDayCounts.leaveDaysCount(year: currentYear, leaveEntries: Array(leaveEntries), type: .recuperation, employers: Array(employers)))")
            }
        }
    }

    @ViewBuilder
    private var preferencesSection: some View {
        Section(header: Text("Blocs affichés"), footer: Text("Activez ou désactivez chaque bloc individuellement.")) {
            Toggle("Heures travaillées", isOn: $showTotalHours)
            Toggle("Répartition par employeur", isOn: $showEmployerBreakdown)
            Toggle("Évolution mensuelle", isOn: $showMonthlyEvolution)
            Toggle("Frais réels estimés", isOn: $showFiscalEstimate)
            Toggle("Repas", isOn: $showMealsCount)
            Toggle("Congés & récup", isOn: $showLeaveDaysCount)
            Toggle("Heures traitées", isOn: $showArchivedHours)
        }
        Section(
            header: Text("Filtres"),
            footer: Text("Options d'inclusion de données dans les totaux affichés — désactivées par défaut.")
        ) {
            Toggle("Inclure la projection Semaine type", isOn: $includeTypicalWeekProjection)
            Toggle("Inclure les entrées traitées dans les totaux", isOn: $includeArchivedHoursInTotals)
        }
    }

    private var formContent: some View {
        Form {
            if showPreferences { preferencesSection }
            if showTotalHours { totalHoursSection }
            if showEmployerBreakdown { employerBreakdownSection }
            if showMonthlyEvolution { monthlyEvolutionSection }
            if showFiscalEstimate { fiscalEstimateSection }
            if showMealsCount { mealsCountSection }
            if showLeaveDaysCount { leaveDaysCountSection }
            if showArchivedHours { archivedHoursSection }
        }
        .navigationTitle("Statistiques")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                ToolbarDisclosureButton(
                    isExpanded: $showPreferences,
                    systemImage: "slider.horizontal.3",
                    expandedLabel: "Masquer les réglages d'affichage",
                    collapsedLabel: "Personnaliser les blocs affichés"
                )
            }
        }
    }

    var body: some View {
        NavigationStack {
            formContent
        }
    }

    private func monthAbbreviation(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        let symbol = formatter.shortStandaloneMonthSymbols[max(0, min(11, month - 1))]
        return String(symbol.prefix(1)).uppercased()
    }
}

#Preview {
    StatisticsView()
        .environment(\.managedObjectContext, CoreDataManager.shared.container.viewContext)
}
