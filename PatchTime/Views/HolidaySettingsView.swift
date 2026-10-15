import SwiftUI

struct HolidaySettingsView: View {
    @EnvironmentObject private var holidayManager: HolidayManager

    @AppStorage("holidayCountryZone") private var holidayCountryZoneRaw: String = HolidayZone.metropole.rawValue

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \PublicHoliday.date, ascending: true)],
        animation: .default)
    private var holidays: FetchedResults<PublicHoliday>

    @State private var showingAddSheet = false
    @State private var editingHoliday: PublicHoliday?
    @State private var isSyncing = false

    private var selectedZone: HolidayZone {
        get { HolidayZone(rawValue: holidayCountryZoneRaw) ?? .metropole }
    }

    /// Filtré en mémoire (une douzaine d'entrées par zone, pas besoin d'un predicate CoreData
    /// dynamique) — corrige B3 : la section affichait auparavant toutes les zones mélangées,
    /// indépendamment de la zone sélectionnée ci-dessus.
    private var filteredHolidays: [PublicHoliday] {
        holidays.filter { $0.zone == selectedZone }
    }

    var body: some View {
        Form {
            Section(header: Text("Pays / zone de référence")) {
                Picker("Zone", selection: $holidayCountryZoneRaw) {
                    ForEach(HolidayZone.allCases) { zone in
                        Text(zone.label).tag(zone.rawValue)
                    }
                }

                Button {
                    Task {
                        isSyncing = true
                        let year = Calendar.current.component(.year, from: Date())
                        await holidayManager.syncIfNeeded(zone: selectedZone, year: year, force: true)
                        await holidayManager.syncIfNeeded(zone: selectedZone, year: year + 1, force: true)
                        isSyncing = false
                    }
                } label: {
                    HStack {
                        Text("Rafraîchir depuis le calendrier officiel")
                        if isSyncing { Spacer(); ProgressView() }
                    }
                }
                .disabled(isSyncing || !selectedZone.isFetchableFromAPI)

                if !selectedZone.isFetchableFromAPI {
                    Text("Monaco n'a pas d'API officielle : la liste ci-dessous est une base éditable, à vérifier chaque année.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text("Liste effective (\(selectedZone.label))")) {
                if filteredHolidays.isEmpty {
                    Text("Aucun jour férié enregistré pour cette zone.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                ForEach(filteredHolidays) { holiday in
                    HolidayRow(holiday: holiday)
                        .contentShape(Rectangle())
                        .onTapGesture { editingHoliday = holiday }
                }
                .onDelete(perform: deleteHolidays)
            }
        }
        .navigationTitle("Pays / jours fériés")
        .toolbar {
            Button(action: { showingAddSheet = true }) {
                Image(systemName: "plus")
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddPublicHolidayView(zone: selectedZone)
        }
        .sheet(item: $editingHoliday) { holiday in
            AddPublicHolidayView(zone: holiday.zone, holiday: holiday)
        }
    }

    private func deleteHolidays(offsets: IndexSet) {
        withAnimation {
            offsets.map { filteredHolidays[$0] }.forEach { CoreDataManager.shared.deletePublicHoliday($0) }
        }
    }
}

struct HolidayRow: View {
    let holiday: PublicHoliday

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(holiday.label ?? "")
                    .font(.headline)
                if let date = holiday.date {
                    Text(SharedFormatters.frenchLongDate.string(from: date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Text(holiday.zone.label)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.15))
                .cornerRadius(4)
        }
    }
}

struct AddPublicHolidayView: View {
    @Environment(\.dismiss) private var dismiss

    let zone: HolidayZone
    var holiday: PublicHoliday? = nil

    @State private var label: String
    @State private var date: Date

    init(zone: HolidayZone, holiday: PublicHoliday? = nil) {
        self.zone = zone
        self.holiday = holiday
        _label = State(initialValue: holiday?.label ?? "")
        _date = State(initialValue: holiday?.date ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Libellé", text: $label)
                DatePicker("Date", selection: $date, displayedComponents: .date)
            }
            .navigationTitle(holiday == nil ? "Nouveau jour férié" : "Modifier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                        .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmedLabel = label.trimmingCharacters(in: .whitespaces)
        if let existing = holiday {
            CoreDataManager.shared.updatePublicHoliday(existing, date: date, label: trimmedLabel, zone: zone)
        } else {
            CoreDataManager.shared.addPublicHoliday(date: date, label: trimmedLabel, zone: zone, source: .custom, isUserEdited: true)
        }
        dismiss()
    }
}

#Preview {
    NavigationStack {
        HolidaySettingsView()
            .environment(\.managedObjectContext, CoreDataManager.shared.container.viewContext)
            .environmentObject(HolidayManager())
    }
}
