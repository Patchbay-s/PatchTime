import Foundation

/// Une ligne du barème : coefficients pour les 3 tranches kilométriques officielles
/// (≤5000 km, 5001-20000 km, >20000 km). `tier2FixedAmount` est le montant fixe additionné
/// dans la formule de la 2e tranche : `(d × tier2Coefficient) + tier2FixedAmount`.
struct KmBaremeTier: Codable, Equatable {
    let fiscalPowerLabel: String
    let tier1Coefficient: Double
    let tier2Coefficient: Double
    let tier2FixedAmount: Double
    let tier3Coefficient: Double
}

/// Barème kilométrique éditable (`Codable`, persisté par l'écran "Barèmes & frais" à venir —
/// hors scope de ce plan, voir design doc chantier 8). `tiers` est ordonné du CV le plus
/// faible au plus élevé ; `deduction` traite toute puissance fiscale ≤ à la première ligne
/// comme "3 CV et moins" et toute puissance ≥ à la dernière ligne comme "7 CV et plus"
/// (plafonnement DGFiP).
struct KmBareme: Codable {
    let tiers: [KmBaremeTier]
    let verifiedDate: String
    let source: String

    /// Barème 2026 officiel, sourcé Service-Public.fr (publication du 9 avril 2026, reconduit
    /// à l'identique de 2025) — voir design doc V5, chantier 5.
    static let default2026 = KmBareme(
        tiers: [
            KmBaremeTier(fiscalPowerLabel: "3 et moins", tier1Coefficient: 0.529, tier2Coefficient: 0.316, tier2FixedAmount: 1065, tier3Coefficient: 0.370),
            KmBaremeTier(fiscalPowerLabel: "4", tier1Coefficient: 0.606, tier2Coefficient: 0.340, tier2FixedAmount: 1330, tier3Coefficient: 0.407),
            KmBaremeTier(fiscalPowerLabel: "5", tier1Coefficient: 0.636, tier2Coefficient: 0.357, tier2FixedAmount: 1395, tier3Coefficient: 0.427),
            KmBaremeTier(fiscalPowerLabel: "6", tier1Coefficient: 0.665, tier2Coefficient: 0.374, tier2FixedAmount: 1457, tier3Coefficient: 0.447),
            KmBaremeTier(fiscalPowerLabel: "7 et plus", tier1Coefficient: 0.697, tier2Coefficient: 0.394, tier2FixedAmount: 1515, tier3Coefficient: 0.470)
        ],
        verifiedDate: "2026-04-09",
        source: "Service-Public.fr"
    )

    private func tier(forFiscalPower fiscalPower: Int) -> KmBaremeTier {
        // Index 0 = "3 et moins", index 1 = 4 CV, ..., index 4 = "7 et plus".
        // fiscalPower 3 ou moins -> index 0 ; fiscalPower 7 ou plus -> index 4.
        let index = min(max(fiscalPower - 3, 0), tiers.count - 1)
        return tiers[index]
    }

    func deduction(distanceKm: Double, fiscalPower: Int, isElectric: Bool) -> Double {
        let t = tier(forFiscalPower: fiscalPower)
        let base: Double
        // Bornes officielles : "≤ 5 000 km" (tranche 1), "5 001 à 20 000 km" (tranche 2),
        // "> 20 000 km" (tranche 3) — 5000 km pile appartient à la tranche 1, pas la 2.
        switch distanceKm {
        case ..<0:
            base = 0
        case 0...5000:
            base = distanceKm * t.tier1Coefficient
        case 5000.0001...20000:
            base = (distanceKm * t.tier2Coefficient) + t.tier2FixedAmount
        default:
            base = distanceKm * t.tier3Coefficient
        }
        return isElectric ? base * 1.2 : base
    }
}
