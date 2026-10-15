import Foundation

struct ReportRow {
    let date: Date
    let profileName: String
    let isRecup: Bool
    let isValidated: Bool
    let hours: Double            // signé : négatif si récupération
    let earnings: Double         // meilleur taux disponible (net > brut > 0) — utilisé par les
                                  // vues à un seul chiffre (dashboard, tri, bilan annuel)
    let earningsBrut: Double?    // nil si tauxBrut inconnu pour le profil de cette entrée
    let earningsNet: Double?     // nil si tauxNet inconnu pour le profil de cette entrée
}

enum ReportRowCalculator {
    static func makeRow(entry: OvertimeEntry, profileMap: [UUID: OvertimeProfile], holidays: [PublicHoliday]) -> ReportRow {
        let isRecup = entry.type == "recup"
        let profile = entry.profileID.flatMap { profileMap[$0] }
        let isValidated = entry.value(forKey: "isValidated") as? Bool ?? false

        var unsignedHours = 0.0
        if let start = entry.startTime, let end = entry.endTime {
            unsignedHours = end.timeIntervalSince(start) / 3600
        }
        let signedHours = isRecup ? -unsignedHours : unsignedHours

        // La majoration ne s'applique jamais à une récupération (temps pris, pas travaillé).
        let multiplier = isRecup ? 1.0 : OvertimeSurcharge.multiplier(for: entry, profile: profile, holidays: holidays)

        let earnings = computeEarnings(hours: unsignedHours, rate: bestEffortRate(for: profile) * multiplier, isRecup: isRecup)
        let earningsBrut = profile?.tauxBrutValue.map { computeEarnings(hours: unsignedHours, rate: $0 * multiplier, isRecup: isRecup) }
        let earningsNet = profile?.tauxNetValue.map { computeEarnings(hours: unsignedHours, rate: $0 * multiplier, isRecup: isRecup) }

        return ReportRow(
            date: entry.date ?? .distantPast,
            profileName: profile?.name ?? "—",
            isRecup: isRecup,
            isValidated: isValidated,
            hours: signedHours,
            earnings: earnings,
            earningsBrut: earningsBrut,
            earningsNet: earningsNet
        )
    }

    /// Calcul canonique du montant à partir d'un taux déjà résolu : négatif pour une récupération.
    static func computeEarnings(hours: Double, rate: Double, isRecup: Bool) -> Double {
        isRecup ? -(hours * rate) : (hours * rate)
    }

    /// Meilleur taux disponible pour un affichage à un seul chiffre : net en priorité (c'est ce
    /// que l'utilisateur touche réellement), sinon brut, sinon 0 si aucun taux connu.
    static func bestEffortRate(for profile: OvertimeProfile?) -> Double {
        profile?.tauxNetValue ?? profile?.tauxBrutValue ?? 0
    }
}
