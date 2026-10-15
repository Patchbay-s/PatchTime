import Testing
import Foundation
@testable import PatchTime

struct OvertimeProfileRateFieldsTests {
    @Test func lesTroisChampsSontOptionnelsEtPersistants() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = OvertimeProfile(context: context)
        profile.id = UUID()
        profile.name = "Test"
        profile.tauxBrut = 12.5
        profile.tauxNet = 9.75
        profile.tauxPourcentage = 0.78

        try context.save()

        #expect(profile.tauxBrut == 12.5)
        #expect(profile.tauxNet == 9.75)
        #expect(profile.tauxPourcentage == 0.78)
    }

    @Test func lesTroisChampsSontNilParDefaut() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = OvertimeProfile(context: context)
        profile.id = UUID()
        profile.name = "Test"

        #expect(profile.tauxBrut == nil)
        #expect(profile.tauxNet == nil)
        #expect(profile.tauxPourcentage == nil)
    }
}
