import CoreData
import SwiftUI
import CloudKit

class CoreDataManager {
    static let shared = CoreDataManager()

    private let migrationKey = "migration_archivedToValidated_v1"
    // v2 : l'ancienne version pouvait se marquer "faite" à tort si le fetch échouait
    // silencieusement (store pas encore attaché) avant le correctif de ce commit ;
    // le changement de clé force un nouveau passage, sûr et idempotent, pour tout le monde.
    private let employerIDMigrationKey = "migration_backfillEmployerID_v2"
    private let hourlyRateMigrationKey = "migration_hourlyRateToTauxBrut_v1"
    private let mealEmployerIDMigrationKey = "migration_backfillMealEmployerID_v1"
    private let pourcentageSemanticsMigrationKey = "migration_pourcentageNetBrutToPrelevement_v1"
    let container: NSPersistentContainer

    init() {
        let cloudContainer = NSPersistentCloudKitContainer(name: "TimeTrackingModel")
        let description = cloudContainer.persistentStoreDescriptions.first
        description?.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        description?.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        description?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        description?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)

        let options = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.fr.antxis.apple.PatchTime"
        )
        options.databaseScope = .private
        description?.cloudKitContainerOptions = options

        container = cloudContainer

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.shouldDeleteInaccessibleFaults = true

        // Le chargement du store se fait en dernier, une fois toutes les propriétés
        // initialisées : le completion handler peut ainsi capturer `self` en toute
        // sécurité et ne déclenche les migrations qu'après confirmation que le store
        // est bien attaché (au lieu de les lancer en aveugle depuis init()).
        container.loadPersistentStores { [weak self] _, error in
            if let error {
                print("Erreur de chargement Core Data : \(error.localizedDescription)")
                return
            }
            self?.runMigrationsIfNeeded()
        }
    }

    var isCloudSyncEnabled: Bool {
        container is NSPersistentCloudKitContainer
    }
    
    // MARK: - Migration

    /// Lance les migrations one-shot restées en attente. Appelé uniquement une fois le
    /// store persistant confirmé chargé (voir `init()`).
    private func runMigrationsIfNeeded() {
        if !UserDefaults.standard.bool(forKey: migrationKey) {
            migrateArchivedEntriesToValidated()
        }
        if !UserDefaults.standard.bool(forKey: employerIDMigrationKey) {
            migrateBackfillEmployerIDs()
        }
        if !UserDefaults.standard.bool(forKey: hourlyRateMigrationKey) {
            migrateHourlyRateToTauxBrut()
        }
        if !UserDefaults.standard.bool(forKey: mealEmployerIDMigrationKey) {
            migrateBackfillMealEmployerIDs()
        }
        if !UserDefaults.standard.bool(forKey: pourcentageSemanticsMigrationKey) {
            migratePourcentageNetBrutToPrelevement()
        }
    }

    private func migrateArchivedEntriesToValidated() {
        performBackgroundTask { [migrationKey] context in
            // Migrer les heures supplémentaires archivées
            let overtimeRequest: NSFetchRequest<OvertimeEntry> = OvertimeEntry.fetchRequest()
            overtimeRequest.predicate = NSPredicate(format: "archived == YES")

            // Si le fetch échoue (store non attaché, contexte invalide…), on ne marque
            // pas la migration comme faite : elle sera retentée au prochain lancement.
            guard let archivedOvertimes = try? context.fetch(overtimeRequest) else { return }
            for entry in archivedOvertimes {
                entry.setValue(true, forKey: "isValidated")
            }

            // Migrer les repas archivés
            let mealRequest: NSFetchRequest<MealEntry> = MealEntry.fetchRequest()
            mealRequest.predicate = NSPredicate(format: "archived == YES")

            guard let archivedMeals = try? context.fetch(mealRequest) else { return }
            for entry in archivedMeals {
                let currentValue = entry.value(forKey: "isValidated") as? Bool ?? false
                if !currentValue {
                    entry.setValue(true, forKey: "isValidated")
                }
            }

            UserDefaults.standard.set(true, forKey: migrationKey)
        }
    }

    /// Renseigne rétroactivement `OvertimeEntry.employerID` (déduit du lien profil → employeur)
    /// pour les entrées créées avant que ce champ ne soit correctement rempli à la saisie.
    private func migrateBackfillEmployerIDs() {
        performBackgroundTask { [employerIDMigrationKey] context in
            let profileRequest: NSFetchRequest<OvertimeProfile> = OvertimeProfile.fetchRequest()

            // Idem : un échec de fetch (store non attaché) ne doit pas marquer la migration
            // comme faite silencieusement.
            guard let profiles = try? context.fetch(profileRequest) else { return }

            let employerIDByProfileID: [UUID: UUID] = Dictionary(uniqueKeysWithValues:
                profiles.compactMap { profile in
                    guard let profileID = profile.id, let employerID = profile.employer?.id else { return nil }
                    return (profileID, employerID)
                }
            )

            if !employerIDByProfileID.isEmpty {
                let overtimeRequest: NSFetchRequest<OvertimeEntry> = OvertimeEntry.fetchRequest()
                overtimeRequest.predicate = NSPredicate(format: "employerID == nil AND profileID != nil")

                guard let entries = try? context.fetch(overtimeRequest) else { return }
                for entry in entries {
                    guard let profileID = entry.profileID, let employerID = employerIDByProfileID[profileID] else { continue }
                    entry.employerID = employerID
                }
            }

            UserDefaults.standard.set(true, forKey: employerIDMigrationKey)
        }
    }

    /// Renseigne rétroactivement `OvertimeProfile.tauxBrut` depuis l'ancien `hourlyRate`
    /// (champ unique historique remplacé par les 3 champs liés brut/net/%). `hourlyRate`
    /// reste en base (déprécié) mais n'est plus lu par aucun code après cette migration.
    private func migrateHourlyRateToTauxBrut() {
        performBackgroundTask { [hourlyRateMigrationKey] context in
            let profileRequest: NSFetchRequest<OvertimeProfile> = OvertimeProfile.fetchRequest()

            guard let profiles = try? context.fetch(profileRequest) else { return }

            for profile in ProfileRateMigration.profilesNeedingBackfill(profiles) {
                profile.tauxBrut = NSNumber(value: profile.hourlyRate)
            }

            UserDefaults.standard.set(true, forKey: hourlyRateMigrationKey)
        }
    }

    /// Renseigne rétroactivement `MealEntry.employerID` (déduit du lien profil -> employeur),
    /// même pattern que `migrateBackfillEmployerIDs` pour `OvertimeEntry.employerID`.
    private func migrateBackfillMealEmployerIDs() {
        performBackgroundTask { [mealEmployerIDMigrationKey] context in
            let profileRequest: NSFetchRequest<OvertimeProfile> = OvertimeProfile.fetchRequest()
            guard let profiles = try? context.fetch(profileRequest) else { return }

            let employerIDByProfileID = MealEmployerMigration.employerIDsByProfileID(profiles)

            if !employerIDByProfileID.isEmpty {
                let mealRequest: NSFetchRequest<MealEntry> = MealEntry.fetchRequest()
                mealRequest.predicate = NSPredicate(format: "employerID == nil AND profileID != nil")
                guard let meals = try? context.fetch(mealRequest) else { return }

                for (meal, employerID) in MealEmployerMigration.mealsNeedingBackfill(meals, employerIDByProfileID: employerIDByProfileID) {
                    meal.employerID = employerID
                }
            }

            UserDefaults.standard.set(true, forKey: mealEmployerIDMigrationKey)
        }
    }

    /// Corrige rétroactivement la sémantique du `tauxPourcentage` déjà stocké : il était
    /// jusqu'ici un ratio net/brut, il devient un taux de prélèvement (voir
    /// `TauxCalculator.computed` et `PourcentageSemanticsMigration`). Cette migration est sa
    /// propre inverse (1 - x) : le flag one-shot est essentiel pour ne jamais la rejouer.
    private func migratePourcentageNetBrutToPrelevement() {
        performBackgroundTask { [pourcentageSemanticsMigrationKey] context in
            let profileRequest: NSFetchRequest<OvertimeProfile> = OvertimeProfile.fetchRequest()

            guard let profiles = try? context.fetch(profileRequest) else { return }

            for profile in PourcentageSemanticsMigration.profilesNeedingConversion(profiles) {
                guard let oldValue = profile.tauxPourcentageValue else { continue }
                profile.tauxPourcentageValue = PourcentageSemanticsMigration.convertedValue(from: oldValue)
            }

            UserDefaults.standard.set(true, forKey: pourcentageSemanticsMigrationKey)
        }
    }

    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Erreur de sauvegarde: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Context Operations
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask { context in
            block(context)
            if context.hasChanges {
                do {
                    try context.save()
                } catch {
                    print("Erreur de sauvegarde en arrière-plan: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - OvertimeEntry Operations
extension CoreDataManager {
    /// Point d'entrée métier partagé (Siri/App Intents, import OCR, potentiellement Watch) :
    /// crée une entrée d'heures supplémentaires en dérivant `employerID` du profil sélectionné,
    /// comme le font déjà AddOvertimeView/EditOvertimeView.
    func addOvertimeEntry(date: Date, startTime: Date, endTime: Date, location: String, reason: String, profileID: UUID?, type: String = "sup") {
        let context = container.viewContext
        let entry = OvertimeEntry(context: context)

        entry.id = UUID()
        entry.date = date
        entry.startTime = startTime
        entry.endTime = endTime
        entry.location = location
        entry.reason = reason
        entry.profileID = profileID
        entry.type = type
        entry.employerID = employerID(forProfileID: profileID)
        entry.archived = false
        entry.setValue(false, forKey: "isValidated")

        save()
    }

    func updateOvertimeEntry(_ entry: OvertimeEntry, date: Date, startTime: Date, endTime: Date, location: String, reason: String, profileID: UUID?) {
        entry.date = date
        entry.startTime = startTime
        entry.endTime = endTime
        entry.location = location
        entry.reason = reason
        entry.profileID = profileID
        entry.employerID = employerID(forProfileID: profileID)

        save()
    }

    /// Déduit l'employeur associé à un profil de taux (utilisé pour renseigner
    /// OvertimeEntry.employerID à la création/mise à jour).
    private func employerID(forProfileID profileID: UUID?) -> UUID? {
        guard let profileID else { return nil }
        let request: NSFetchRequest<OvertimeProfile> = OvertimeProfile.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", profileID as CVarArg)
        request.fetchLimit = 1
        return (try? container.viewContext.fetch(request))?.first?.employer?.id
    }
    
    func deleteOvertimeEntry(_ entry: OvertimeEntry) {
        container.viewContext.delete(entry)
        save()
    }
    
    func fetchOvertimeEntries(predicate: NSPredicate? = nil) -> [OvertimeEntry] {
        let request: NSFetchRequest<OvertimeEntry> = OvertimeEntry.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \OvertimeEntry.date, ascending: false)]
        request.predicate = predicate
        
        do {
            return try container.viewContext.fetch(request)
        } catch {
            print("Erreur de récupération des heures supplémentaires: \(error.localizedDescription)")
            return []
        }
    }
}

// MARK: - MealEntry Operations
extension CoreDataManager {
    /// Point d'entrée métier partagé pour la création d'un repas, comme `addOvertimeEntry`
    /// pour les heures sup : `employerID` est fourni directement par l'appelant (sélection
    /// d'employeur en UI), plus besoin de le déduire d'un profil intermédiaire.
    func addMealEntry(date: Date, mealType: String, category: MealCategory?, employerID: UUID?) {
        let context = container.viewContext
        let entry = MealEntry(context: context)

        entry.id = UUID()
        entry.date = date
        entry.mealType = mealType
        entry.category = category
        entry.employerID = employerID
        entry.archived = false
        entry.setValue(false, forKey: "isValidated")

        save()
    }

    func updateMealEntry(_ entry: MealEntry, date: Date, mealType: String, category: MealCategory?, employerID: UUID?) {
        entry.date = date
        entry.mealType = mealType
        entry.category = category
        entry.employerID = employerID

        save()
    }
    
    func deleteMealEntry(_ entry: MealEntry) {
        container.viewContext.delete(entry)
        save()
    }
    
    func fetchMealEntries(predicate: NSPredicate? = nil) -> [MealEntry] {
        let request: NSFetchRequest<MealEntry> = MealEntry.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MealEntry.date, ascending: false)]
        request.predicate = predicate
        
        do {
            return try container.viewContext.fetch(request)
        } catch {
            print("Erreur de récupération des repas: \(error.localizedDescription)")
            return []
        }
    }
}

// MARK: - Availability Operations
extension CoreDataManager {
    func addAvailability(date: Date, endDate: Date? = nil, notes: String? = nil, isRecurring: Bool = false, recurringPattern: String? = nil) {
        let context = container.viewContext
        let availability = Availability(context: context)

        availability.id = UUID()
        availability.date = date
        availability.endDate = endDate
        availability.notes = notes
        availability.isRecurring = isRecurring
        availability.recurringPattern = recurringPattern

        save()
    }

    func deleteAvailability(_ availability: Availability) {
        container.viewContext.delete(availability)
        save()
    }

    func fetchAvailabilities(predicate: NSPredicate? = nil) -> [Availability] {
        let request: NSFetchRequest<Availability> = Availability.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Availability.date, ascending: false)]
        request.predicate = predicate

        do {
            return try container.viewContext.fetch(request)
        } catch {
            print("Erreur de récupération des disponibilités: \(error.localizedDescription)")
            return []
        }
    }
}

// MARK: - Employer Operations
extension CoreDataManager {
    @discardableResult
    func addEmployer(name: String, siret: String?, notes: String?) -> Employer {
        let context = container.viewContext
        let employer = Employer(context: context)
        employer.id = UUID()
        employer.name = name
        employer.siret = siret
        employer.notes = notes
        save()
        return employer
    }

    func updateEmployer(_ employer: Employer, name: String, siret: String?, notes: String?) {
        employer.name = name
        employer.siret = siret
        employer.notes = notes
        save()
    }

    func deleteEmployer(_ employer: Employer) {
        let context = container.viewContext

        if let employerID = employer.id {
            let overtimeRequest: NSFetchRequest<OvertimeEntry> = OvertimeEntry.fetchRequest()
            overtimeRequest.predicate = NSPredicate(format: "employerID == %@", employerID as CVarArg)
            if let orphanedEntries = try? context.fetch(overtimeRequest) {
                orphanedEntries.forEach { $0.employerID = nil }
            }

            let mealRequest: NSFetchRequest<MealEntry> = MealEntry.fetchRequest()
            mealRequest.predicate = NSPredicate(format: "employerID == %@", employerID as CVarArg)
            if let orphanedMeals = try? context.fetch(mealRequest) {
                orphanedMeals.forEach { $0.employerID = nil }
            }
        }

        context.delete(employer)
        save()
    }

    func fetchEmployers() -> [Employer] {
        let request: NSFetchRequest<Employer> = Employer.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Employer.name, ascending: true)]
        do {
            return try container.viewContext.fetch(request)
        } catch {
            print("Erreur de récupération des employeurs: \(error.localizedDescription)")
            return []
        }
    }
}

// MARK: - PublicHoliday Operations
extension CoreDataManager {
    @discardableResult
    func addPublicHoliday(date: Date, label: String, zone: HolidayZone, source: HolidaySource, isUserEdited: Bool) -> PublicHoliday {
        let context = container.viewContext
        let holiday = PublicHoliday(context: context)
        holiday.id = UUID()
        holiday.date = date
        holiday.label = label
        holiday.zone = zone
        holiday.sourceValue = source
        holiday.isUserEdited = isUserEdited
        save()
        return holiday
    }

    /// Modifier manuellement une entrée officielle la marque `isUserEdited` (utile pour un
    /// futur "réinitialiser aux valeurs officielles" par zone, hors scope de ce plan).
    func updatePublicHoliday(_ holiday: PublicHoliday, date: Date, label: String, zone: HolidayZone) {
        holiday.date = date
        holiday.label = label
        holiday.zone = zone
        holiday.isUserEdited = true
        save()
    }

    func deletePublicHoliday(_ holiday: PublicHoliday) {
        container.viewContext.delete(holiday)
        save()
    }

    func fetchPublicHolidays(predicate: NSPredicate? = nil) -> [PublicHoliday] {
        let request: NSFetchRequest<PublicHoliday> = PublicHoliday.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PublicHoliday.date, ascending: true)]
        request.predicate = predicate

        do {
            return try container.viewContext.fetch(request)
        } catch {
            print("Erreur de récupération des jours fériés: \(error.localizedDescription)")
            return []
        }
    }
}

// MARK: - LeaveEntry Operations
extension CoreDataManager {
    func addLeaveEntry(date: Date, endDate: Date?, type: LeaveType, employerID: UUID?, reason: String?) {
        let context = container.viewContext
        let entry = LeaveEntry(context: context)

        entry.id = UUID()
        entry.date = date
        entry.endDate = endDate
        entry.leaveType = type
        entry.employerID = employerID
        entry.reason = reason
        entry.archived = false
        entry.setValue(false, forKey: "isValidated")

        save()
    }

    func updateLeaveEntry(_ entry: LeaveEntry, date: Date, endDate: Date?, type: LeaveType, employerID: UUID?, reason: String?) {
        entry.date = date
        entry.endDate = endDate
        entry.leaveType = type
        entry.employerID = employerID
        entry.reason = reason

        save()
    }

    func deleteLeaveEntry(_ entry: LeaveEntry) {
        container.viewContext.delete(entry)
        save()
    }

    func fetchLeaveEntries(predicate: NSPredicate? = nil) -> [LeaveEntry] {
        let request: NSFetchRequest<LeaveEntry> = LeaveEntry.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \LeaveEntry.date, ascending: false)]
        request.predicate = predicate

        do {
            return try container.viewContext.fetch(request)
        } catch {
            print("Erreur de récupération des congés/récup: \(error.localizedDescription)")
            return []
        }
    }
}

// MARK: - Contract Operations
extension CoreDataManager {
    @discardableResult
    func addContract(
        type: ContractType,
        startDate: Date,
        endDate: Date?,
        weeklyContractHours: Double?,
        weeklyContractDays: Double?,
        kmDistanceRoundTrip: Double?,
        employer: Employer
    ) -> Contract {
        let context = container.viewContext
        let contract = Contract(context: context)
        contract.id = UUID()
        contract.contractType = type
        contract.startDate = startDate
        contract.endDate = endDate
        contract.weeklyContractHoursValue = weeklyContractHours
        contract.weeklyContractDaysValue = weeklyContractDays
        contract.kmDistanceRoundTripValue = kmDistanceRoundTrip
        contract.employer = employer
        save()
        return contract
    }

    func updateContract(
        _ contract: Contract,
        type: ContractType,
        startDate: Date,
        endDate: Date?,
        weeklyContractHours: Double?,
        weeklyContractDays: Double?,
        kmDistanceRoundTrip: Double?
    ) {
        contract.contractType = type
        contract.startDate = startDate
        contract.endDate = endDate
        contract.weeklyContractHoursValue = weeklyContractHours
        contract.weeklyContractDaysValue = weeklyContractDays
        contract.kmDistanceRoundTripValue = kmDistanceRoundTrip
        save()
    }

    func deleteContract(_ contract: Contract) {
        container.viewContext.delete(contract)
        save()
    }

    func fetchContracts(for employer: Employer) -> [Contract] {
        let request: NSFetchRequest<Contract> = Contract.fetchRequest()
        request.predicate = NSPredicate(format: "employer == %@", employer)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Contract.startDate, ascending: false)]
        do {
            return try container.viewContext.fetch(request)
        } catch {
            print("Erreur de récupération des contrats: \(error.localizedDescription)")
            return []
        }
    }
}
