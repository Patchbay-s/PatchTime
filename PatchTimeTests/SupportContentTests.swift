import Foundation
import Testing
@testable import PatchTime

struct SupportContentTests {
    @Test func lesIdentifiantsDeLaFAQSontUniques() {
        let itemIDs = SupportContent.allItems.map(\.id)
        #expect(Set(itemIDs).count == itemIDs.count)
        let themeIDs = SupportContent.themes.map(\.id)
        #expect(Set(themeIDs).count == themeIDs.count)
    }

    @Test func chaqueQuestionEtReponseEstTraduiteEtNonVide() {
        for theme in SupportContent.themes {
            #expect(!theme.items.isEmpty, "thème vide : \(theme.id)")
            #expect(theme.title != "faq.theme.\(theme.id)", "titre manquant : \(theme.id)")
            for item in theme.items {
                #expect(!item.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                #expect(!item.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                #expect(item.question != "faq.\(item.id).q", "question manquante : \(item.id)")
                #expect(item.answer != "faq.\(item.id).a", "réponse manquante : \(item.id)")
            }
        }
    }

    @Test func laRechercheIgnoreCasseEtAccents() {
        let results = SupportContent.filteredThemes(matching: "ICLOUD")
        #expect(results.flatMap(\.items).contains { $0.id == "icloud" })
        let accents = SupportContent.filteredThemes(matching: "ferie")
        #expect(accents.flatMap(\.items).contains { $0.id == "feries" })
        #expect(SupportContent.filteredThemes(matching: "zzzz-introuvable").isEmpty)
        #expect(SupportContent.filteredThemes(matching: "  ").count == SupportContent.themes.count)
    }

}
