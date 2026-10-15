import SwiftUI
import CoreData

struct ConsolidatedReportView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("currency") private var currency: String = "€"

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \OvertimeEntry.date, ascending: true)]
    ) private var allEntries: FetchedResults<OvertimeEntry>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MealEntry.date, ascending: true)]
    ) private var allMeals: FetchedResults<MealEntry>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Employer.name, ascending: true)]
    ) private var employers: FetchedResults<Employer>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \OvertimeProfile.name, ascending: true)]
    ) private var profiles: FetchedResults<OvertimeProfile>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \PublicHoliday.date, ascending: true)]
    ) private var holidays: FetchedResults<PublicHoliday>

    @State private var selectedMonth: Date = {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
    }()
    @State private var selectedEmployer: Employer? = nil
    /// Même pattern que OvertimeListView (Toggle "Afficher les entrées traitées") — la vue
    /// consolidée ne montrait jusqu'ici que les entrées actives, laissant les heures sup et
    /// repas déjà traités/archivés absents du récapitulatif comptable.
    @State private var showArchived = false

    private var calendar: Calendar { Calendar.current }

    private var monthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth)) ?? selectedMonth
    }
    private var monthEnd: Date {
        calendar.date(byAdding: DateComponents(month: 1, second: -1), to: monthStart) ?? monthStart
    }

    private var monthEntries: [OvertimeEntry] {
        allEntries.filter { entry in
            guard let date = entry.date, date >= monthStart, date <= monthEnd else { return false }
            return showArchived || !entry.archived
        }
    }

    private var monthMeals: [MealEntry] {
        allMeals.filter { meal in
            guard let date = meal.date, date >= monthStart, date <= monthEnd else { return false }
            return showArchived || !meal.archived
        }
    }

    private var profileMap: [UUID: OvertimeProfile] {
        Dictionary(uniqueKeysWithValues: profiles.compactMap { p in p.id.map { ($0, p) } })
    }

    private func profileIDs(for employer: Employer) -> Set<UUID> {
        Set(profiles.filter { $0.employer == employer }.compactMap { $0.id })
    }

    private func entries(for employer: Employer) -> [OvertimeEntry] {
        let ids = profileIDs(for: employer)
        return monthEntries.filter { entry in
            guard let pid = entry.profileID else { return false }
            return ids.contains(pid)
        }
    }

    private func meals(for employer: Employer) -> [MealEntry] {
        guard let employerID = employer.id else { return [] }
        return monthMeals.filter { $0.employerID == employerID }
    }

    private var unassignedEntries: [OvertimeEntry] {
        let assignedIDs = Set(profiles.filter { $0.employer != nil }.compactMap { $0.id })
        return monthEntries.filter { entry in
            guard let pid = entry.profileID else { return true }
            return !assignedIDs.contains(pid)
        }
    }

    private var unassignedMeals: [MealEntry] {
        let assignedEmployerIDs = Set(employers.compactMap { $0.id })
        return monthMeals.filter { meal in
            guard let employerID = meal.employerID else { return true }
            return !assignedEmployerIDs.contains(employerID)
        }
    }

    /// Calculée une seule fois par render et réutilisée pour `activeEmployers` et pour les
    /// sections par employeur, plutôt que de refaire `entries(for:)` deux fois par employeur.
    private var entriesByEmployer: [Employer: [OvertimeEntry]] {
        Dictionary(uniqueKeysWithValues: employers.map { ($0, entries(for: $0)) })
    }

    private var mealsByEmployer: [Employer: [MealEntry]] {
        Dictionary(uniqueKeysWithValues: employers.map { ($0, meals(for: $0)) })
    }

    private var displayedEntries: [OvertimeEntry] {
        guard let employer = selectedEmployer else { return monthEntries }
        return entries(for: employer)
    }

    private var displayedMeals: [MealEntry] {
        guard let employer = selectedEmployer else { return monthMeals }
        return meals(for: employer)
    }

    private func totalHours(for entries: [OvertimeEntry]) -> Double {
        entries.reduce(0.0) { sum, entry in
            guard let s = entry.startTime, let e = entry.endTime else { return sum }
            let h = e.timeIntervalSince(s) / 3600
            return entry.type == "recup" ? sum - h : sum + h
        }
    }

    private func totalEarnings(for entries: [OvertimeEntry]) -> (brut: Double, net: Double) {
        entries.reduce((0.0, 0.0)) { sum, entry in
            let row = ReportRowCalculator.makeRow(entry: entry, profileMap: profileMap, holidays: Array(holidays))
            return (sum.0 + (row.earningsBrut ?? 0), sum.1 + (row.earningsNet ?? 0))
        }
    }

    private func formattedHours(_ h: Double) -> String {
        let sign = h < 0 ? "-" : "+"
        let abs = Swift.abs(h)
        let hh = Int(abs)
        let mm = Int((abs - Double(hh)) * 60)
        return mm == 0 ? "\(sign)\(hh)h" : String(format: "\(sign)%dh%02d", hh, mm)
    }

    private func formattedAmount(_ value: Double) -> String {
        let fmt = SharedFormatters.frenchDecimalAmount
        let sign = value < 0 ? "-" : "+"
        return "\(sign)\(fmt.string(from: NSNumber(value: Swift.abs(value))) ?? "0,00") \(currency)"
    }

    var body: some View {
        // Calculée une seule fois par render (au lieu de deux fois par employeur : une pour
        // filtrer les employeurs actifs, une pour peupler chaque section).
        let entriesByEmployer = self.entriesByEmployer
        let mealsByEmployer = self.mealsByEmployer
        let activeEmployers = employers.filter {
            !(entriesByEmployer[$0]?.isEmpty ?? true) || !(mealsByEmployer[$0]?.isEmpty ?? true)
        }

        Form {
            Section(header: Text("Période")) {
                HStack {
                    Button {
                        if let prev = calendar.date(byAdding: .month, value: -1, to: selectedMonth) {
                            selectedMonth = prev
                            selectedEmployer = nil
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3.bold())
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Mois précédent")

                    Spacer()

                    Text(SharedFormatters.frenchMonthYear.string(from: selectedMonth).capitalized)
                        .font(.headline)

                    Spacer()

                    Button {
                        if let next = calendar.date(byAdding: .month, value: 1, to: selectedMonth) {
                            selectedMonth = next
                            selectedEmployer = nil
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.title3.bold())
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Mois suivant")
                }

                if !employers.isEmpty {
                    Picker("Employeur", selection: $selectedEmployer) {
                        Label("Tous les employeurs", systemImage: "building.2.fill")
                            .tag(Optional<Employer>.none)
                        ForEach(employers) { employer in
                            Label(employer.name ?? "", systemImage: "building.2")
                                .tag(Optional(employer))
                        }
                    }
                }

                Toggle("Afficher les entrées traitées", isOn: $showArchived)
            }

            let totalLabel = selectedEmployer.flatMap { $0.name } ?? "Total du mois"
            Section(header: Text(totalLabel)) {
                LabeledContent("Entrées") {
                    Text("\(displayedEntries.count)")
                        .foregroundColor(.secondary)
                }
                LabeledContent("Total heures") {
                    let h = totalHours(for: displayedEntries)
                    Text(formattedHours(h))
                        .foregroundColor(h >= 0 ? .green : .orange)
                        .fontWeight(.medium)
                }
                LabeledContent("Total brut") {
                    let g = totalEarnings(for: displayedEntries).brut
                    Text(formattedAmount(g))
                        .foregroundColor(g >= 0 ? .green : .red)
                        .fontWeight(.medium)
                }
                LabeledContent("Total net") {
                    let g = totalEarnings(for: displayedEntries).net
                    Text(formattedAmount(g))
                        .foregroundColor(g >= 0 ? .green : .red)
                        .fontWeight(.medium)
                }
                LabeledContent("Repas") {
                    Text("\(displayedMeals.count)")
                        .foregroundColor(.secondary)
                }
                if let employer = selectedEmployer, let siret = employer.siret, !siret.isEmpty {
                    LabeledContent("SIRET") {
                        Text(siret).foregroundColor(.secondary)
                    }
                }
            }

            if selectedEmployer == nil {
                ForEach(activeEmployers) { employer in
                    let empEntries = entriesByEmployer[employer] ?? []
                    let empMeals = mealsByEmployer[employer] ?? []
                    Section(header: Text(employer.name ?? "")) {
                        LabeledContent("Entrées") {
                            Text("\(empEntries.count)")
                                .foregroundColor(.secondary)
                        }
                        LabeledContent("Heures") {
                            let h = totalHours(for: empEntries)
                            Text(formattedHours(h))
                                .foregroundColor(h >= 0 ? .green : .orange)
                                .fontWeight(.medium)
                        }
                        LabeledContent("Brut") {
                            let g = totalEarnings(for: empEntries).brut
                            Text(formattedAmount(g))
                                .foregroundColor(g >= 0 ? .green : .red)
                                .fontWeight(.medium)
                        }
                        LabeledContent("Net") {
                            let g = totalEarnings(for: empEntries).net
                            Text(formattedAmount(g))
                                .foregroundColor(g >= 0 ? .green : .red)
                                .fontWeight(.medium)
                        }
                        LabeledContent("Repas") {
                            Text("\(empMeals.count)")
                                .foregroundColor(.secondary)
                        }
                        if let siret = employer.siret, !siret.isEmpty {
                            LabeledContent("SIRET") {
                                Text(siret).foregroundColor(.secondary)
                            }
                        }
                    }
                }

                if !unassignedEntries.isEmpty || !unassignedMeals.isEmpty {
                    Section(header: Text("Sans employeur affecté")) {
                        LabeledContent("Entrées") {
                            Text("\(unassignedEntries.count)")
                                .foregroundColor(.secondary)
                        }
                        LabeledContent("Heures") {
                            let h = totalHours(for: unassignedEntries)
                            Text(formattedHours(h))
                                .foregroundColor(h >= 0 ? .green : .orange)
                                .fontWeight(.medium)
                        }
                        LabeledContent("Brut") {
                            let g = totalEarnings(for: unassignedEntries).brut
                            Text(formattedAmount(g))
                                .foregroundColor(g >= 0 ? .green : .red)
                                .fontWeight(.medium)
                        }
                        LabeledContent("Net") {
                            let g = totalEarnings(for: unassignedEntries).net
                            Text(formattedAmount(g))
                                .foregroundColor(g >= 0 ? .green : .red)
                                .fontWeight(.medium)
                        }
                        LabeledContent("Repas") {
                            Text("\(unassignedMeals.count)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            if displayedEntries.isEmpty && displayedMeals.isEmpty {
                Section {
                    Text(showArchived ? "Aucune entrée pour ce mois." : "Aucune entrée active pour ce mois.")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Vue consolidée")
    }
}

#Preview {
    NavigationStack {
        ConsolidatedReportView()
            .environment(\.managedObjectContext, CoreDataManager.shared.container.viewContext)
    }
}
