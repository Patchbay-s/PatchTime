import Foundation

extension Contract {
    /// Distance aller-retour à utiliser pour le calcul des frais kilométriques (décision D6
    /// du design doc V5) : celle du contrat si renseignée, sinon celle par défaut de
    /// l'employeur, sinon aucune (l'utilisateur n'a rien renseigné).
    var effectiveKmDistanceRoundTrip: Double? {
        kmDistanceRoundTripValue ?? employer?.kmDistanceRoundTripValue
    }
}
