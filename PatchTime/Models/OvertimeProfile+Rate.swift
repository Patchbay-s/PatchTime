import Foundation

extension OvertimeProfile {
    /// Un montant (brut ou net) est directement connu : condition nécessaire et suffisante
    /// pour qu'un calcul de montant soit possible quelque part dans l'app. Un pourcentage
    /// seul (sans brut ni net) ne donne aucune valeur absolue, donc ne compte pas.
    var hasUsableRate: Bool {
        tauxBrut != nil || tauxNet != nil
    }

    /// Core Data génère `NSNumber?` pour ces attributs (optionnels, `usesScalarValueType="NO"`) ;
    /// ces bridges exposent des `Double?` natifs à tout le reste du code, qui ne doit jamais
    /// toucher `tauxBrut`/`tauxNet`/`tauxPourcentage` directement au-delà de ce fichier.
    var tauxBrutValue: Double? {
        get { tauxBrut?.doubleValue }
        set { tauxBrut = newValue.map { NSNumber(value: $0) } }
    }
    var tauxNetValue: Double? {
        get { tauxNet?.doubleValue }
        set { tauxNet = newValue.map { NSNumber(value: $0) } }
    }
    var tauxPourcentageValue: Double? {
        get { tauxPourcentage?.doubleValue }
        set { tauxPourcentage = newValue.map { NSNumber(value: $0) } }
    }

    /// Fraction (0.25 = 25 %), jamais un taux légal unique par défaut — voir
    /// `OvertimeSurcharge.multiplier`. Même pattern de bridge que les taux ci-dessus.
    var weekendSurchargePercentValue: Double? {
        get { weekendSurchargePercent?.doubleValue }
        set { weekendSurchargePercent = newValue.map { NSNumber(value: $0) } }
    }
    var holidaySurchargePercentValue: Double? {
        get { holidaySurchargePercent?.doubleValue }
        set { holidaySurchargePercent = newValue.map { NSNumber(value: $0) } }
    }
}
