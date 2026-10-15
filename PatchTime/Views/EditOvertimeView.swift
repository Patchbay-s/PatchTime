import SwiftUI

struct EditOvertimeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \OvertimeProfile.name, ascending: true)],
        animation: .default)
    private var profiles: FetchedResults<OvertimeProfile>
    
    let entry: OvertimeEntry
    
    /// Date, heures et choix Même jour / Lendemain (+1 j) — logique dans `OvertimeTimeInput`.
    @State private var timeInput: OvertimeTimeInput
    @State private var location: String
    @State private var reason: String
    @State private var selectedProfileId: UUID?
    @State private var type: String
    @State private var isValidated: Bool
    
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingProfileSheet = false
    @State private var showToast = false
    @State private var profileToEdit: OvertimeProfile?
    @AppStorage("lastOvertimeProfileId") private var lastOvertimeProfileId: String = ""
    
    init(entry: OvertimeEntry) {
        self.entry = entry
        // Heures ramenées au pas de 15 min des roues, comme avant ; le +1 j enregistré est conservé.
        _timeInput = State(initialValue: OvertimeTimeInput(
            day: entry.date ?? Date(),
            start: roundedToAllowedMinute(date: entry.startTime ?? Date()),
            end: roundedToAllowedMinute(date: entry.endTime ?? Date())
        ))
        _location = State(initialValue: entry.location ?? "")
        _reason = State(initialValue: entry.reason ?? "")
        _selectedProfileId = State(initialValue: entry.profileID)
        _type = State(initialValue: entry.type ?? "sup")
        _isValidated = State(initialValue: entry.value(forKey: "isValidated") as? Bool ?? false)
    }
    
    var selectedProfile: OvertimeProfile? {
        profiles.first(where: { $0.id == selectedProfileId })
    }

    private var isFormValid: Bool {
        selectedProfileId != nil && timeInput.isValid && (selectedProfile?.hasUsableRate ?? false)
    }

    /// Début/fin réels, avec le choix Même jour / Lendemain (+1 j).
    private var resolvedRange: (start: Date, end: Date) {
        timeInput.range()
    }

    private var amountPreviewBrut: Double? {
        guard let profile = selectedProfile, let rate = profile.tauxBrutValue else { return nil }
        let hours = overtimeDuration(from: resolvedRange.start, to: resolvedRange.end) / 3600
        return ReportRowCalculator.computeEarnings(hours: hours, rate: rate, isRecup: type == "recup")
    }

    private var amountPreviewNet: Double? {
        guard let profile = selectedProfile, let rate = profile.tauxNetValue else { return nil }
        let hours = overtimeDuration(from: resolvedRange.start, to: resolvedRange.end) / 3600
        return ReportRowCalculator.computeEarnings(hours: hours, rate: rate, isRecup: type == "recup")
    }

    private static let noUsableRateMessage = "Ce profil n'a aucun taux enregistré. Renseignez au moins un taux dans les réglages du profil avant d'ajouter des heures."
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Type d'heure")) {
                    Picker("Type", selection: $type) {
                        Text("Heure supplémentaire").tag("sup")
                        Text("Récupération").tag("recup")
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(header: Text("Profil de Taux")) {
                    HStack {
                        VStack(alignment: .leading) {
                            if let profile = selectedProfile {
                                Text(profile.name ?? "")
                                    .font(.headline)
                                Text(rateLabel(for: profile))
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            } else {
                                Text("Sélectionner un profil")
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Button(action: { showingProfileSheet = true }) {
                            Image(systemName: "pencil.circle")
                                .foregroundColor(.blue)
                        }
                    }

                    if let profile = selectedProfile, !profile.hasUsableRate {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(Self.noUsableRateMessage, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Button("Modifier le profil") {
                                profileToEdit = profile
                            }
                            .font(.caption.weight(.semibold))
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section(header: Text("Date et Heures")) {
                    OvertimeTimeFields(input: $timeInput)
                }
                
                Section(header: Text("Détails (optionnel)")) {
                    TextField("Lieu", text: $location)
                    TextField("Motif", text: $reason)
                }

                if let profile = selectedProfile, profile.hasUsableRate {
                    Section(header: Text("Prévisualisation")) {
                        if let brut = amountPreviewBrut {
                            HStack {
                                Text("Montant brut estimé")
                                Spacer()
                                Text(formattedCurrency(brut, currency: "€"))
                                    .foregroundColor(brut >= 0 ? .green : .orange)
                                    .fontWeight(.semibold)
                            }
                        }
                        if let net = amountPreviewNet {
                            HStack {
                                Text("Montant net estimé")
                                Spacer()
                                Text(formattedCurrency(net, currency: "€"))
                                    .foregroundColor(net >= 0 ? .green : .orange)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
                
                Section(header: Text("Validation")) {
                    Toggle("Validé", isOn: $isValidated)
                }
            }
            .navigationTitle(type == "sup" ? "Modifier Heure Sup" : "Modifier Récupération")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        saveChanges()
                    }
                    .disabled(!isFormValid)
                }
            }
            .alert("Erreur", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showingProfileSheet) {
                ProfileSelectionView(selectedProfileId: $selectedProfileId)
            }
            .sheet(item: $profileToEdit) { profile in
                EditOvertimeProfileView(profile: profile)
            }
        }
        .toast(isPresented: $showToast, message: "Modifications enregistrées")
    }


    private func rateLabel(for profile: OvertimeProfile) -> String {
        switch (profile.tauxBrutValue, profile.tauxNetValue) {
        case let (.some(b), .some(n)): return String(format: "%.2f€/h brut · %.2f€/h net", b, n)
        case let (.some(b), .none): return String(format: "%.2f€/h brut", b)
        case let (.none, .some(n)): return String(format: "%.2f€/h net", n)
        case (.none, .none): return "Aucun taux enregistré"
        }
    }

    private func saveChanges() {
        let range = resolvedRange
        if let problem = timeInput.problem {
            alertMessage = problem.message
            showingAlert = true
            return
        }

        guard selectedProfileId != nil else {
            alertMessage = "Veuillez sélectionner un profil de taux"
            showingAlert = true
            return
        }

        guard selectedProfile?.hasUsableRate ?? false else {
            alertMessage = Self.noUsableRateMessage
            showingAlert = true
            return
        }

        entry.date = timeInput.day
        entry.startTime = range.start
        entry.endTime = range.end
        entry.location = location
        entry.reason = reason
        entry.profileID = selectedProfileId
        entry.employerID = selectedProfile?.employer?.id
        entry.type = type
        entry.setValue(isValidated, forKey: "isValidated")
        if let selectedProfileId {
            lastOvertimeProfileId = selectedProfileId.uuidString
        }
        
        do {
            try viewContext.save()
            showToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { dismiss() }
        } catch {
            alertMessage = "Impossible d'enregistrer les modifications : \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

struct ProfileSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \OvertimeProfile.name, ascending: true)],
        animation: .default)
    private var profiles: FetchedResults<OvertimeProfile>
    
    @Binding var selectedProfileId: UUID?
    
    var body: some View {
        NavigationStack {
            List(profiles) { profile in
                Button(action: {
                    selectedProfileId = profile.id
                    dismiss()
                }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(profile.name ?? "")
                                .font(.headline)
                            if !profile.hasUsableRate {
                                Text("Aucun taux enregistré")
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                            }
                            if let details = profile.details, !details.isEmpty {
                                Text(details)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        Spacer()
                        if profile.id == selectedProfileId {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Sélectionner un Profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    EditOvertimeView(entry: OvertimeEntry())
        .environment(\.managedObjectContext, CoreDataManager.shared.container.viewContext)
} 