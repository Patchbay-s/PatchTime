import SwiftUI
import CoreData

/// Le tableau de bord "Repas" a été fusionné dans OvertimeListView (Chantier 6, sélecteur
/// segmenté "Heures Sup" / "Repas") — ce fichier ne garde plus que les vues réutilisées par
/// cette fusion (MealEntryRow, EditMealView).
struct MealEntryRow: View {
    @Environment(\.managedObjectContext) private var viewContext
    let entry: MealEntry
    let employer: Employer?
    let onDelete: () -> Void
    let onArchive: () -> Void
    
    var validationColor: Color {
        let isValidated = entry.value(forKey: "isValidated") as? Bool ?? false
        return isValidated ? .blue : .primary
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
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        toggleValidation()
                    }) {
                        Image(systemName: isValidated ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(isValidated ? .blue : .secondary)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isValidated ? "Marquer comme non validé" : "Marquer comme validé")
                }
                if let mealType = entry.mealType, !mealType.isEmpty {
                    Text(mealType)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if let employer = employer {
                    Text(employer.name ?? "")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                } else {
                    Text("Sans employeur")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
            .tint(isValidated ? .orange : .blue)
        }
    }
    
    private func formattedDate(from date: Date?) -> String {
        guard let date = date else { return "" }
        return SharedFormatters.frenchLongDate.string(from: date)
    }

    private func duplicateEntry() {
        CoreDataManager.shared.addMealEntry(
            date: Date(),
            mealType: entry.mealType ?? "",
            category: entry.category,
            employerID: entry.employerID
        )
    }

    private func toggleValidation() {
        // Utiliser setValue pour éviter les erreurs si l'attribut n'est pas encore reconnu
        let currentValue = entry.value(forKey: "isValidated") as? Bool ?? false
        entry.setValue(!currentValue, forKey: "isValidated")
        do {
            try viewContext.save()
        } catch {
            print("Error toggling validation: \(error.localizedDescription)")
        }
    }
}

struct EditMealView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let entry: MealEntry
    
    let mealTypes = ["Déjeuner", "Dîner", "Autre"]

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Employer.name, ascending: true)],
        animation: .default)
    private var employers: FetchedResults<Employer>

    @State private var date: Date
    @State private var selectedMealType: String
    @State private var selectedEmployer: Employer?
    @State private var isValidated: Bool
    @State private var showToast = false

    init(entry: MealEntry) {
        self.entry = entry
        _date = State(initialValue: entry.date ?? Date())
        _selectedMealType = State(initialValue: entry.mealType ?? "Déjeuner")
        _isValidated = State(initialValue: entry.value(forKey: "isValidated") as? Bool ?? false)
        _selectedEmployer = State(initialValue: nil) // résolu dans .onAppear une fois le @FetchRequest peuplé
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Date")) {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                Section(header: Text("Employeur")) {
                    Picker("Employeur", selection: $selectedEmployer) {
                        Text("Sans employeur").tag(Optional<Employer>.none)
                        ForEach(employers) { employer in
                            Text(employer.name ?? "").tag(Optional(employer))
                        }
                    }
                }

                Section(header: Text("Type de repas")) {
                    Picker("Type", selection: $selectedMealType) {
                        ForEach(mealTypes, id: \.self) { type in
                            Text(type)
                        }
                    }
                }

                Section(header: Text("Validation")) {
                    Toggle("Validé", isOn: $isValidated)
                }
            }
            .navigationTitle("Modifier Repas")
            .navigationBarTitleDisplayMode(.inline)
            .toast(isPresented: $showToast, message: "Repas modifié")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Enregistrer") {
                        saveChanges()
                    }
                }
            }
            .onAppear {
                selectedEmployer = entry.employerID.flatMap { id in employers.first(where: { $0.id == id }) }
            }
        }
    }

    private func saveChanges() {
        CoreDataManager.shared.updateMealEntry(
            entry,
            date: date,
            mealType: selectedMealType,
            category: entry.category,
            employerID: selectedEmployer?.id
        )
        entry.setValue(isValidated, forKey: "isValidated")
        CoreDataManager.shared.save()
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { dismiss() }
    }
}

