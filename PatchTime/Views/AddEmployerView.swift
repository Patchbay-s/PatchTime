import SwiftUI

struct AddEmployerView: View {
    @Environment(\.dismiss) private var dismiss

    var employer: Employer? = nil

    @State private var name: String
    @State private var siret: String
    @State private var notes: String

    init(employer: Employer? = nil) {
        self.employer = employer
        _name = State(initialValue: employer?.name ?? "")
        _siret = State(initialValue: employer?.siret ?? "")
        _notes = State(initialValue: employer?.notes ?? "")
    }

    private var isEditing: Bool { employer != nil }
    private var isSaveDisabled: Bool { name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Informations")) {
                    TextField("Nom de l'employeur", text: $name)
                    TextField("14 chiffres", text: $siret)
                        .keyboardType(.numberPad)
                }
                Section(header: Text("Notes (optionnel)")) {
                    TextField("Notes", text: $notes)
                }
            }
            .navigationTitle(isEditing ? "Modifier l'employeur" : "Nouvel employeur")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        save()
                    }
                    .disabled(isSaveDisabled)
                }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedSiret = siret.trimmingCharacters(in: .whitespaces)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)

        if let existing = employer {
            CoreDataManager.shared.updateEmployer(
                existing,
                name: trimmedName,
                siret: trimmedSiret.isEmpty ? nil : trimmedSiret,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes
            )
        } else {
            CoreDataManager.shared.addEmployer(
                name: trimmedName,
                siret: trimmedSiret.isEmpty ? nil : trimmedSiret,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes
            )
        }
        dismiss()
    }
}

#Preview {
    AddEmployerView()
}
