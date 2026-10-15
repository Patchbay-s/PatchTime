import SwiftUI

/// Les 5 catégories d'événements affichées comme pastilles sur le calendrier — indépendantes
/// et cumulables (un jour peut afficher plusieurs pastilles à la fois, ex: jour travaillé +
/// repas + à valider). Couleurs par défaut ici ; l'écran Réglages (Chantier 4) permet de les
/// personnaliser, en conservant ces mêmes cas comme clés.
enum CalendarDotCategory: String, CaseIterable {
    case holidayLeave
    case workedDay
    case meal
    case validatedOvertime
    case toValidate

    var label: String {
        switch self {
        case .holidayLeave: return "Jours fériés / CP / Récup"
        case .workedDay: return "Jours travaillés"
        case .meal: return "Repas"
        case .validatedOvertime: return "Heures sup validées"
        case .toValidate: return "Heures sup / repas à valider"
        }
    }

    var defaultPaletteColor: CalendarPaletteColor {
        switch self {
        case .holidayLeave: return .brown
        case .workedDay: return .blue
        case .meal: return .yellow
        case .validatedOvertime: return .green
        case .toValidate: return .red
        }
    }

    var defaultColor: Color { defaultPaletteColor.swiftUIColor }

    /// Couleur effectivement utilisée pour le rendu — personnalisable via l'écran Réglages
    /// "Couleurs du calendrier" (`CalendarColorStore`), retombe sur `defaultColor` sinon.
    var color: Color {
        CalendarColorStore.paletteColor(for: self).swiftUIColor
    }

    func setColor(_ palette: CalendarPaletteColor) {
        CalendarColorStore.setPaletteColor(palette, for: self)
    }

    /// Catégories actives un jour donné, dans un ordre stable (celui de `allCases`) pour que
    /// la disposition des pastilles en couronne autour du numéro du jour reste cohérente
    /// d'un jour à l'autre.
    static func activeCategories(
        holidayOrLeave: Bool,
        workedDay: Bool,
        meal: Bool,
        validatedOvertime: Bool,
        toValidate: Bool
    ) -> [CalendarDotCategory] {
        var result: [CalendarDotCategory] = []
        if holidayOrLeave { result.append(.holidayLeave) }
        if workedDay { result.append(.workedDay) }
        if meal { result.append(.meal) }
        if validatedOvertime { result.append(.validatedOvertime) }
        if toValidate { result.append(.toValidate) }
        return result
    }
}
