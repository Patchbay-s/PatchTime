import SwiftUI
import CoreData

struct EmployerListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Employer.name, ascending: true)],
        animation: .default
    ) private var employers: FetchedResults<Employer>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \OvertimeEntry.date, ascending: false)]
    ) private var allEntries: FetchedResults<OvertimeEntry>

    @FetchRequest(
        sortDescriptors: [],
        predicate: NSPredicate(format: "employer == nil")
    ) private var unassignedProfiles: FetchedResults<OvertimeProfile>

    @State private var showingAddSheet = false
    @State private var editingEmployer: Employer?
    var body: some View {
        // Pas de NavigationView ici : cet écran n'est jamais présenté qu'en push, depuis
        // SettingsView ou RatesSettingsView (toujours déjà dans une NavigationStack) —
        // s'auto-envelopper créait une seconde chaîne de navigation, donc un second bouton
        // retour une fois poussé plus loin vers Taux/Contrat (Chantier B).
        Group {
            if employers.isEmpty {
                EmptyStateView(
                    icon: "building.2",
                    title: "Aucun employeur",
                    subtitle: "Ajoutez-en avec le bouton +."
                )
            } else {
                List {
                    if !unassignedProfiles.isEmpty {
                        Section {
                            NavigationLink(destination: RateProfileSettingsView(employer: nil)) {
                                Label("Profils sans employeur (\(unassignedProfiles.count))", systemImage: "eurosign.circle")
                            }
                        }
                    }
                    ForEach(employers) { employer in
                        employerSection(for: employer)
                    }
                }
            }
        }
        .navigationTitle("Employeurs / Contrats")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddEmployerView()
        }
        .sheet(item: $editingEmployer) { employer in
            AddEmployerView(employer: employer)
        }
    }

    /// Un employeur = un groupe de lignes : sa fiche (nom/SIRET/notes, tap pour modifier,
    /// swipe pour supprimer), suivie de 2 lignes de navigation simples — Taux, puis Contrat
    /// (qui regroupe désormais la gestion des contrats et la Semaine type associée, plutôt
    /// qu'une ligne "Semaine type" séparée).
    @ViewBuilder
    private func employerSection(for employer: Employer) -> some View {
        Section {
            EmployerInfoRow(
                employer: employer,
                entryCount: entryCount(for: employer),
                editingEmployer: $editingEmployer
            )
            NavigationLink(destination: RateProfileSettingsView(employer: employer)) {
                Label("Taux", systemImage: "eurosign.circle")
            }
            NavigationLink(destination: ContractListView(employer: employer)) {
                HStack {
                    Label("Contrat", systemImage: "doc.text")
                    Spacer()
                    if employer.typicalWeekEnabled {
                        Text("Semaine type active")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private func entryCount(for employer: Employer) -> Int {
        guard let employerID = employer.id else { return 0 }
        return allEntries.filter { $0.employerID == employerID }.count
    }
}

struct EmployerInfoRow: View {
    let employer: Employer
    let entryCount: Int
    @Binding var editingEmployer: Employer?

    var body: some View {
        HStack {
            Button {
                editingEmployer = employer
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(employer.name ?? "")
                        .font(.headline)
                    if let siret = employer.siret, !siret.isEmpty {
                        Text("SIRET : \(siret)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    if let notes = employer.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(entryCount)")
                    .font(.title3.bold())
                    .foregroundColor(.accentColor)
                Text(entryCount == 1 ? "entrée" : "entrées")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Button {
                editingEmployer = employer
            } label: {
                Image(systemName: "pencil.circle")
                    .foregroundColor(.blue)
                    .font(.title2)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                CoreDataManager.shared.deleteEmployer(employer)
            } label: {
                Label("Supprimer", systemImage: "trash")
            }
        }
    }
}

#Preview {
    NavigationStack {
        EmployerListView()
            .environment(\.managedObjectContext, CoreDataManager.shared.container.viewContext)
    }
}
