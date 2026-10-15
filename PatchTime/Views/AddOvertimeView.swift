import SwiftUI

struct AddOvertimeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \OvertimeProfile.name, ascending: true)],
        animation: .default)
    private var profiles: FetchedResults<OvertimeProfile>
    
    /// Date, heures et choix Même jour / Lendemain (+1 j) — logique dans `OvertimeTimeInput`.
    @State private var timeInput: OvertimeTimeInput
    @State private var location = ""
    @State private var reason = ""
    @State private var selectedProfileId: UUID?
    @State private var type = "sup"
    
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showToast = false
    @State private var isSaving = false
    @State private var profileToEdit: OvertimeProfile?
    @AppStorage("lastOvertimeProfileId") private var lastOvertimeProfileId: String = ""

    private var isFormValid: Bool {
        selectedProfileId != nil && timeInput.isValid && (selectedProfile?.hasUsableRate ?? false)
    }

    private var selectedProfile: OvertimeProfile? {
        profiles.first(where: { $0.id == selectedProfileId })
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
    
    init() {
        // 18:00 → 19:00 le jour même par défaut.
        _timeInput = State(initialValue: OvertimeTimeInput(day: Date(), startMinutes: 18 * 60, endMinutes: 19 * 60))
    }
    
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
                
                Section(header: Text("Date et Heures")) {
                    OvertimeTimeFields(input: $timeInput)
                }
                
                Section(header: Text("Profil de Taux")) {
                    if profiles.isEmpty {
                        Text("Aucun profil disponible")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Profil", selection: $selectedProfileId) {
                            Text("Sélectionner un profil").tag(nil as UUID?)
                            ForEach(profiles) { profile in
                                Text(profile.name ?? "").tag(profile.id as UUID?)
                            }
                        }
                        .onAppear {
                            if selectedProfileId == nil,
                               let saved = UUID(uuidString: lastOvertimeProfileId),
                               profiles.contains(where: { $0.id == saved }) {
                                selectedProfileId = saved
                            }
                        }
                    }

                    if let profile = selectedProfile, !profile.hasUsableRate {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Ce profil n'a aucun taux enregistré. Renseignez au moins un taux dans les réglages du profil avant d'ajouter des heures.", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Button("Modifier le profil") {
                                profileToEdit = profile
                            }
                            .font(.caption.weight(.semibold))
                        }
                        .padding(.vertical, 4)
                    } else if selectedProfile != nil {
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
                
                Section(header: Text("Détails (optionnel)")) {
                    TextField("Lieu", text: $location)
                    TextField("Motif", text: $reason)
                }
            }
            .navigationTitle(type == "sup" ? "Nouvelle heure sup" : "Nouvelle récupération")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        saveEntry()
                    }
                    .disabled(!isFormValid || isSaving)
                }
            }
            .alert("Erreur", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .sheet(item: $profileToEdit) { profile in
                EditOvertimeProfileView(profile: profile)
            }
        }
        .toast(isPresented: $showToast, message: "Entrée enregistrée")
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func saveEntry() {
        // Sans ce garde, un double-tap sur "Enregistrer" pendant la seconde où le toast est
        // affiché (dismiss() différé, formulaire toujours rempli donc isFormValid reste vrai)
        // crée deux OvertimeEntry distincts avec les mêmes données — B3, vrai doublon en base,
        // pas un problème de rendu de liste.
        guard !isSaving else { return }

        let range = resolvedRange
        if let problem = timeInput.problem {
            alertMessage = problem.message
            showingAlert = true
            return
        }
        
        guard let profileId = selectedProfileId else {
            alertMessage = "Veuillez sélectionner un profil de taux"
            showingAlert = true
            return
        }

        guard selectedProfile?.hasUsableRate ?? false else {
            alertMessage = "Ce profil n'a aucun taux enregistré. Renseignez au moins un taux dans les réglages du profil avant d'ajouter des heures."
            showingAlert = true
            return
        }

        isSaving = true

        let newEntry = OvertimeEntry(context: viewContext)
        newEntry.id = UUID()
        newEntry.date = timeInput.day
        newEntry.startTime = range.start
        newEntry.endTime = range.end
        newEntry.location = location
        newEntry.reason = reason
        newEntry.profileID = profileId
        newEntry.employerID = selectedProfile?.employer?.id
        newEntry.type = type
        newEntry.setValue(false, forKey: "isValidated")
        newEntry.archived = false
        lastOvertimeProfileId = profileId.uuidString

        do {
            try viewContext.save()
            showToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { dismiss() }
        } catch {
            isSaving = false
            alertMessage = "Impossible d'enregistrer l'entrée : \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

#Preview {
    AddOvertimeView()
        .environment(\.managedObjectContext, CoreDataManager.shared.container.viewContext)
} 