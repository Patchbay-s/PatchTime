import SwiftUI

/// Écran "Contrat" d'un employeur — regroupe la gestion des contrats et la Semaine type.
struct ContractListView: View {
    let employer: Employer

    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest private var contracts: FetchedResults<Contract>

    @State private var showingAddSheet = false
    @State private var editingContract: Contract?

    private struct DayState: Identifiable {
        let weekday: Weekday
        var isWorked: Bool
        var hoursText: String
        var id: Int { weekday.rawValue }
    }

    @State private var typicalWeekEnabled: Bool
    @State private var dayStates: [DayState]

    init(employer: Employer) {
        self.employer = employer
        _contracts = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Contract.startDate, ascending: false)],
            predicate: NSPredicate(format: "employer == %@", employer),
            animation: .default
        )
        _typicalWeekEnabled = State(initialValue: employer.typicalWeekEnabled)
        _dayStates = State(initialValue: employer.typicalWeekDays.map { day in
            DayState(weekday: day.weekday, isWorked: day.isWorked, hoursText: day.hours.map { String(format: "%.1f", $0) } ?? "")
        })
    }

    private var weeklyTotal: Double {
        dayStates
            .filter { $0.isWorked }
            .compactMap { Double($0.hoursText.replacingOccurrences(of: ",", with: ".")) }
            .reduce(0, +)
    }

    private var distanceText: String {
        employer.kmDistanceRoundTripValue.map { String(format: "%.0f km", $0) } ?? "non renseignée"
    }

    var body: some View {
        List {
            contractsSection
            typicalWeekSection
        }
        .navigationTitle("Contrat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingAddSheet = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddContractView(employer: employer)
        }
        .sheet(item: $editingContract) { contract in
            AddContractView(employer: employer, contract: contract)
        }
    }

    @ViewBuilder
    private var contractsSection: some View {
        Section(header: Text("Contrats")) {
            if contracts.isEmpty {
                Text("Aucun contrat pour \(employer.name ?? "cet employeur"). Ajoutez-en un avec le bouton +.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(contracts) { contract in
                    ContractRowView(contract: contract, editingContract: $editingContract)
                }
                .onDelete(perform: deleteContracts)
            }
        }
    }

    @ViewBuilder
    private var typicalWeekSection: some View {
        Section(header: Text("Semaine type")) {
            Toggle("Semaine type active", isOn: $typicalWeekEnabled)
        }
        Section(
            header: Text("Jours travaillés"),
            footer: Text("Distance aller-retour domicile-travail : \(distanceText) (modifiable depuis la fiche employeur).")
        ) {
            ForEach($dayStates) { $day in
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(day.weekday.label, isOn: $day.isWorked)
                    if day.isWorked {
                        HStack {
                            Text("Heures")
                            Spacer()
                            TextField("0", text: $day.hoursText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        Section {
            HStack {
                Text("Total hebdomadaire")
                Spacer()
                Text(String(format: "%.1f h", weeklyTotal))
                    .foregroundColor(.secondary)
            }
            Button("Enregistrer la semaine type") {
                saveTypicalWeek()
            }
        }
    }

    private func deleteContracts(offsets: IndexSet) {
        withAnimation {
            offsets.map { contracts[$0] }.forEach { CoreDataManager.shared.deleteContract($0) }
        }
    }

    private func saveTypicalWeek() {
        employer.typicalWeekEnabled = typicalWeekEnabled
        for day in dayStates {
            let hours = day.isWorked ? Double(day.hoursText.replacingOccurrences(of: ",", with: ".")) : nil
            employer.setTypicalWeekDay(day.weekday, isWorked: day.isWorked, hours: hours)
        }
        do {
            try viewContext.save()
        } catch {
            print("Error saving typical week: \(error.localizedDescription)")
        }
    }
}

struct ContractRowView: View {
    let contract: Contract
    @Binding var editingContract: Contract?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(contract.contractType.label)
                        .font(.headline)
                    if contract.endDate == nil, contract.contractType != .cdi {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }
                if let start = contract.startDate {
                    if let end = contract.endDate {
                        Text("Du \(SharedFormatters.frenchLongDate.string(from: start)) au \(SharedFormatters.frenchLongDate.string(from: end))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Depuis le \(SharedFormatters.frenchLongDate.string(from: start))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                if let hours = contract.weeklyContractHoursValue {
                    Text("\(hours, specifier: "%.1f") h / semaine")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Button {
                editingContract = contract
            } label: {
                Image(systemName: "pencil.circle")
                    .foregroundColor(.blue)
                    .font(.title2)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { editingContract = contract }
    }
}

#Preview {
    let context = CoreDataManager.shared.container.viewContext
    let employer = Employer(context: context)
    employer.id = UUID()
    employer.name = "Compagnie Aparté"
    return NavigationStack {
        ContractListView(employer: employer)
            .environment(\.managedObjectContext, context)
    }
}
