import Foundation

/// Persistance des barèmes éditables (`KmBareme`/`MealBareme`), mêmes principes que
/// `RateHistoryStore` (`OvertimeProfilesView.swift`) : `Data` encodée en JSON dans
/// `UserDefaults.standard`, retombe sur la valeur par défaut 2026 si rien n'est sauvegardé.
enum BaremeStore {
    private static let kmBaremeKey = "bareme_km_v1"
    private static let mealBaremeKey = "bareme_meal_v1"

    static var kmBareme: KmBareme {
        get {
            guard let data = UserDefaults.standard.data(forKey: kmBaremeKey),
                  let decoded = try? JSONDecoder().decode(KmBareme.self, from: data) else {
                return .default2026
            }
            return decoded
        }
        set {
            guard let encoded = try? JSONEncoder().encode(newValue) else { return }
            UserDefaults.standard.set(encoded, forKey: kmBaremeKey)
        }
    }

    static var mealBareme: MealBareme {
        get {
            guard let data = UserDefaults.standard.data(forKey: mealBaremeKey),
                  let decoded = try? JSONDecoder().decode(MealBareme.self, from: data) else {
                return .default2026
            }
            return decoded
        }
        set {
            guard let encoded = try? JSONEncoder().encode(newValue) else { return }
            UserDefaults.standard.set(encoded, forKey: mealBaremeKey)
        }
    }

    /// Réinitialise les deux barèmes aux valeurs par défaut 2026 (bouton "Réinitialiser" de
    /// l'écran Barèmes & frais).
    static func resetToDefaults() {
        UserDefaults.standard.removeObject(forKey: kmBaremeKey)
        UserDefaults.standard.removeObject(forKey: mealBaremeKey)
    }
}
