import Foundation

/// Barème frais de repas éditable (`Codable`, persisté par l'écran "Barèmes & frais" à venir —
/// hors scope de ce plan, voir design doc chantier 8). Valeurs 2026 sourcées BOFiP — voir
/// design doc V5, chantier 6.
struct MealBareme: Codable {
    /// Forfait repas à domicile (non utilisé directement par le calcul de déduction, conservé
    /// pour référence/affichage futur dans l'écran barèmes).
    let homeAllowance: Double
    /// Plafond de dépense/jour (référence réglementaire, non utilisé directement par le calcul).
    let expenseCap: Double
    /// Montant réellement déductible par jour travaillé — c'est cette valeur que
    /// `MealExpenseEstimator` multiplie par le nombre de jours travaillés.
    let maxDeduction: Double
    let verifiedDate: String
    let source: String

    static let default2026 = MealBareme(
        homeAllowance: 5.45,
        expenseCap: 21.10,
        maxDeduction: 15.65,
        verifiedDate: "2026",
        source: "BOFiP"
    )
}
