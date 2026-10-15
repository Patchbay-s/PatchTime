import SwiftUI

struct AddContractView: View {
    @Environment(\.dismiss) private var dismiss

    let employer: Employer
    var contract: Contract? = nil

    @State private var type: ContractType
    @State private var startDate: Date
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var weeklyHoursText: String
    @State private var weeklyDaysText: String
    @State private var kmDistanceText: String

    init(employer: Employer, contract: Contract? = nil) {
        self.employer = employer
        self.contract = contract
        _type = State(initialValue: contract?.contractType ?? .cdi)
        _startDate = State(initialValue: contract?.startDate ?? Date())
        _hasEndDate = State(initialValue: contract?.endDate != nil)
        _endDate = State(initialValue: contract?.endDate ?? Date())
        _weeklyHoursText = State(initialValue: contract?.weeklyContractHoursValue.map { String($0) } ?? "")
        _weeklyDaysText = State(initialValue: contract?.weeklyContractDaysValue.map { String($0) } ?? "")
        _kmDistanceText = State(initialValue: contract?.kmDistanceRoundTripValue.map { String($0) } ?? "")
    }

    private var isEditing: Bool { contract != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Type de contrat")) {
                    Picker("Type", selection: $type) {
                        ForEach(ContractType.allCases) { type in
                            Text(type.label).tag(type)
                        }
                    }
                }
                Section(header: Text("Dates")) {
                    DatePicker("Date de début", selection: $startDate, displayedComponents: .date)
                    Toggle("Date de fin", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("Date de fin", selection: $endDate, displayedComponents: .date)
                    } else if type != .cdi {
                        Text("Une date de fin est recommandée pour un \(type.label).")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                Section(header: Text("Volume contractuel (optionnel)")) {
                    HStack {
                        Text("Heures / semaine")
                        Spacer()
                        TextField("ex: 35", text: $weeklyHoursText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Jours / semaine")
                        Spacer()
                        TextField("ex: 5", text: $weeklyDaysText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                Section(header: Text("Trajet domicile-travail (optionnel)")) {
                    HStack {
                        Text("Distance aller-retour (km)")
                        Spacer()
                        TextField("optionnel", text: $kmDistanceText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle(isEditing ? "Modifier le contrat" : "Nouveau contrat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                }
            }
        }
    }

    private func save() {
        let weeklyHours = Double(weeklyHoursText.replacingOccurrences(of: ",", with: "."))
        let weeklyDays = Double(weeklyDaysText.replacingOccurrences(of: ",", with: "."))
        let kmDistance = Double(kmDistanceText.replacingOccurrences(of: ",", with: "."))
        let resolvedEndDate = hasEndDate ? endDate : nil

        if let existing = contract {
            CoreDataManager.shared.updateContract(
                existing,
                type: type,
                startDate: startDate,
                endDate: resolvedEndDate,
                weeklyContractHours: weeklyHours,
                weeklyContractDays: weeklyDays,
                kmDistanceRoundTrip: kmDistance
            )
        } else {
            CoreDataManager.shared.addContract(
                type: type,
                startDate: startDate,
                endDate: resolvedEndDate,
                weeklyContractHours: weeklyHours,
                weeklyContractDays: weeklyDays,
                kmDistanceRoundTrip: kmDistance,
                employer: employer
            )
        }
        dismiss()
    }
}

#Preview {
    let context = CoreDataManager.shared.container.viewContext
    let employer = Employer(context: context)
    employer.id = UUID()
    employer.name = "Compagnie Aparté"
    return AddContractView(employer: employer)
}
