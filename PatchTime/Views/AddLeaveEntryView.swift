import SwiftUI

struct AddLeaveEntryView: View {
    @Environment(\.dismiss) private var dismiss

    var entry: LeaveEntry? = nil

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Employer.name, ascending: true)])
    private var employers: FetchedResults<Employer>

    @State private var type: LeaveType
    @State private var date: Date
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var selectedEmployer: Employer?
    @State private var reason: String

    init(entry: LeaveEntry? = nil) {
        self.entry = entry
        _type = State(initialValue: entry?.leaveType ?? .congePaye)
        _date = State(initialValue: entry?.date ?? Date())
        _hasEndDate = State(initialValue: entry?.endDate != nil)
        _endDate = State(initialValue: entry?.endDate ?? Date())
        _reason = State(initialValue: entry?.reason ?? "")
    }

    private var isEditing: Bool { entry != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Type")) {
                    Picker("Type", selection: $type) {
                        ForEach(LeaveType.allCases) { type in
                            Text(type.label).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section(header: Text("Date")) {
                    DatePicker("Date de début", selection: $date, displayedComponents: .date)
                    Toggle("Sur plusieurs jours", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("Date de fin", selection: $endDate, displayedComponents: .date)
                    }
                }
                if !employers.isEmpty {
                    Section(header: Text("Employeur (optionnel)")) {
                        Picker("Employeur", selection: $selectedEmployer) {
                            Text("Aucun").tag(Optional<Employer>.none)
                            ForEach(employers) { employer in
                                Text(employer.name ?? "").tag(Optional(employer))
                            }
                        }
                    }
                }
                Section(header: Text("Motif (optionnel)")) {
                    TextField("Motif", text: $reason)
                }
            }
            .navigationTitle(isEditing ? "Modifier" : "Nouveau congé / récup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                }
            }
            .onAppear {
                if let existingID = entry?.employerID {
                    selectedEmployer = employers.first(where: { $0.id == existingID })
                }
            }
        }
    }

    private func save() {
        let trimmedReason = reason.trimmingCharacters(in: .whitespaces)
        let resolvedEndDate = hasEndDate ? endDate : nil

        if let existing = entry {
            CoreDataManager.shared.updateLeaveEntry(
                existing,
                date: date,
                endDate: resolvedEndDate,
                type: type,
                employerID: selectedEmployer?.id,
                reason: trimmedReason.isEmpty ? nil : trimmedReason
            )
        } else {
            CoreDataManager.shared.addLeaveEntry(
                date: date,
                endDate: resolvedEndDate,
                type: type,
                employerID: selectedEmployer?.id,
                reason: trimmedReason.isEmpty ? nil : trimmedReason
            )
        }
        dismiss()
    }
}

#Preview {
    AddLeaveEntryView()
        .environment(\.managedObjectContext, CoreDataManager.shared.container.viewContext)
}
