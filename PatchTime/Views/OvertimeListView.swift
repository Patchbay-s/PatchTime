import SwiftUI
import CoreData
import Foundation

enum QuickOvertimeFilter: String, CaseIterable, Identifiable {
    case all = "Tous"
    case today = "Aujourd'hui"
    case week = "Semaine"
    case month = "Mois"
    case nonValidated = "Non validées"
    var id: String { rawValue }
}

enum OvertimeSortMode: String, CaseIterable, Identifiable {
    case dateDesc = "Date (récent)"
    case dateAsc = "Date (ancien)"
    case amountDesc = "Montant (max)"
    case amountAsc = "Montant (min)"
    var id: String { rawValue }
}

/// Sélecteur segmenté fusionnant Heures Sup et Repas (Chantier 6) — l'onglet Repas de la tab
/// bar principale est retiré, ce sélecteur est désormais le seul accès à cet écran.
enum OvertimeListSegment: String, CaseIterable, Identifiable {
    case heuresSup = "Heures Sup"
    case repas = "Repas"
    var id: String { rawValue }
}

struct OvertimeListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    // Entrées actives (archived == NO), restreintes en plus à la période affichée via un
    // predicate mis à jour dynamiquement (voir updateActivePredicate()) plutôt que de fetcher
    // tout l'historique et de le filtrer en mémoire à chaque render.
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \OvertimeEntry.date, ascending: false)],
        predicate: NSPredicate(format: "archived == NO"),
        animation: .default)
    private var overtimeEntries: FetchedResults<OvertimeEntry>

    // Entrées traitées, chargées séparément (predicate statique) pour ne jamais les mélanger
    // au fetch ci-dessus ni les recharger inutilement à chaque changement de période.
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \OvertimeEntry.date, ascending: false)],
        predicate: NSPredicate(format: "archived == YES"),
        animation: .default)
    private var archivedOvertimeEntries: FetchedResults<OvertimeEntry>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \OvertimeProfile.name, ascending: true)],
        animation: .default)
    private var overtimeProfiles: FetchedResults<OvertimeProfile>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Employer.name, ascending: true)],
        animation: .default)
    private var employers: FetchedResults<Employer>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \PublicHoliday.date, ascending: true)],
        animation: .default)
    private var holidays: FetchedResults<PublicHoliday>

    // Repas — fusionné dans cet écran (Chantier 6), même pattern actif/traité que les heures sup.
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MealEntry.date, ascending: false)],
        predicate: NSPredicate(format: "archived == NO"),
        animation: .default)
    private var mealEntries: FetchedResults<MealEntry>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MealEntry.date, ascending: false)],
        predicate: NSPredicate(format: "archived == YES"),
        animation: .default)
    private var archivedMealEntries: FetchedResults<MealEntry>

    @AppStorage("displayPeriod") private var displayPeriod: String = DisplayPeriod.all.rawValue
    @AppStorage("currency") private var currency: String = Currency.euro.rawValue
    @AppStorage("defaultProfileId") private var defaultProfileId: String = ""
    @AppStorage("customStartDate") private var customStartDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @AppStorage("customEndDate") private var customEndDate: Date = Date()
    
    @State private var showingAddSheet = false
    @State private var showFilters = false
    @State private var editingEntry: OvertimeEntry?
    @State private var searchText = ""
    @State private var selectedProfileFilter: OvertimeProfile?
    @State private var selectedEmployer: Employer? = nil
    @State private var refreshView = false
    @State private var showArchived: Bool = false
    @State private var quickFilter: QuickOvertimeFilter = .all
    @State private var sortMode: OvertimeSortMode = .dateDesc
    @State private var selectedArchiveMonth = "Tous les mois"
    @State private var showArchiveConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var entriesToDelete: [OvertimeEntry] = []
    @State private var undoMessage: String?
    @State private var undoWorkItem: DispatchWorkItem?

    @State private var selectedSegment: OvertimeListSegment = .heuresSup
    @State private var showingAddMealSheet = false
    @State private var editingMealEntry: MealEntry?
    @State private var mealSearchText = ""
    @State private var showMealArchived: Bool = false

    private var profileMap: [UUID: OvertimeProfile] {
        Dictionary(uniqueKeysWithValues: overtimeProfiles.compactMap { p in p.id.map { ($0, p) } })
    }

    private var employerMap: [UUID: Employer] {
        Dictionary(uniqueKeysWithValues: employers.compactMap { e in e.id.map { ($0, e) } })
    }

    var filteredMealEntries: [MealEntry] {
        // archived == NO et la période sélectionnée sont déjà appliqués au niveau du
        // predicate CoreData (voir le @FetchRequest de mealEntries).
        var employerFiltered = Array(mealEntries)
        if !defaultProfileId.isEmpty,
           let defaultProfile = overtimeProfiles.first(where: { $0.id?.uuidString == defaultProfileId }),
           let employerID = defaultProfile.employer?.id {
            employerFiltered = employerFiltered.filter { $0.employerID == employerID }
        }

        if mealSearchText.isEmpty {
            return employerFiltered
        }
        return employerFiltered.filter { entry in
            (entry.mealType?.localizedCaseInsensitiveContains(mealSearchText) ?? false)
        }
    }

    var archivedMealEntriesList: [MealEntry] {
        Array(archivedMealEntries)
    }

    var filteredEntries: [OvertimeEntry] {
        // archived == NO et la période sélectionnée sont déjà appliqués au niveau du
        // predicate CoreData (voir le @FetchRequest de overtimeEntries).
        var employerFiltered = Array(overtimeEntries)
        if let employer = selectedEmployer {
            let profileIDs = Set(overtimeProfiles.filter { $0.employer == employer }.compactMap { $0.id })
            employerFiltered = employerFiltered.filter { entry in
                guard let pid = entry.profileID else { return false }
                return profileIDs.contains(pid)
            }
        }

        var profileFiltered = employerFiltered
        if let selectedProfileFilter = selectedProfileFilter {
            profileFiltered = profileFiltered.filter { $0.profileID == selectedProfileFilter.id }
        } else if !defaultProfileId.isEmpty {
            if let defaultProfile = overtimeProfiles.first(where: { $0.id?.uuidString == defaultProfileId }) {
                profileFiltered = profileFiltered.filter { $0.profileID == defaultProfile.id }
            }
        }
        
        let quickFiltered = profileFiltered.filter { entry in
            guard let date = entry.date else { return false }
            switch quickFilter {
            case .all:
                return true
            case .today:
                return Calendar.current.isDateInToday(date)
            case .week:
                return Calendar.current.isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
            case .month:
                return Calendar.current.isDate(date, equalTo: Date(), toGranularity: .month)
            case .nonValidated:
                return !(entry.value(forKey: "isValidated") as? Bool ?? false)
            }
        }

        let searched: [OvertimeEntry]
        if searchText.isEmpty {
            searched = quickFiltered
        } else {
            searched = quickFiltered.filter { entry in
                (entry.location?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (entry.reason?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (entry.profileID != nil && overtimeProfiles.first(where: { $0.id == entry.profileID })?.name?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return searched.sorted { lhs, rhs in
            switch sortMode {
            case .dateDesc:
                return (lhs.date ?? .distantPast) > (rhs.date ?? .distantPast)
            case .dateAsc:
                return (lhs.date ?? .distantPast) < (rhs.date ?? .distantPast)
            case .amountDesc:
                return amount(for: lhs) > amount(for: rhs)
            case .amountAsc:
                return amount(for: lhs) < amount(for: rhs)
            }
        }
    }
    
    var archivedEntries: [OvertimeEntry] {
        guard selectedArchiveMonth != "Tous les mois" else { return Array(archivedOvertimeEntries) }
        return archivedOvertimeEntries.filter { entry in
            guard let date = entry.date else { return false }
            return SharedFormatters.frenchMonthYear.string(from: date).capitalized == selectedArchiveMonth
        }
    }

    var archiveMonthOptions: [String] {
        let months: Set<String> = Set(archivedOvertimeEntries.compactMap { entry in
            guard let date = entry.date else { return nil }
            return SharedFormatters.frenchMonthYear.string(from: date).capitalized
        })
        return ["Tous les mois"] + months.sorted()
    }
    
    @ViewBuilder
    private var filtersSection: some View {
        Section(header: Text("Filtres rapides")) {
            Picker("Filtre", selection: $quickFilter) {
                ForEach(QuickOvertimeFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            Picker("Tri", selection: $sortMode) {
                ForEach(OvertimeSortMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }

            if !employers.isEmpty {
                Picker("Employeur", selection: $selectedEmployer) {
                    Text("Tous les employeurs").tag(Optional<Employer>.none)
                    ForEach(employers) { employer in
                        Label(employer.name ?? "", systemImage: "building.2")
                            .tag(Optional(employer))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var activeEntriesSection: some View {
        let activeEntries = filteredEntries
        if activeEntries.isEmpty {
            EmptyStateView(
                icon: "clock.badge.xmark",
                title: "Aucune entrée",
                subtitle: "Ajoutez votre première heure supplémentaire avec le bouton +",
                actionTitle: "Ajouter",
                action: { showingAddSheet = true }
            )
        }

        ForEach(activeEntries, id: \.id) { entry in
            HStack {
                Button(action: { editingEntry = entry }) {
                    OvertimeEntryRow(entry: entry, currency: currency,
                                    profile: entry.profileID.flatMap { profileMap[$0] },
                                    onDelete: {
                        entriesToDelete = [entry]
                        showDeleteConfirmation = true
                    }, onArchive: {
                        withAnimation {
                            entry.archived = true
                            entry.setValue(true, forKey: "isValidated") // Valider automatiquement lors du traitement
                            do {
                                try viewContext.save()
                                print("OvertimeEntry traité. Entry ID: \(entry.id?.uuidString ?? "nil")")
                                refreshView.toggle()
                            } catch {
                                print("Error traitement OvertimeEntry: \(error.localizedDescription)")
                            }
                        }
                    })
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .onDelete { offsets in
            entriesToDelete = offsets.map { activeEntries[$0] }
            showDeleteConfirmation = true
        }
    }

    @ViewBuilder
    private var archiveControlsSection: some View {
        Section {
            Toggle(isOn: $showArchived) {
                Text("Afficher les entrées traitées")
            }
            if showArchived {
                Picker("Mois", selection: $selectedArchiveMonth) {
                    ForEach(archiveMonthOptions, id: \.self) { month in
                        Text(month).tag(month)
                    }
                }
            }

            Button("Saisir tout validé en compta") {
                showArchiveConfirmation = true
            }
            .foregroundColor(.blue)
        }

        if showArchived && !archivedEntries.isEmpty {
            Section(header: Text("Traités")) {
                ForEach(archivedEntries, id: \.id) { entry in
                    HStack {
                        Button(action: { editingEntry = entry }) {
                            OvertimeEntryRow(entry: entry, currency: currency,
                                            profile: entry.profileID.flatMap { profileMap[$0] },
                                            onDelete: {
                                entriesToDelete = [entry]
                                showDeleteConfirmation = true
                            }, onArchive: {
                                withAnimation {
                                    entry.archived = false
                                    // Ne pas dévalider lors du retrait de la compta
                                    do {
                                        try viewContext.save()
                                        print("OvertimeEntry retiré de la compta. Entry ID: \(entry.id?.uuidString ?? "nil")")
                                        refreshView.toggle()
                                    } catch {
                                        print("Error retrait compta OvertimeEntry: \(error.localizedDescription)")
                                    }
                                }
                            })
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                }
            }
        }

        if let undoMessage {
            Section {
                HStack {
                    Text(undoMessage)
                        .font(.subheadline)
                    Spacer()
                    Button("Annuler") {
                        undoLastAction()
                    }
                    .fontWeight(.bold)
                }
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private var mealActiveEntriesSection: some View {
        let activeMeals = filteredMealEntries
        if activeMeals.isEmpty {
            EmptyStateView(
                icon: "fork.knife",
                title: "Aucun repas",
                subtitle: "Ajoutez votre premier repas professionnel avec le bouton +",
                actionTitle: "Ajouter",
                action: { showingAddMealSheet = true }
            )
        }

        ForEach(activeMeals, id: \.id) { entry in
            HStack {
                Button(action: { editingMealEntry = entry }) {
                    MealEntryRow(entry: entry,
                                 employer: entry.employerID.flatMap { employerMap[$0] },
                                 onDelete: {
                        deleteMeal(entry)
                    }, onArchive: {
                        withAnimation {
                            entry.archived = true
                            entry.setValue(true, forKey: "isValidated") // Valider automatiquement lors du traitement
                            do {
                                try viewContext.save()
                                refreshView.toggle()
                            } catch {
                                print("Error traitement meal: \(error.localizedDescription)")
                            }
                        }
                    })
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .onDelete { offsets in
            deleteMeals(offsets: offsets, from: activeMeals)
        }
    }

    @ViewBuilder
    private var mealArchiveControlsSection: some View {
        Section {
            Toggle(isOn: $showMealArchived) {
                Text("Afficher les entrées traitées")
            }
        }

        if showMealArchived && !archivedMealEntriesList.isEmpty {
            Section(header: Text("Traités")) {
                ForEach(archivedMealEntriesList, id: \.id) { entry in
                    HStack {
                        Button(action: { editingMealEntry = entry }) {
                            MealEntryRow(entry: entry,
                                         employer: entry.employerID.flatMap { employerMap[$0] },
                                         onDelete: {
                                deleteMeal(entry)
                            }, onArchive: {
                                withAnimation {
                                    entry.archived = false
                                    // Ne pas dévalider lors du retrait de la compta
                                    do {
                                        try viewContext.save()
                                        refreshView.toggle()
                                    } catch {
                                        print("Error retrait compta meal: \(error.localizedDescription)")
                                    }
                                }
                            })
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if selectedSegment == .heuresSup {
            ToolbarItem(placement: .navigationBarLeading) {
                ToolbarDisclosureButton(
                    isExpanded: $showFilters,
                    systemImage: "line.3.horizontal.decrease.circle",
                    systemImageExpanded: "line.3.horizontal.decrease.circle.fill",
                    expandedLabel: "Masquer les filtres",
                    collapsedLabel: "Afficher les filtres"
                )
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: {
                if selectedSegment == .heuresSup {
                    showingAddSheet = true
                } else {
                    showingAddMealSheet = true
                }
            }) {
                Image(systemName: "plus")
            }
            .accessibilityLabel(selectedSegment == .heuresSup ? "Nouvelle entrée" : "Nouveau repas")
            // iPad avec clavier et Mac : ⌘N ouvre une nouvelle saisie.
            .keyboardShortcut("n", modifiers: .command)
        }
    }

    private var segmentPicker: some View {
        Picker("Affichage", selection: $selectedSegment) {
            ForEach(OvertimeListSegment.allCases) { segment in
                Text(segment.rawValue).tag(segment)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 8)
        // Le sélecteur vit dans le VStack au-dessus de la List (fond .systemBackground par
        // défaut), alors que la List juste en dessous garde son fond .systemGroupedBackground
        // par défaut (gris en light mode) — sans ceci, rupture visuelle nette entre les deux
        // zones (Chantier 4). On aligne le fond du sélecteur sur celui de la liste plutôt que
        // de restyler toute la List, pour rester cohérent avec le style déjà utilisé ailleurs.
        .background(Color(.systemGroupedBackground))
    }

    @ViewBuilder
    private var segmentedList: some View {
        List {
            if selectedSegment == .heuresSup {
                if showFilters {
                    filtersSection
                }
                activeEntriesSection
                archiveControlsSection
            } else {
                mealActiveEntriesSection
                mealArchiveControlsSection
            }
        }
        .id(refreshView)
    }

    private var listView: some View {
        VStack(spacing: 0) {
            segmentPicker
            segmentedList
        }
        .searchable(text: selectedSegment == .heuresSup ? $searchText : $mealSearchText, prompt: "Rechercher...")
        .navigationTitle(selectedSegment == .heuresSup ? "Heures Supplémentaires" : "Repas")
        .toolbar { toolbarContent }
        .sheet(isPresented: $showingAddSheet) {
            AddOvertimeView()
        }
        .sheet(item: $editingEntry) { entry in
            EditOvertimeView(entry: entry)
        }
        .sheet(isPresented: $showingAddMealSheet) {
            AddMealView()
        }
        .sheet(item: $editingMealEntry) { entry in
            EditMealView(entry: entry)
        }
        .alert("Saisir en comptabilité ?", isPresented: $showArchiveConfirmation) {
            Button("Annuler", role: .cancel) {}
            Button("Saisir en compta", role: .destructive) {
                archiveAllValidated()
            }
        } message: {
            Text("Toutes les heures validées non traitées seront saisies en comptabilité.")
        }
        .alert("Supprimer les entrées sélectionnées ?", isPresented: $showDeleteConfirmation) {
            Button("Annuler", role: .cancel) {
                entriesToDelete = []
            }
            Button("Supprimer", role: .destructive) {
                deleteEntries(entriesToDelete)
                entriesToDelete = []
            }
        } message: {
            Text("Cette action peut être annulée pendant 5 secondes.")
        }
    }

    var body: some View {
        NavigationStack {
            listView
        }
        .onAppear {
            updateActivePredicate()
            updateMealActivePredicate()
        }
        .onChange(of: displayPeriod) { _, _ in
            updateActivePredicate()
            updateMealActivePredicate()
        }
        .onChange(of: customStartDate) { _, _ in
            updateActivePredicate()
            updateMealActivePredicate()
        }
        .onChange(of: customEndDate) { _, _ in
            updateActivePredicate()
            updateMealActivePredicate()
        }
    }

    /// Restreint le @FetchRequest des entrées actives à la période sélectionnée
    /// (en plus de archived == NO, déjà fixé à la déclaration).
    private func updateActivePredicate() {
        let period = DisplayPeriod(rawValue: displayPeriod) ?? .all
        let archivedPred = NSPredicate(format: "archived == NO")
        if let datePred = FilterHelper.datePredicate(for: period, customStart: customStartDate, customEnd: customEndDate) {
            overtimeEntries.nsPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [archivedPred, datePred])
        } else {
            overtimeEntries.nsPredicate = archivedPred
        }
    }

    /// Même principe que `updateActivePredicate` mais pour le segment Repas.
    private func updateMealActivePredicate() {
        let period = DisplayPeriod(rawValue: displayPeriod) ?? .all
        let archivedPred = NSPredicate(format: "archived == NO")
        if let datePred = FilterHelper.datePredicate(for: period, customStart: customStartDate, customEnd: customEndDate) {
            mealEntries.nsPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [archivedPred, datePred])
        } else {
            mealEntries.nsPredicate = archivedPred
        }
    }

    private func deleteMeal(_ entry: MealEntry) {
        withAnimation {
            viewContext.delete(entry)
            do {
                try viewContext.save()
                refreshView.toggle()
            } catch {
                print("Error deleting meal: \(error.localizedDescription)")
            }
        }
    }

    private func deleteMeals(offsets: IndexSet, from entries: [MealEntry]) {
        withAnimation {
            offsets.map { entries[$0] }.forEach(viewContext.delete)
            do {
                try viewContext.save()
                refreshView.toggle()
            } catch {
                print("Error deleting meals: \(error.localizedDescription)")
            }
        }
    }

    private func deleteEntries(_ entries: [OvertimeEntry]) {
        withAnimation {
            viewContext.undoManager = UndoManager()
            entries.forEach(viewContext.delete)
            do {
                try viewContext.save()
                print("OvertimeEntries deleted successfully!")
                refreshView.toggle()
                showUndo(message: "Entrée(s) supprimée(s)")
            } catch {
                print("Error deleting OvertimeEntries: \(error.localizedDescription)")
            }
        }
    }
    
    private func amount(for entry: OvertimeEntry) -> Double {
        guard let start = entry.startTime, let end = entry.endTime else { return 0 }
        let hours = overtimeDuration(from: start, to: end) / 3600
        let profile = overtimeProfiles.first(where: { $0.id == entry.profileID })
        let rate = ReportRowCalculator.bestEffortRate(for: profile)
        let isRecup = entry.type == "recup"
        let multiplier = isRecup ? 1.0 : OvertimeSurcharge.multiplier(for: entry, profile: profile, holidays: Array(holidays))
        let gross = hours * rate * multiplier
        return isRecup ? -gross : gross
    }

    private func archiveAllValidated() {
        // Fetch dédié, indépendant du predicate de période appliqué à la liste affichée :
        // "Saisir tout validé" doit porter sur TOUTES les heures validées, pas seulement
        // celles visibles avec le filtre de période courant.
        let entriesToArchive = CoreDataManager.shared.fetchOvertimeEntries(
            predicate: NSPredicate(format: "archived == NO AND isValidated == YES")
        )
        guard !entriesToArchive.isEmpty else { return }
        withAnimation {
            viewContext.undoManager = UndoManager()
            entriesToArchive.forEach { $0.archived = true }
            do {
                try viewContext.save()
                refreshView.toggle()
                showUndo(message: "\(entriesToArchive.count) entrée(s) saisie(s) en compta")
            } catch {
                print("Error archiving validated entries: \(error.localizedDescription)")
            }
        }
    }

    private func showUndo(message: String) {
        undoWorkItem?.cancel()
        undoMessage = message

        let workItem = DispatchWorkItem {
            undoMessage = nil
        }
        undoWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: workItem)
    }

    private func undoLastAction() {
        guard let undoManager = viewContext.undoManager, undoManager.canUndo else { return }
        undoWorkItem?.cancel()
        undoMessage = nil

        undoManager.undo()
        do {
            try viewContext.save()
            refreshView.toggle()
        } catch {
            print("Error undoing last action: \(error.localizedDescription)")
        }
    }
}

struct OvertimeEntryRow: View {
    @Environment(\.managedObjectContext) private var viewContext
    let entry: OvertimeEntry
    let currency: String
    let profile: OvertimeProfile?
    let onDelete: () -> Void
    let onArchive: () -> Void
    
    var validationColor: Color {
        let isValidated = entry.value(forKey: "isValidated") as? Bool ?? false
        return isValidated ? .green : .red
    }
    
    var isValidated: Bool {
        entry.value(forKey: "isValidated") as? Bool ?? false
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(formattedDate(from: entry.date))
                        .font(.headline)
                        .foregroundColor(validationColor)
                    Text(entry.type == "sup" ? "Heure Sup" : "Récupération")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(entry.type == "sup" ? Color.blue.opacity(0.2) : Color.green.opacity(0.2))
                        .foregroundColor(entry.type == "sup" ? .blue : .green)
                        .cornerRadius(4)
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        toggleValidation()
                    }) {
                        Image(systemName: isValidated ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(isValidated ? .green : .red)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isValidated ? "Marquer comme non validé" : "Marquer comme validé")
                }
                if let timeRange = entry.timeRangeText {
                    Text(timeRange)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                if let location = entry.location, !location.isEmpty {
                    Text(location)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if let reason = entry.reason, !reason.isEmpty {
                    Text(reason)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if let profile = profile {
                    Text(profile.name ?? "")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                if let start = entry.startTime, let end = entry.endTime {
                    let hours = end.timeIntervalSince(start) / 3600
                    Text(String(format: "%.1f heures", hours))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Supprimer", systemImage: "trash")
            }
            Button {
                duplicateEntry()
            } label: {
                Label("Dupliquer", systemImage: "doc.on.doc")
            }
            .tint(.indigo)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                onArchive()
            } label: {
                Label(entry.archived ? "Retirer de la compta" : "Saisir en compta", systemImage: entry.archived ? "archivebox.fill" : "archivebox")
            }
            .tint(.blue)

            Button {
                toggleValidation()
            } label: {
                Label(isValidated ? "Dévalider" : "Valider", systemImage: isValidated ? "xmark.circle" : "checkmark.circle")
            }
            .tint(isValidated ? .orange : .green)
        }
    }

    private func formattedDate(from date: Date?) -> String {
        guard let date = date else { return "" }
        return SharedFormatters.frenchLongDate.string(from: date)
    }

    private func duplicateEntry() {
        let copy = OvertimeEntry(context: viewContext)
        copy.id = UUID()
        copy.date = Date()
        copy.startTime = entry.startTime
        copy.endTime = entry.endTime
        copy.location = entry.location
        copy.reason = entry.reason
        copy.profileID = entry.profileID
        copy.type = entry.type
        copy.archived = false
        copy.setValue(false, forKey: "isValidated")
        do {
            try viewContext.save()
        } catch {
            print("Error duplicating entry: \(error.localizedDescription)")
        }
    }

    private func toggleValidation() {
        // Utiliser setValue pour éviter les erreurs si l'attribut n'est pas encore reconnu
        let currentValue = entry.value(forKey: "isValidated") as? Bool ?? false
        entry.setValue(!currentValue, forKey: "isValidated")
        do {
            try viewContext.save()
            // Rafraîchir le contexte pour notifier les autres vues
            viewContext.refresh(entry, mergeChanges: true)
        } catch {
            print("Error toggling validation: \(error.localizedDescription)")
        }
    }
}

#Preview {
    OvertimeListView()
        .environment(\.managedObjectContext, CoreDataManager.shared.container.viewContext)
} 
 