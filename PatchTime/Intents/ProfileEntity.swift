import AppIntents
import CoreData

/// Représente un profil de taux horaire pour les raccourcis Siri/App Intents. Le paramètre
/// exposé à Siri est le profil (et non l'employeur) car c'est le profil qui porte le taux
/// horaire nécessaire pour valoriser une entrée — un employeur peut avoir plusieurs profils.
struct ProfileEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Profil de taux"
    static var defaultQuery = ProfileEntityQuery()

    var id: UUID
    var name: String
    var employerName: String?

    var displayRepresentation: DisplayRepresentation {
        if let employerName, !employerName.isEmpty {
            DisplayRepresentation(title: "\(name)", subtitle: "\(employerName)")
        } else {
            DisplayRepresentation(title: "\(name)")
        }
    }
}

struct ProfileEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [ProfileEntity] {
        await MainActor.run {
            Self.fetchAllProfiles().filter { identifiers.contains($0.id) }
        }
    }

    func suggestedEntities() async throws -> [ProfileEntity] {
        await MainActor.run { Self.fetchAllProfiles() }
    }

    func defaultResult() async -> ProfileEntity? {
        (try? await suggestedEntities())?.first
    }

    @MainActor
    static func fetchAllProfiles() -> [ProfileEntity] {
        let request: NSFetchRequest<OvertimeProfile> = OvertimeProfile.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \OvertimeProfile.name, ascending: true)]
        let profiles = (try? CoreDataManager.shared.container.viewContext.fetch(request)) ?? []
        return profiles.compactMap { profile in
            guard let id = profile.id else { return nil }
            return ProfileEntity(id: id, name: profile.name ?? "", employerName: profile.employer?.name)
        }
    }
}
