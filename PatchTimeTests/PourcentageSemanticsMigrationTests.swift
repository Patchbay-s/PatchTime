import Testing
import Foundation
@testable import PatchTime

struct PourcentageSemanticsMigrationTests {
    @Test func convertitAncienneValeurEnNouvelleSemantique() async throws {
        // Ancienne sémantique (ratio net/brut) 0.90 -> nouvelle sémantique (taux de
        // prélèvement) 0.10 : nouvelleValeur = 1 - ancienneValeur.
        let converted = PourcentageSemanticsMigration.convertedValue(from: 0.90)
        #expect(abs(converted - 0.10) < 0.0001)
    }

    @Test func profilAvecPourcentageEstSelectionnePourConversion() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = OvertimeProfile(context: context)
        profile.id = UUID()
        profile.name = "AvecPourcentage"
        profile.tauxPourcentageValue = 0.90

        let toConvert = PourcentageSemanticsMigration.profilesNeedingConversion([profile])

        #expect(toConvert.count == 1)
        #expect(toConvert.first?.id == profile.id)
    }

    @Test func profilSansPourcentageNestPasSelectionne() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = OvertimeProfile(context: context)
        profile.id = UUID()
        profile.name = "SansPourcentage"
        // tauxPourcentage reste nil

        let toConvert = PourcentageSemanticsMigration.profilesNeedingConversion([profile])

        #expect(toConvert.isEmpty)
    }
}
