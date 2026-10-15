import AppIntents

struct PatchTimeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // Une phrase ne peut référencer qu'un seul paramètre, et uniquement de type
        // AppEntity/AppEnum (un Double comme `hours` ne peut pas être intégré à la phrase —
        // Siri le demandera après coup si besoin, via le dialogue de l'intent).
        AppShortcut(
            intent: AddHoursIntent(),
            phrases: [
                "Ajoute des heures dans \(.applicationName)",
                "Ajoute des heures chez \(\.$profile) dans \(.applicationName)",
                "Enregistre des heures supplémentaires dans \(.applicationName)"
            ],
            shortTitle: "Ajouter des heures",
            systemImageName: "clock.badge.plus"
        )
    }
}
