import Testing
import Foundation
import CoreData
@testable import PatchTime

struct OvertimeProfileHasUsableRateTests {
    private func makeProfile(context: NSManagedObjectContext, brut: Double?, net: Double?, pourcentage: Double?) -> OvertimeProfile {
        let profile = OvertimeProfile(context: context)
        profile.id = UUID()
        profile.name = "Test"
        profile.tauxBrut = brut.map { NSNumber(value: $0) }
        profile.tauxNet = net.map { NSNumber(value: $0) }
        profile.tauxPourcentage = pourcentage.map { NSNumber(value: $0) }
        return profile
    }

    @Test func aucunChampRempliNestPasUtilisable() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = makeProfile(context: context, brut: nil, net: nil, pourcentage: nil)
        #expect(profile.hasUsableRate == false)
    }

    @Test func brutSeulEstUtilisable() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = makeProfile(context: context, brut: 20.0, net: nil, pourcentage: nil)
        #expect(profile.hasUsableRate == true)
    }

    @Test func netSeulEstUtilisable() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = makeProfile(context: context, brut: nil, net: 15.6, pourcentage: nil)
        #expect(profile.hasUsableRate == true)
    }

    @Test func pourcentageSeulNestPasUtilisable() async throws {
        // Décision validée : un pourcentage seul ne donne aucune valeur absolue, donc aucun
        // montant n'est jamais calculable pour ce profil -> traité comme "aucun taux".
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = makeProfile(context: context, brut: nil, net: nil, pourcentage: 0.78)
        #expect(profile.hasUsableRate == false)
    }

    @Test func bridgesDoubleVersNSNumberDansLesDeuxSens() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = OvertimeProfile(context: context)
        profile.id = UUID()
        profile.name = "Test"

        profile.tauxBrutValue = 12.5
        #expect(profile.tauxBrut == 12.5) // le stockage NSNumber? sous-jacent reflète l'écriture
        #expect(profile.tauxBrutValue == 12.5)

        profile.tauxBrutValue = nil
        #expect(profile.tauxBrut == nil)
        #expect(profile.tauxBrutValue == nil)
    }
}
