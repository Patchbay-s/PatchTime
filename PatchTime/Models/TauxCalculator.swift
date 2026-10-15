import Foundation

enum TauxField: CaseIterable {
    case brut, net, pourcentage
}

/// Pilote la logique de saisie à 3 champs liés (taux brut / net / pourcentage) : au plus 2
/// champs sont jamais renseignés manuellement en même temps, le 3ème est toujours dérivé des
/// 2 derniers champs édités à la main (voir `docs/superpowers/specs/2026-07-15-taux-3-champs-repas-employeur-design.md`,
/// section "Logique de calcul à 3 champs").
struct TauxCalculator {
    var brut: Double?
    var net: Double?
    var pourcentage: Double?

    /// Champs édités manuellement par l'utilisateur, du plus récent au plus ancien. Un champ
    /// recalculé automatiquement n'y entre jamais — c'est ce qui le distingue d'un champ saisi.
    private(set) var manualEditHistory: [TauxField] = []

    func isManuallyEdited(_ field: TauxField) -> Bool {
        manualEditHistory.contains(field)
    }

    /// État vide (nouveau profil) : équivalent à l'ancien init memberwise implicite, mais
    /// désormais explicite puisque déclarer `init(loadingBrut:net:pourcentage:)` ci-dessous
    /// désactive la synthèse automatique de Swift.
    init() {}

    /// Initialise depuis des valeurs déjà persistées (Core Data), sans déclencher de recalcul :
    /// contrairement à `fieldEdited`, on suppose que les 3 valeurs sont déjà mutuellement
    /// cohérentes (ou légitimement à l'état "0/1 rempli"). On ne persiste pas quels champs
    /// avaient été saisis à la main à l'origine ; par convention déterministe, les 2 premiers
    /// champs non-nil (ordre brut, net, pourcentage) deviennent les "sources", et le 3ème
    /// (s'il existe) s'affiche en "Calculé automatiquement" jusqu'à ce que l'utilisateur le
    /// modifie lui-même — un choix arbitraire mais stable, qui ne recalcule ni ne perturbe rien.
    init(loadingBrut brut: Double?, net: Double?, pourcentage: Double?) {
        self.brut = brut
        self.net = net
        self.pourcentage = pourcentage
        let nonNilFields = TauxField.allCases.filter { field in
            switch field {
            case .brut: return brut != nil
            case .net: return net != nil
            case .pourcentage: return pourcentage != nil
            }
        }
        self.manualEditHistory = Array(nonNilFields.prefix(2))
    }

    /// À appeler à chaque frappe utilisateur dans un des 3 champs (jamais lors d'un recalcul auto).
    mutating func fieldEdited(_ field: TauxField, newValue: Double?) {
        set(field, newValue)
        manualEditHistory.removeAll { $0 == field }
        manualEditHistory.insert(field, at: 0)
        recomputeIfPossible()
    }

    private mutating func set(_ field: TauxField, _ value: Double?) {
        switch field {
        case .brut: brut = value
        case .net: net = value
        case .pourcentage: pourcentage = value
        }
    }

    private mutating func recomputeIfPossible() {
        let knownCount = [brut, net, pourcentage].compactMap { $0 }.count
        guard knownCount >= 2, manualEditHistory.count >= 2 else { return } // 0 ou 1 rempli : rien ne se passe
        let sources = Set(manualEditHistory.prefix(2))
        guard let target = TauxField.allCases.first(where: { !sources.contains($0) }) else { return }
        set(target, computed(target))
        // Le champ recalculé n'est plus "édité manuellement" même s'il l'a été par le passé —
        // sans cette éviction, isManuallyEdited(target) resterait vrai à tort après qu'une
        // valeur saisie à la main ait été écrasée par un recalcul automatique ultérieur.
        manualEditHistory.removeAll { $0 == target }
    }

    private func computed(_ target: TauxField) -> Double? {
        switch target {
        case .net:
            // pourcentage = taux de prélèvement (charges, cotisations...) : le net est ce qui
            // reste une fois le prélèvement appliqué au brut.
            guard let b = brut, let p = pourcentage else { return nil }
            return b * (1 - p)
        case .pourcentage:
            guard let n = net, let b = brut, b != 0 else { return nil }
            return 1 - (n / b)
        case .brut:
            guard let n = net, let p = pourcentage, p != 1 else { return nil }
            return n / (1 - p)
        }
    }
}
