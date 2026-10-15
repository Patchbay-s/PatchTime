import SwiftUI

enum LeaveFilter: String, CaseIterable, Identifiable {
    case all = "Tous"
    case congePaye = "Congés payés"
    case recuperation = "Récupération"
    var id: String { rawValue }
}

struct LeaveListView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \LeaveEntry.date, ascending: false)],
        animation: .default)
    private var leaveEntries: FetchedResults<LeaveEntry>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Employer.name, ascending: true)])
    private var employers: FetchedResults<Employer>

    @State private var showingAddSheet = false
    @State private var editingEntry: LeaveEntry?
    @State private var filter: LeaveFilter = .all

    private var employerMap: [UUID: Employer] {
        Dictionary(uniqueKeysWithValues: employers.compactMap { e in e.id.map { ($0, e) } })
    }

    private var filteredEntries: [LeaveEntry] {
        switch filter {
        case .all: return Array(leaveEntries)
        case .congePaye: return leaveEntries.filter { $0.leaveType == .congePaye }
        case .recuperation: return leaveEntries.filter { $0.leaveType == .recuperation }
        }
    }

    var body: some View {
        List {
            Section(header: Text("Filtre")) {
                Picker("Filtre", selection: $filter) {
                    ForEach(LeaveFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
            }

            if filteredEntries.isEmpty {
                EmptyStateView(
                    icon: "calendar.badge.minus",
                    title: "Aucune entrée",
                    subtitle: "Ajoutez un congé payé ou une récupération avec le bouton +.",
                    actionTitle: "Ajouter",
                    action: { showingAddSheet = true }
                )
            } else {
                ForEach(filteredEntries, id: \.id) { entry in
                    LeaveEntryRow(entry: entry, employer: entry.employerID.flatMap { employerMap[$0] })
                        .contentShape(Rectangle())
                        .onTapGesture { editingEntry = entry }
                }
                .onDelete(perform: deleteEntries)
            }
        }
        .navigationTitle("Congés / Récup")
        .toolbar {
            Button(action: { showingAddSheet = true }) {
                Image(systemName: "plus")
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddLeaveEntryView()
        }
        .sheet(item: $editingEntry) { entry in
            AddLeaveEntryView(entry: entry)
        }
    }

    private func deleteEntries(offsets: IndexSet) {
        withAnimation {
            offsets.map { filteredEntries[$0] }.forEach { CoreDataManager.shared.deleteLeaveEntry($0) }
        }
    }
}

struct LeaveEntryRow: View {
    let entry: LeaveEntry
    let employer: Employer?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar.badge.minus")
                        .foregroundColor(.purple)
                        .font(.caption)
                    Text(entry.leaveType.label)
                        .font(.caption)
                        .foregroundColor(.purple)
                }
                if let date = entry.date {
                    if let endDate = entry.endDate {
                        Text("Du \(SharedFormatters.frenchLongDate.string(from: date)) au \(SharedFormatters.frenchLongDate.string(from: endDate))")
                            .font(.headline)
                    } else {
                        Text(SharedFormatters.frenchLongDate.string(from: date))
                            .font(.headline)
                    }
                }
                if let employer = employer {
                    Text(employer.name ?? "")
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
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                CoreDataManager.shared.deleteLeaveEntry(entry)
            } label: {
                Label("Supprimer", systemImage: "trash")
            }
        }
    }
}

#Preview {
    NavigationStack {
        LeaveListView()
            .environment(\.managedObjectContext, CoreDataManager.shared.container.viewContext)
    }
}
