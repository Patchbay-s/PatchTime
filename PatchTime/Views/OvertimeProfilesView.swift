import SwiftUI

struct RateHistoryItem: Codable, Identifiable {
    let id: UUID
    let date: Date
    let rate: Double
}

struct RateHistoryStore {
    static func key(for profileId: UUID) -> String { "rateHistory_\(profileId.uuidString)" }

    static func load(for profileId: UUID) -> [RateHistoryItem] {
        guard let data = UserDefaults.standard.data(forKey: key(for: profileId)),
              let history = try? JSONDecoder().decode([RateHistoryItem].self, from: data) else {
            return []
        }
        return history.sorted(by: { $0.date > $1.date })
    }

    static func append(rate: Double, for profileId: UUID, at date: Date = Date()) {
        var history = load(for: profileId)
        history.append(RateHistoryItem(id: UUID(), date: date, rate: rate))
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: key(for: profileId))
        }
    }
}

struct RateProfileSettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext

    /// `nil` = profils sans employeur assigné ; sinon, profils rattachés à cet employeur
    /// (même pattern d'accès per-employeur que ContractListView, Chantier 7).
    let employer: Employer?

    @FetchRequest private var profiles: FetchedResults<OvertimeProfile>

    @State private var showingAddSheet = false
    @State private var editingProfile: OvertimeProfile?
    @State private var showDeleteError = false
    @State private var deleteErrorMessage = ""

    init(employer: Employer? = nil) {
        self.employer = employer
        let predicate = employer.map { NSPredicate(format: "employer == %@", $0) } ?? NSPredicate(format: "employer == nil")
        _profiles = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \OvertimeProfile.name, ascending: true)],
            predicate: predicate,
            animation: .default
        )
    }

    private var navigationTitleText: String {
        employer != nil ? "Taux" : "Profils sans employeur"
    }

    var body: some View {
        Group {
            if profiles.isEmpty {
                EmptyStateView(
                    icon: "eurosign.circle",
                    title: "Aucun profil de taux",
                    subtitle: "Ajoutez-en un avec le bouton +.",
                    actionTitle: "Ajouter",
                    action: { showingAddSheet = true }
                )
            } else {
                List {
                    ForEach(profiles) { profile in
                        ProfileRowView(profile: profile, editingProfile: $editingProfile)
                    }
                    .onDelete(perform: deleteProfiles)
                }
            }
        }
        .navigationTitle(navigationTitleText)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddOvertimeProfileView(preselectedEmployer: employer)
        }
        .sheet(item: $editingProfile) { profile in
            EditOvertimeProfileView(profile: profile)
        }
        .alert("Erreur", isPresented: $showDeleteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteErrorMessage)
        }
    }

    private func deleteProfiles(offsets: IndexSet) {
        withAnimation {
            offsets.map { profiles[$0] }.forEach(viewContext.delete)
            do {
                try viewContext.save()
            } catch {
                deleteErrorMessage = "Erreur de suppression : \(error.localizedDescription)"
                showDeleteError = true
            }
        }
    }
}

struct ProfileRowView: View {
    let profile: OvertimeProfile
    @Binding var editingProfile: OvertimeProfile?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name ?? "")
                    .font(.headline)
                Text(rateSummary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if let employerName = profile.employer?.name, !employerName.isEmpty {
                    Label(employerName, systemImage: "building.2")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if let details = profile.details, !details.isEmpty {
                    Text(details)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                if let id = profile.id {
                    let history = RateHistoryStore.load(for: id)
                    if let latest = history.first {
                        Text("Dernier changement: \(latest.date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
            Button(action: { editingProfile = profile }) {
                Image(systemName: "pencil.circle")
                    .foregroundColor(.blue)
                    .font(.title2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            editingProfile = profile
        }
        .padding(.vertical, 4)
    }

    private var rateSummary: String {
        switch (profile.tauxBrutValue, profile.tauxNetValue) {
        case let (.some(b), .some(n)):
            return String(format: "%.2f€/h brut · %.2f€/h net", b, n)
        case let (.some(b), .none):
            return String(format: "%.2f€/h brut", b)
        case let (.none, .some(n)):
            return String(format: "%.2f€/h net", n)
        case (.none, .none):
            return "Aucun taux enregistré"
        }
    }
}

struct AddOvertimeProfileView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Employer.name, ascending: true)])
    private var employers: FetchedResults<Employer>

    @State private var name = ""
    @State private var details = ""
    @State private var selectedEmployer: Employer? = nil
    @State private var calculator = TauxCalculator()
    @State private var weekendSurchargeText = ""
    @State private var holidaySurchargeText = ""

    @State private var showingAlert = false
    @State private var alertMessage = ""

    init(preselectedEmployer: Employer? = nil) {
        _selectedEmployer = State(initialValue: preselectedEmployer)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Informations")) {
                    TextField("Nom du profil", text: $name)
                }

                TauxFieldsSection(calculator: $calculator)

                Section(header: Text("Majoration weekend / jour férié (optionnel)"), footer: Text("Laissez vide si votre convention collective n'en prévoit pas — aucune valeur légale unique n'existe pour le dimanche ou les jours fériés.")) {
                    HStack {
                        Text("Weekend (%)")
                        Spacer()
                        TextField("0", text: $weekendSurchargeText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Jour férié (%)")
                        Spacer()
                        TextField("0", text: $holidaySurchargeText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section(header: Text("Employeur (optionnel)")) {
                    Picker("Employeur", selection: $selectedEmployer) {
                        Text("Aucun").tag(Optional<Employer>.none)
                        ForEach(employers) { employer in
                            Text(employer.name ?? "").tag(Optional(employer))
                        }
                    }
                }

                Section(header: Text("Description (optionnelle)")) {
                    TextEditor(text: $details)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Nouveau Profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { saveProfile() }
                }
            }
            .alert("Erreur", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func saveProfile() {
        guard !name.isEmpty else {
            alertMessage = "Veuillez entrer un nom"
            showingAlert = true
            return
        }
        let profile = OvertimeProfile(context: viewContext)
        profile.id = UUID()
        profile.name = name
        profile.tauxBrutValue = calculator.brut
        profile.tauxNetValue = calculator.net
        profile.tauxPourcentageValue = calculator.pourcentage
        profile.weekendSurchargePercentValue = Double(weekendSurchargeText.replacingOccurrences(of: ",", with: ".")).map { $0 / 100 }
        profile.holidaySurchargePercentValue = Double(holidaySurchargeText.replacingOccurrences(of: ",", with: ".")).map { $0 / 100 }
        profile.details = details
        profile.employer = selectedEmployer
        do {
            try viewContext.save()
            if let profileId = profile.id, let brut = calculator.brut {
                RateHistoryStore.append(rate: brut, for: profileId)
            }
            dismiss()
        } catch {
            alertMessage = "Erreur lors de la sauvegarde du profil: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

struct EditOvertimeProfileView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Employer.name, ascending: true)])
    private var employers: FetchedResults<Employer>

    let profile: OvertimeProfile

    @State private var name: String
    @State private var details: String
    @State private var selectedEmployer: Employer?
    @State private var calculator: TauxCalculator
    @State private var weekendSurchargeText: String
    @State private var holidaySurchargeText: String

    @State private var showingAlert = false
    @State private var alertMessage = ""

    init(profile: OvertimeProfile) {
        self.profile = profile
        _name = State(initialValue: profile.name ?? "")
        _details = State(initialValue: profile.details ?? "")
        _selectedEmployer = State(initialValue: profile.employer)
        _calculator = State(initialValue: TauxCalculator(
            loadingBrut: profile.tauxBrutValue,
            net: profile.tauxNetValue,
            pourcentage: profile.tauxPourcentageValue
        ))
        _weekendSurchargeText = State(initialValue: profile.weekendSurchargePercentValue.map { String($0 * 100) } ?? "")
        _holidaySurchargeText = State(initialValue: profile.holidaySurchargePercentValue.map { String($0 * 100) } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Informations")) {
                    TextField("Nom du profil", text: $name)
                }

                TauxFieldsSection(calculator: $calculator)

                Section(header: Text("Majoration weekend / jour férié (optionnel)"), footer: Text("Laissez vide si votre convention collective n'en prévoit pas — aucune valeur légale unique n'existe pour le dimanche ou les jours fériés.")) {
                    HStack {
                        Text("Weekend (%)")
                        Spacer()
                        TextField("0", text: $weekendSurchargeText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Jour férié (%)")
                        Spacer()
                        TextField("0", text: $holidaySurchargeText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section(header: Text("Employeur (optionnel)")) {
                    Picker("Employeur", selection: $selectedEmployer) {
                        Text("Aucun").tag(Optional<Employer>.none)
                        ForEach(employers) { employer in
                            Text(employer.name ?? "").tag(Optional(employer))
                        }
                    }
                }

                Section(header: Text("Description (optionnelle)")) {
                    TextEditor(text: $details)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Modifier Profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { saveChanges() }
                }
            }
            .alert("Erreur", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func saveChanges() {
        guard !name.isEmpty else {
            alertMessage = "Veuillez entrer un nom"
            showingAlert = true
            return
        }
        let brutChanged = profile.tauxBrutValue != calculator.brut
        profile.name = name
        profile.tauxBrutValue = calculator.brut
        profile.tauxNetValue = calculator.net
        profile.tauxPourcentageValue = calculator.pourcentage
        profile.weekendSurchargePercentValue = Double(weekendSurchargeText.replacingOccurrences(of: ",", with: ".")).map { $0 / 100 }
        profile.holidaySurchargePercentValue = Double(holidaySurchargeText.replacingOccurrences(of: ",", with: ".")).map { $0 / 100 }
        profile.details = details
        profile.employer = selectedEmployer
        if let profileId = profile.id, let brut = calculator.brut, brutChanged {
            RateHistoryStore.append(rate: brut, for: profileId)
        }
        do {
            try viewContext.save()
            dismiss()
        } catch {
            alertMessage = "Erreur lors de la sauvegarde : \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

/// Section de formulaire partagée par Add/EditOvertimeProfileView : les 3 champs liés
/// brut/net/pourcentage, pilotés par un `TauxCalculator`. Un champ recalculé automatiquement
/// (absent de `calculator.manualEditHistory`) s'affiche en lecture seule, texte secondaire,
/// avec un libellé "calculé" — dès qu'il est modifié à la main il redevient éditable.
struct TauxFieldsSection: View {
    @Binding var calculator: TauxCalculator

    var body: some View {
        Section(header: Text("Taux horaire")) {
            rateField(label: "Taux brut (€)", field: .brut, value: calculator.brut) { newValue in
                calculator.fieldEdited(.brut, newValue: newValue)
            }
            rateField(label: "Taux net (€)", field: .net, value: calculator.net) { newValue in
                calculator.fieldEdited(.net, newValue: newValue)
            }
            percentageField()
        }
    }

    @ViewBuilder
    private func rateField(label: String, field: TauxField, value: Double?, onCommit: @escaping (Double?) -> Void) -> some View {
        let isComputed = value != nil && !calculator.isManuallyEdited(field)
        VStack(alignment: .leading, spacing: 2) {
            TextField(label, text: textBinding(for: value, onCommit: onCommit))
                .keyboardType(.decimalPad)
                .foregroundColor(isComputed ? .secondary : .primary)
            if isComputed {
                Text("Calculé automatiquement")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private func percentageField() -> some View {
        let isComputed = calculator.pourcentage != nil && !calculator.isManuallyEdited(.pourcentage)
        VStack(alignment: .leading, spacing: 2) {
            TextField("Taux de prélèvement (%)", text: percentageBinding)
                .keyboardType(.decimalPad)
                .foregroundColor(isComputed ? .secondary : .primary)
            if isComputed {
                Text("Calculé automatiquement")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func textBinding(for value: Double?, onCommit: @escaping (Double?) -> Void) -> Binding<String> {
        Binding<String>(
            get: { value.map { String(format: "%.2f", $0) } ?? "" },
            set: { newText in
                onCommit(newText.isEmpty ? nil : Double(newText.replacingOccurrences(of: ",", with: ".")))
            }
        )
    }

    /// Le pourcentage est un taux de prélèvement (charges, cotisations...), stocké en fraction
    /// (0.10 pour "10% prélevé") mais édité par l'utilisateur en 0-100.
    private var percentageBinding: Binding<String> {
        Binding<String>(
            get: { calculator.pourcentage.map { String(format: "%.0f", $0 * 100) } ?? "" },
            set: { newText in
                let newValue = newText.isEmpty ? nil : Double(newText.replacingOccurrences(of: ",", with: "."))
                calculator.fieldEdited(.pourcentage, newValue: newValue.map { $0 / 100 })
            }
        )
    }
}

#Preview {
    NavigationStack {
        RateProfileSettingsView()
            .environment(\.managedObjectContext, CoreDataManager.shared.container.viewContext)
    }
}