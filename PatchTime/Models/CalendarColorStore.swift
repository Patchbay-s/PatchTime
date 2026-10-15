import Foundation

/// Persistance du choix de couleur par catégorie de pastille calendrier (`CalendarDotCategory`),
/// même principe que `BaremeStore` : `UserDefaults.standard`, retombe sur la couleur par
/// défaut de la catégorie si rien n'est sauvegardé.
enum CalendarColorStore {
    private static func key(for category: CalendarDotCategory) -> String {
        "calendarDotColor_\(category.rawValue)"
    }

    static func paletteColor(for category: CalendarDotCategory) -> CalendarPaletteColor {
        guard let raw = UserDefaults.standard.string(forKey: key(for: category)),
              let palette = CalendarPaletteColor(rawValue: raw) else {
            return category.defaultPaletteColor
        }
        return palette
    }

    static func setPaletteColor(_ palette: CalendarPaletteColor, for category: CalendarDotCategory) {
        UserDefaults.standard.set(palette.rawValue, forKey: key(for: category))
    }

    /// Réinitialise toutes les catégories aux couleurs par défaut (bouton "Réinitialiser" de
    /// l'écran Couleurs du calendrier).
    static func resetToDefaults() {
        for category in CalendarDotCategory.allCases {
            UserDefaults.standard.removeObject(forKey: key(for: category))
        }
    }
}
