import SwiftUI
import CoreData
import UniformTypeIdentifiers

// MARK: - Modèles Codable pour le JSON de sauvegarde

private struct BackupFile: Codable {
    let version: Int
    let exportDate: Date
    var overtimeEntries: [OvertimeBackup]
    var mealEntries: [MealBackup]
    var employers: [EmployerBackup]
    var overtimeProfiles: [ProfileBackup]
}

private struct OvertimeBackup: Codable {
    let id: String
    let date: Date?
    let startTime: Date?
    let endTime: Date?
    let location: String?
    let reason: String?
    let type: String?
    let profileID: String?
    let employerID: String?
    let archived: Bool
    let isValidated: Bool
}

private struct MealBackup: Codable {
    let id: String
    let date: Date?
    let mealType: String?
    let profileID: String?
    let employerID: String?
    let archived: Bool
    let isValidated: Bool
}

private struct EmployerBackup: Codable {
    let id: String
    let name: String?
    let siret: String?
    let notes: String?
}

private struct ProfileBackup: Codable {
    let id: String
    let name: String?
    let hourlyRate: Double
    let tauxBrut: Double?
    let tauxNet: Double?
    let tauxPourcentage: Double?
    let details: String?
}

// MARK: - BackupRestoreView

struct BackupRestoreView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \OvertimeEntry.date, ascending: true)])
    private var overtimeEntries: FetchedResults<OvertimeEntry>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \MealEntry.date, ascending: true)])
    private var mealEntries: FetchedResults<MealEntry>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Employer.name, ascending: true)])
    private var employers: FetchedResults<Employer>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \OvertimeProfile.name, ascending: true)])
    private var profiles: FetchedResults<OvertimeProfile>

    // MARK: - State

    @State private var showShareSheet = false
    @State private var exportURL: URL? = nil
    @State private var isExporting = false
    @State private var exportError: String? = nil
    @State private var showExportError = false

    @State private var showDocumentPicker = false
    @State private var isRestoring = false
    @State private var showRestoreConfirmation = false
    @State private var pendingRestoreURL: URL? = nil
    @State private var restoreMessage: String? = nil
    @State private var showRestoreResult = false

    @AppStorage("backup_lastExportDate") private var lastExportDateTimestamp: Double = 0

    private var lastExportDate: Date? {
        lastExportDateTimestamp > 0 ? Date(timeIntervalSince1970: lastExportDateTimestamp) : nil
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // MARK: - Corps

    var body: some View {
        mainContent
        .navigationTitle("Sauvegarde / Restauration")
        .navigationBarTitleDisplayMode(.inline)
        .activityShareSheet(isPresented: $showShareSheet, items: exportURL.map { [$0] } ?? [])
        .fileImporter(isPresented: $showDocumentPicker, allowedContentTypes: [.json]) { result in
            // Sélecteur de fichiers natif (iPhone, iPad, Mac) ; l'accès au fichier hors
            // bac à sable est ouvert dans restore(from:).
            if case .success(let url) = result {
                pendingRestoreURL = url
                showRestoreConfirmation = true
            }
        }
        .alert("Confirmer la restauration", isPresented: $showRestoreConfirmation) {
            Button("Restaurer", role: .destructive) {
                if let url = pendingRestoreURL {
                    Task { await restore(from: url) }
                }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("La restauration ajoute les données manquantes sans supprimer les données existantes.")
        }
        .alert("Export", isPresented: $showExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "Erreur inconnue.")
        }
        .alert("Restauration terminée", isPresented: $showRestoreResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(restoreMessage ?? "")
        }
    }

    // MARK: - Contenu principal

    private var mainContent: some View {
        Form {
            // --- Export ---
            Section {
                Button {
                    Task { await exportBackup() }
                } label: {
                    HStack {
                        if isExporting {
                            ProgressView().padding(.trailing, 6)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.accentColor)
                        }
                        Text(isExporting ? "Génération en cours…" : "Exporter la sauvegarde")
                            .font(.headline)
                    }
                }
                .disabled(isExporting || isRestoring)

                if let date = lastExportDate {
                    LabeledContent("Dernière sauvegarde") {
                        Text(date, style: .date)
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                }
            } header: {
                Text("Exporter")
            } footer: {
                Text("Le fichier JSON contient toutes vos heures, repas, employeurs et profils.")
            }

            // --- Restauration ---
            Section {
                Button {
                    showDocumentPicker = true
                } label: {
                    HStack {
                        if isRestoring {
                            ProgressView().padding(.trailing, 6)
                        } else {
                            Image(systemName: "square.and.arrow.down")
                                .foregroundColor(.orange)
                        }
                        Text(isRestoring ? "Restauration en cours…" : "Restaurer depuis un fichier")
                            .font(.headline)
                    }
                }
                .disabled(isExporting || isRestoring)
            } header: {
                Text("Restaurer")
            } footer: {
                Text("Sélectionnez un fichier de sauvegarde .json. Les entrées déjà présentes ne seront pas dupliquées.")
            }

            // --- Informations ---
            Section {
                LabeledContent("Version du format") {
                    Text("1")
                        .foregroundColor(.secondary)
                }
                LabeledContent("Données incluses") {
                    Text("Heures supplémentaires, Repas, Employeurs, Profils")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                        .font(.subheadline)
                }
                LabeledContent("Heures supplémentaires") {
                    Text("\(overtimeEntries.count)")
                        .foregroundColor(.secondary)
                }
                LabeledContent("Repas") {
                    Text("\(mealEntries.count)")
                        .foregroundColor(.secondary)
                }
                LabeledContent("Employeurs") {
                    Text("\(employers.count)")
                        .foregroundColor(.secondary)
                }
                LabeledContent("Profils") {
                    Text("\(profiles.count)")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Informations")
            }
        }
    }

    // MARK: - Export

    private func exportBackup() async {
        isExporting = true
        defer { isExporting = false }

        let backup = buildBackup()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(backup) else {
            exportError = "Impossible de générer le fichier de sauvegarde."
            showExportError = true
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: Date())
        let fileName = "PatchTime_backup_\(dateStr).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: url, options: .atomic)
        } catch {
            exportError = "Impossible d'écrire le fichier : \(error.localizedDescription)"
            showExportError = true
            return
        }

        // Mémoriser la date de sauvegarde
        lastExportDateTimestamp = Date().timeIntervalSince1970
        exportURL = url
        showShareSheet = true
    }

    private func buildBackup() -> BackupFile {
        let overtime: [OvertimeBackup] = overtimeEntries.compactMap { entry in
            guard let rawID = entry.id else { return nil }
            return OvertimeBackup(
                id: rawID.uuidString,
                date: entry.date,
                startTime: entry.startTime,
                endTime: entry.endTime,
                location: entry.location,
                reason: entry.reason,
                type: entry.type,
                profileID: entry.profileID?.uuidString,
                employerID: entry.employerID?.uuidString,
                archived: entry.archived,
                isValidated: entry.isValidated
            )
        }

        let meals: [MealBackup] = mealEntries.compactMap { meal in
            guard let rawID = meal.id else { return nil }
            return MealBackup(
                id: rawID.uuidString,
                date: meal.date,
                mealType: meal.mealType,
                profileID: meal.profileID?.uuidString,
                employerID: meal.employerID?.uuidString,
                archived: meal.archived,
                isValidated: meal.isValidated
            )
        }

        let employerList: [EmployerBackup] = employers.compactMap { emp in
            guard let rawID = emp.id else { return nil }
            return EmployerBackup(
                id: rawID.uuidString,
                name: emp.name,
                siret: emp.siret,
                notes: emp.notes
            )
        }

        let profileList: [ProfileBackup] = profiles.compactMap { prof in
            guard let rawID = prof.id else { return nil }
            return ProfileBackup(
                id: rawID.uuidString,
                name: prof.name,
                hourlyRate: prof.hourlyRate,
                tauxBrut: prof.tauxBrutValue,
                tauxNet: prof.tauxNetValue,
                tauxPourcentage: prof.tauxPourcentageValue,
                details: prof.details
            )
        }

        return BackupFile(
            version: 1,
            exportDate: Date(),
            overtimeEntries: overtime,
            mealEntries: meals,
            employers: employerList,
            overtimeProfiles: profileList
        )
    }

    // MARK: - Restauration

    private func restore(from url: URL) async {
        isRestoring = true
        defer { isRestoring = false }

        // Accès sécurisé au fichier (iCloud / Documents)
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else {
            restoreMessage = "Impossible de lire le fichier sélectionné."
            showRestoreResult = true
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let backup = try? decoder.decode(BackupFile.self, from: data) else {
            restoreMessage = "Le fichier n'est pas un fichier de sauvegarde valide."
            showRestoreResult = true
            return
        }

        var added = 0

        // IDs existants pour éviter les doublons
        let existingOvertimeIDs = Set(overtimeEntries.compactMap { $0.id?.uuidString })
        let existingMealIDs = Set(mealEntries.compactMap { $0.id?.uuidString })
        let existingEmployerIDs = Set(employers.compactMap { $0.id?.uuidString })
        let existingProfileIDs = Set(profiles.compactMap { $0.id?.uuidString })

        // --- Profils ---
        for p in backup.overtimeProfiles where !existingProfileIDs.contains(p.id) {
            guard let uuid = UUID(uuidString: p.id) else { continue }
            let profile = OvertimeProfile(context: viewContext)
            profile.id = uuid
            profile.name = p.name
            profile.hourlyRate = p.hourlyRate
            // Un backup pré-migration n'a que hourlyRate : on applique la même règle que la
            // migration one-shot (CoreDataManager.migrateHourlyRateToTauxBrut) plutôt que de
            // compter sur elle, car elle a déjà pu tourner et se marquer "faite" avant cet
            // import — ce profil restauré ne serait alors jamais backfillé automatiquement.
            if p.tauxBrut == nil, p.hourlyRate > 0 {
                profile.tauxBrutValue = p.hourlyRate
            } else {
                profile.tauxBrutValue = p.tauxBrut
            }
            profile.tauxNetValue = p.tauxNet
            profile.tauxPourcentageValue = p.tauxPourcentage
            profile.details = p.details
            added += 1
        }

        // --- Employeurs ---
        for e in backup.employers where !existingEmployerIDs.contains(e.id) {
            guard let uuid = UUID(uuidString: e.id) else { continue }
            let employer = Employer(context: viewContext)
            employer.id = uuid
            employer.name = e.name
            employer.siret = e.siret
            employer.notes = e.notes
            added += 1
        }

        // --- Heures supplémentaires ---
        for o in backup.overtimeEntries where !existingOvertimeIDs.contains(o.id) {
            guard let uuid = UUID(uuidString: o.id) else { continue }
            let entry = OvertimeEntry(context: viewContext)
            entry.id = uuid
            entry.date = o.date
            entry.startTime = o.startTime
            entry.endTime = o.endTime
            entry.location = o.location
            entry.reason = o.reason
            entry.type = o.type
            entry.profileID = o.profileID.flatMap { UUID(uuidString: $0) }
            entry.employerID = o.employerID.flatMap { UUID(uuidString: $0) }
            entry.archived = o.archived
            entry.isValidated = o.isValidated
            added += 1
        }

        // --- Repas ---
        for m in backup.mealEntries where !existingMealIDs.contains(m.id) {
            guard let uuid = UUID(uuidString: m.id) else { continue }
            let meal = MealEntry(context: viewContext)
            meal.id = uuid
            meal.date = m.date
            meal.mealType = m.mealType
            meal.profileID = m.profileID.flatMap { UUID(uuidString: $0) }
            meal.employerID = m.employerID.flatMap { UUID(uuidString: $0) }
            meal.archived = m.archived
            meal.isValidated = m.isValidated
            added += 1
        }

        CoreDataManager.shared.save()

        if added == 0 {
            restoreMessage = "Toutes les données de la sauvegarde sont déjà présentes. Aucune entrée ajoutée."
        } else {
            restoreMessage = "\(added) entrée(s) importée(s) avec succès."
        }
        showRestoreResult = true
    }
}

#Preview {
    NavigationStack {
        BackupRestoreView()
            .environment(\.managedObjectContext, CoreDataManager.shared.container.viewContext)
    }
}
