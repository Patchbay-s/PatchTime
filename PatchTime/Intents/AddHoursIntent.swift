import AppIntents
import Foundation

enum AddHoursIntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case invalidHours
    case noProfile

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .invalidHours:
            return "Le nombre d'heures doit être compris entre 0 et 24."
        case .noProfile:
            return "Aucun profil de taux n'existe. Créez-en un dans l'app avant d'utiliser ce raccourci."
        }
    }
}

struct AddHoursIntent: AppIntent {
    static var title: LocalizedStringResource = "Ajouter des heures supplémentaires"
    static var description = IntentDescription("Enregistre des heures supplémentaires dans PatchTime.")

    @Parameter(title: "Profil", description: "Le profil de taux concerné (indique l'employeur si vous en avez plusieurs).")
    var profile: ProfileEntity?

    @Parameter(title: "Heures", description: "Nombre d'heures à ajouter.", controlStyle: .field)
    var hours: Double

    static var parameterSummary: some ParameterSummary {
        Summary("Ajouter \(\.$hours) heures chez \(\.$profile)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Même plafond que la saisie manuelle : 24 h par entrée.
        guard hours > 0, hours * 3600 <= OvertimeTimeRange.maxDuration else {
            throw AddHoursIntentError.invalidHours
        }

        let resolvedProfile: ProfileEntity
        if let profile {
            resolvedProfile = profile
        } else {
            let all = ProfileEntityQuery.fetchAllProfiles()
            guard !all.isEmpty else { throw AddHoursIntentError.noProfile }
            if all.count == 1, let only = all.first {
                // Cas mono-profil : pas besoin de demander de préciser.
                resolvedProfile = only
            } else {
                // Plusieurs profils existent et aucun n'a été précisé dans la phrase :
                // demande explicitement à Siri/Raccourcis de désambiguïser.
                throw $profile.needsValueError("Pour quel profil ?")
            }
        }

        let now = Date()
        let calendar = Calendar.current
        let startTime = now
        let endTime = calendar.date(byAdding: .second, value: Int((hours * 3600).rounded()), to: startTime)
            ?? startTime.addingTimeInterval(hours * 3600)

        CoreDataManager.shared.addOvertimeEntry(
            date: calendar.startOfDay(for: now),
            startTime: startTime,
            endTime: endTime,
            location: "",
            reason: "Ajouté via Siri",
            profileID: resolvedProfile.id,
            type: "sup"
        )

        let hoursText = String(format: "%.1f", hours)
        return .result(dialog: "\(hoursText) heure(s) ajoutées pour \(resolvedProfile.name).")
    }
}
