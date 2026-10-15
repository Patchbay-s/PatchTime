//
//  SupportContent.swift
//  PatchTime
//
//  Source unique de la FAQ (Aide & Support) : thèmes, ordre et identifiants. Les textes
//  sont dans Localizable.strings (clés `faq.theme.<id>`, `faq.<id>.q`, `faq.<id>.a`).
//  Le script scripts/export_faq.py lit les lignes `FAQTheme(id:itemIDs:)` ci-dessous :
//  garder ce format sur une ligne.
//

import Foundation

struct FAQItem: Identifiable, Hashable {
    let id: String
    var question: String { SupportText.localized("faq.\(id).q") }
    var answer: String { SupportText.localized("faq.\(id).a") }

    /// Recherche insensible à la casse et aux accents, dans la question et la réponse.
    func matches(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return question.range(of: trimmed, options: options) != nil
            || answer.range(of: trimmed, options: options) != nil
    }
}

struct FAQTheme: Identifiable, Hashable {
    let id: String
    let items: [FAQItem]
    var title: String { SupportText.localized("faq.theme.\(id)") }

    init(id: String, itemIDs: [String]) {
        self.id = id
        self.items = itemIDs.map(FAQItem.init(id:))
    }
}

enum SupportContent {
    static let themes: [FAQTheme] = [
        FAQTheme(id: "saisie", itemIDs: ["saisie_heures", "saisie_minuit", "saisie_repas", "valider"]),
        FAQTheme(id: "taux", itemIDs: ["taux", "majorations"]),
        FAQTheme(id: "employeurs", itemIDs: ["employeurs", "semaine_type"]),
        FAQTheme(id: "conges", itemIDs: ["conges", "feries"]),
        FAQTheme(id: "calendrier", itemIDs: ["calendrier"]),
        FAQTheme(id: "bilans", itemIDs: ["statistiques", "bilans"]),
        FAQTheme(id: "exports", itemIDs: ["exports"]),
        FAQTheme(id: "donnees", itemIDs: ["icloud", "sauvegarde"]),
        FAQTheme(id: "notifications", itemIDs: ["notifications"]),
        FAQTheme(id: "widgets", itemIDs: ["widgets"]),
    ]

    static var allItems: [FAQItem] { themes.flatMap(\.items) }

    /// Thèmes filtrés par la recherche ; les thèmes sans résultat disparaissent.
    static func filteredThemes(matching query: String) -> [FAQTheme] {
        themes.compactMap { theme in
            let items = theme.items.filter { $0.matches(query) }
            guard !items.isEmpty else { return nil }
            return FAQTheme(id: theme.id, itemIDs: items.map(\.id))
        }
    }
}

enum SupportText {
    static func localized(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    }
}
