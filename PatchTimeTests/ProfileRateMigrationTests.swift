import Testing
import Foundation
@testable import PatchTime

struct ProfileRateMigrationTests {
    @Test func profilAvecAncienTauxEtSansNouveauEstSelectionne() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = OvertimeProfile(context: context)
        profile.id = UUID()
        profile.name = "Ancien"
        profile.hourlyRate = 18.0
        // tauxBrut reste nil

        let toMigrate = ProfileRateMigration.profilesNeedingBackfill([profile])

        #expect(toMigrate.count == 1)
        #expect(toMigrate.first?.id == profile.id)
    }

    @Test func profilDejaMigreNestPasReselectionne() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = OvertimeProfile(context: context)
        profile.id = UUID()
        profile.name = "DejaMigre"
        profile.hourlyRate = 18.0
        profile.tauxBrut = 18.0

        let toMigrate = ProfileRateMigration.profilesNeedingBackfill([profile])

        #expect(toMigrate.isEmpty)
    }

    @Test func profilSansAncienTauxNestPasSelectionne() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = OvertimeProfile(context: context)
        profile.id = UUID()
        profile.name = "Neuf"
        // hourlyRate garde sa valeur par défaut 0.0 (attribut non-optionnel)

        let toMigrate = ProfileRateMigration.profilesNeedingBackfill([profile])

        #expect(toMigrate.isEmpty)
    }
}
