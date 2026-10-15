import SwiftUI
import Foundation
import CoreData

// MARK: - ContentView
struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("currency") private var currency: String = Currency.euro.rawValue
    @AppStorage("defaultProfileId") private var defaultProfileId: String = ""
    @State private var showingAddOvertimeSheet = false
    @State private var showingAddMealSheet = false
    @State private var showingAddLeaveSheet = false
    @AppStorage("displayPeriod") private var displayPeriod: String = DisplayPeriod.all.rawValue

    // archived == NO : aucun des usages de HomeView (résumé, stats du mois, graphique
    // hebdomadaire) n'a besoin des entrées déjà traitées.
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \OvertimeEntry.date, ascending: false)],
        predicate: NSPredicate(format: "archived == NO"),
        animation: .default)
    var overtimeEntries: FetchedResults<OvertimeEntry>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MealEntry.date, ascending: false)],
        predicate: NSPredicate(format: "archived == NO"),
        animation: .default)
    var mealEntries: FetchedResults<MealEntry>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \OvertimeProfile.name, ascending: true)],
        animation: .default)
    private var overtimeProfiles: FetchedResults<OvertimeProfile>

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                // Onglet Accueil
                NavigationStack {
                    HomeView(
                        overtimeEntries: overtimeEntries,
                        mealEntries: mealEntries,
                        displayPeriod: displayPeriod,
                        currency: currency,
                        showingAddOvertimeSheet: $showingAddOvertimeSheet,
                        showingAddMealSheet: $showingAddMealSheet,
                        showingAddLeaveSheet: $showingAddLeaveSheet,
                        defaultProfileId: $defaultProfileId,
                        overtimeProfiles: overtimeProfiles
                    )
                    .environment(\.managedObjectContext, viewContext)
                }
                .readableContentWidth(820)
                .tabItem {
                    Label("Accueil", systemImage: "house.fill")
                }

                // Onglet Heures Sup — inclut désormais Repas via un sélecteur segmenté
                // (Chantier 6), l'onglet Repas dédié a été retiré de la tab bar.
                OvertimeListView()
                .readableContentWidth()
                .tabItem {
                    Label("Heures Sup", systemImage: "hourglass")
                }

                // Onglet Calendrier
                NavigationStack {
                    CalendarView(
                        overtimeProfiles: Array(overtimeProfiles),
                        currency: currency
                    )
                }
                .tabItem {
                    Label("Calendrier", systemImage: "calendar")
                }

                // Onglet Statistiques — occupe l'emplacement libéré par la fusion Heures Sup/Repas.
                StatisticsView()
                .readableContentWidth(820)
                .tabItem {
                    Label("Statistiques", systemImage: "chart.bar.fill")
                }

                // Onglet Réglages
                NavigationStack {
                    SettingsView()
                }
                // Largeur de lecture pour Réglages et tous les écrans poussés depuis cet onglet.
                .readableContentWidth()
                .tabItem {
                    Label("Réglages", systemImage: "gear")
                }
            }
            .sheet(isPresented: $showingAddOvertimeSheet) {
                AddOvertimeView()
            }
            .sheet(isPresented: $showingAddMealSheet) {
                AddMealView()
            }
            .sheet(isPresented: $showingAddLeaveSheet) {
                AddLeaveEntryView()
            }
        }
    }
}

// MARK: - HomeView
struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    let overtimeEntries: FetchedResults<OvertimeEntry>
    let mealEntries: FetchedResults<MealEntry>
    let displayPeriod: String
    let currency: String
    @Binding var showingAddOvertimeSheet: Bool
    @Binding var showingAddMealSheet: Bool
    @Binding var showingAddLeaveSheet: Bool
    @Binding var defaultProfileId: String
    let overtimeProfiles: FetchedResults<OvertimeProfile>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Employer.name, ascending: true)],
        animation: .default)
    private var employers: FetchedResults<Employer>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \PublicHoliday.date, ascending: true)],
        animation: .default)
    private var holidays: FetchedResults<PublicHoliday>

    @State private var selectedEmployer: Employer? = nil
    
    var filteredOvertimeEntries: [OvertimeEntry] {
        let period = DisplayPeriod(rawValue: displayPeriod) ?? .all
        let customStart = UserDefaults.standard.object(forKey: "customStartDate") as? Date ?? Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        let customEnd = UserDefaults.standard.object(forKey: "customEndDate") as? Date ?? Date()

        // archived == NO déjà appliqué au niveau du @FetchRequest de ContentView.
        var filtered = overtimeEntries.filter { entry in
            guard let date = entry.date else { return false }
            return FilterHelper.isDate(date, in: period, customStart: customStart, customEnd: customEnd)
        }

        if let employer = selectedEmployer {
            let profileIDs = Set(overtimeProfiles.filter { $0.employer == employer }.compactMap { $0.id })
            filtered = filtered.filter { entry in
                guard let pid = entry.profileID else { return false }
                return profileIDs.contains(pid)
            }
        } else if !defaultProfileId.isEmpty {
            if let defaultProfile = overtimeProfiles.first(where: { $0.id?.uuidString == defaultProfileId }) {
                filtered = filtered.filter { $0.profileID == defaultProfile.id }
            }
        }

        return filtered
    }

    var filteredMealEntries: [MealEntry] {
        let period = DisplayPeriod(rawValue: displayPeriod) ?? .all
        let customStart = UserDefaults.standard.object(forKey: "customStartDate") as? Date ?? Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        let customEnd = UserDefaults.standard.object(forKey: "customEndDate") as? Date ?? Date()

        var filtered = mealEntries.filter { entry in
            guard let date = entry.date else { return false }
            return FilterHelper.isDate(date, in: period, customStart: customStart, customEnd: customEnd)
        }

        if let employer = selectedEmployer {
            filtered = filtered.filter { $0.employerID == employer.id }
        } else if !defaultProfileId.isEmpty,
                  let defaultProfile = overtimeProfiles.first(where: { $0.id?.uuidString == defaultProfileId }),
                  let employerID = defaultProfile.employer?.id {
            filtered = filtered.filter { $0.employerID == employerID }
        }
        return filtered
    }
    
    private var summaryStats: (hours: Double, earnings: Double, meals: Int) {
        var totalHours = 0.0
        var totalEarnings = 0.0

        for entry in filteredOvertimeEntries {
            guard let start = entry.startTime,
                  let end = entry.endTime,
                  let profileId = entry.profileID else { continue }

            if let profile = overtimeProfiles.first(where: { $0.id == profileId }) {
                let hours = end.timeIntervalSince(start) / 3600
                let rate = ReportRowCalculator.bestEffortRate(for: profile)
                if entry.type == "recup" {
                    totalHours -= hours
                    totalEarnings -= hours * rate
                } else {
                    let multiplier = OvertimeSurcharge.multiplier(for: entry, profile: profile, holidays: Array(holidays))
                    totalHours += hours
                    totalEarnings += hours * rate * multiplier
                }
            }
        }

        let meals = filteredMealEntries.count
        return (totalHours, totalEarnings, meals)
    }
    
    var nonValidatedCount: Int {
        filteredOvertimeEntries.filter { entry in
            !(entry.value(forKey: "isValidated") as? Bool ?? false)
        }.count
    }

    private var monthStats: (hours: Double, earnings: Double, nonValidated: Int, meals: Int) {
        let currentMonthEntries = overtimeEntries.filter { entry in
            guard let date = entry.date else { return false }
            return Calendar.current.isDate(date, equalTo: Date(), toGranularity: .month)
        }
        let currentMonthMeals = mealEntries.filter { entry in
            guard let date = entry.date else { return false }
            return Calendar.current.isDate(date, equalTo: Date(), toGranularity: .month)
        }

        var totalHours = 0.0
        var totalEarnings = 0.0
        var toValidate = 0

        for entry in currentMonthEntries {
            guard let start = entry.startTime, let end = entry.endTime else { continue }
            let hours = overtimeDuration(from: start, to: end) / 3600
            let profile = overtimeProfiles.first(where: { $0.id == entry.profileID })
            let rate = ReportRowCalculator.bestEffortRate(for: profile)
            if entry.type == "recup" {
                totalHours -= hours
                totalEarnings -= hours * rate
            } else {
                let multiplier = OvertimeSurcharge.multiplier(for: entry, profile: profile, holidays: Array(holidays))
                totalHours += hours
                totalEarnings += hours * rate * multiplier
            }
            if !(entry.value(forKey: "isValidated") as? Bool ?? false) {
                toValidate += 1
            }
        }

        return (totalHours, totalEarnings, toValidate, currentMonthMeals.count)
    }

    private var weeklyBars: [(label: String, hours: Double)] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        var data: [(String, Double)] = []
        for offset in (0...6).reversed() {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: startOfToday) else { continue }
            let label = SharedFormatters.frenchDayAbbrev.string(from: day).prefix(1).uppercased()

            let dayEntries = overtimeEntries.filter { entry in
                guard let date = entry.date else { return false }
                return calendar.isDate(date, inSameDayAs: day)
            }

            let total = dayEntries.reduce(0.0) { partial, entry in
                guard let start = entry.startTime, let end = entry.endTime else { return partial }
                let value = overtimeDuration(from: start, to: end) / 3600
                return partial + (entry.type == "recup" ? -value : value)
            }
            data.append((String(label), max(0, total)))
        }
        return data
    }

    /// Mars à mai : période typique de déclaration (revenus, France Travail...) où le bilan
    /// annuel est particulièrement pertinent.
    private var isDeclarationSeason: Bool {
        (3...5).contains(Calendar.current.component(.month, from: Date()))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                QuickActionsSection(
                    showingAddOvertimeSheet: $showingAddOvertimeSheet,
                    showingAddMealSheet: $showingAddMealSheet,
                    showingAddLeaveSheet: $showingAddLeaveSheet
                )

                // Ligne avec le nombre d'heures restantes à valider — remontée juste après les
                // actions rapides pour rester visible sans scroll (info la plus actionnable).
                if nonValidatedCount > 0 {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                        Text("Il reste \(nonValidatedCount) heure\(nonValidatedCount > 1 ? "s" : "") à valider")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.red.opacity(0.1))
                    )
                    .padding(.horizontal)
                }

                // Raccourci saisonnier (mars-mai, période de déclaration) vers le bilan annuel.
                if isDeclarationSeason {
                    NavigationLink(destination: AnnualSummaryView()) {
                        HStack {
                            Image(systemName: "doc.text.magnifyingglass")
                                .foregroundColor(.accentColor)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Période de déclaration")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.primary)
                                Text("Consultez votre bilan annuel")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.accentColor.opacity(0.08))
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }

                SummaryCard(
                    displayPeriod: displayPeriod,
                    summaryStats: summaryStats,
                    currency: currency
                )

                MonthlySummaryCard(stats: monthStats, currency: currency)
                WeeklyHoursChart(data: weeklyBars)

                if !employers.isEmpty {
                    Picker("Employeur", selection: $selectedEmployer) {
                        Text("Tous les employeurs").tag(Optional<Employer>.none)
                        ForEach(employers) { employer in
                            Label(employer.name ?? "", systemImage: "building.2")
                                .tag(Optional(employer))
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal)
                }

                Picker("Filtrer par Profil", selection: $defaultProfileId) {
                    Text("Tous les profils").tag("")
                    ForEach(overtimeProfiles) { profile in
                        Text(profile.name ?? "").tag(profile.id?.uuidString ?? "")
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal)
                
            }
        }
        .navigationTitle("Accueil")
    }
}

struct MonthlySummaryCard: View {
    let stats: (hours: Double, earnings: Double, nonValidated: Int, meals: Int)
    let currency: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ce mois")
                .font(.headline)
            HStack {
                Text("Heures nettes")
                Spacer()
                Text(String(format: "%.1f h", stats.hours)).bold()
            }
            HStack {
                Text("€ net")
                Spacer()
                Text(formattedCurrency(stats.earnings, currency: currency)).bold()
            }
            HStack {
                Text("Heures à valider")
                Spacer()
                Text("\(stats.nonValidated)").bold()
            }
            HStack {
                Text("Repas")
                Spacer()
                Text("\(stats.meals)").bold()
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.1)))
        .padding(.horizontal)
    }
}

struct WeeklyHoursChart: View {
    let data: [(label: String, hours: Double)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("7 derniers jours")
                .font(.headline)
            let maxValue = max(data.map(\.hours).max() ?? 1, 1)
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(data.enumerated()), id: \.offset) { _, item in
                    VStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.blue.opacity(0.7))
                            .frame(height: max(6, CGFloat(item.hours / maxValue) * 70))
                        Text(item.label)
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.08)))
        .padding(.horizontal)
    }
}

// MARK: - SummaryCard
struct SummaryCard: View {
    let displayPeriod: String
    let summaryStats: (hours: Double, earnings: Double, meals: Int)
    let currency: String
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Période : " + (DisplayPeriod(rawValue: displayPeriod)?.rawValue ?? "la période"))
                .font(.title2)
                .padding(.top)
                .foregroundColor(.accentColor)

            VStack(spacing: 20) {
                // Heures supplémentaires
                VStack(alignment: .center, spacing: 5) {
                    Text(String(format: "%.1f", summaryStats.hours))
                        .font(.title)
                        .foregroundColor(.blue)
                    Text("heures nettes")
                        .font(.caption)
                        .foregroundColor(.blue.opacity(0.7))
                    Text(formattedCurrency(summaryStats.earnings, currency: currency))
                        .font(.headline)
                        .foregroundColor(.green)
                }
                
                Divider().background(Color.blue.opacity(0.5))
                
                // Repas
                VStack(alignment: .center, spacing: 5) {
                    Text("\(summaryStats.meals)")
                        .font(.title)
                        .foregroundColor(.primary)
                    Text("repas")
                        .font(.caption)
                        .foregroundColor(.green.opacity(0.7))
                }
            }
            .padding()
            .background(
                LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.10), Color.gray.opacity(0.08)]), startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .cornerRadius(18)
            .shadow(color: Color.blue.opacity(0.08), radius: 8, x: 0, y: 4)
        }
        .padding(.horizontal)
    }
}

// MARK: - QuickActionsSection
struct QuickActionsSection: View {
    @Binding var showingAddOvertimeSheet: Bool
    @Binding var showingAddMealSheet: Bool
    @Binding var showingAddLeaveSheet: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Actions rapides")
                .font(.title2)
                .padding(.horizontal)
                .foregroundColor(.accentColor)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    quickBubble(title: "Heures sup", icon: "clock.fill", color: .blue) {
                        showingAddOvertimeSheet = true
                    }
                    quickBubble(title: "Repas", icon: "fork.knife", color: .green) {
                        showingAddMealSheet = true
                    }
                    quickBubble(title: "CP/Récup", icon: "calendar.badge.minus", color: .brown) {
                        showingAddLeaveSheet = true
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private func quickBubble(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .buttonStyle(.borderedProminent)
        .tint(color)
    }
}
