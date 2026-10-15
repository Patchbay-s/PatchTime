import CoreData
@testable import PatchTime

enum CoreDataTestHelpers {
    /// Un seul NSManagedObjectModel pour tout le process : celui que l'app hôte a déjà chargé.
    /// Recharger le .momd à chaque test crée plusieurs entités `Employer`, `Contract`… pour la
    /// même classe ; avec les tests Swift Testing parallèles, `Employer(context:)` peut alors
    /// résoudre l'entité d'un autre modèle et l'affectation d'une relation lève une exception
    /// Objective-C (_PFManagedObject_coerceValueForKeyWithDescription) qui fait planter l'hôte.
    private static let sharedModel = CoreDataManager.shared.container.managedObjectModel

    static func makeInMemoryContext() -> NSManagedObjectContext {
        let container = NSPersistentContainer(name: "TimeTrackingModel", managedObjectModel: sharedModel)

        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        precondition(loadError == nil, "Échec du chargement du store en mémoire : \(String(describing: loadError))")

        // Pas le viewContext : il est confiné au thread principal et la run loop principale y
        // traite les changements en attente pendant que les tests Swift Testing le modifient
        // depuis le pool coopératif → NSInvalidArgumentException (« attempt to insert nil »).
        // Un contexte en file privée n'est jamais touché par la run loop principale.
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = container.persistentStoreCoordinator
        return context
    }

    @discardableResult
    static func makeProfile(
        context: NSManagedObjectContext,
        name: String,
        hourlyRate: Double = 0,
        tauxBrut: Double? = nil,
        tauxNet: Double? = nil,
        tauxPourcentage: Double? = nil
    ) -> OvertimeProfile {
        let profile = OvertimeProfile(context: context)
        profile.id = UUID()
        profile.name = name
        profile.hourlyRate = hourlyRate
        profile.tauxBrutValue = tauxBrut
        profile.tauxNetValue = tauxNet
        profile.tauxPourcentageValue = tauxPourcentage
        return profile
    }

    @discardableResult
    static func makeOvertimeEntry(
        context: NSManagedObjectContext,
        date: Date,
        startTime: Date,
        endTime: Date,
        type: String,
        profileID: UUID?,
        isValidated: Bool = false,
        archived: Bool = false
    ) -> OvertimeEntry {
        let entry = OvertimeEntry(context: context)
        entry.id = UUID()
        entry.date = date
        entry.startTime = startTime
        entry.endTime = endTime
        entry.type = type
        entry.profileID = profileID
        entry.archived = archived
        entry.setValue(isValidated, forKey: "isValidated")
        return entry
    }

    @discardableResult
    static func makeMealEntry(
        context: NSManagedObjectContext,
        date: Date,
        mealType: String,
        profileID: UUID?,
        isValidated: Bool = false,
        archived: Bool = false
    ) -> MealEntry {
        let meal = MealEntry(context: context)
        meal.id = UUID()
        meal.date = date
        meal.mealType = mealType
        meal.profileID = profileID
        meal.archived = archived
        meal.setValue(isValidated, forKey: "isValidated")
        return meal
    }
}
