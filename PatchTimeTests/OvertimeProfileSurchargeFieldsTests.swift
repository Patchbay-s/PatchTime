import Testing
import Foundation
@testable import PatchTime

struct OvertimeProfileSurchargeFieldsTests {
    @Test func lesDeuxChampsSontNilParDefautEtPersistants() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Studio Zenith", tauxBrut: 20.0)

        #expect(profile.weekendSurchargePercent == nil)
        #expect(profile.holidaySurchargePercent == nil)

        profile.weekendSurchargePercent = NSNumber(value: 0.25)
        profile.holidaySurchargePercent = NSNumber(value: 0.5)
        try context.save()

        #expect(profile.weekendSurchargePercent?.doubleValue == 0.25)
        #expect(profile.holidaySurchargePercent?.doubleValue == 0.5)
    }

    @Test func bridgesDoubleVersNSNumberDansLesDeuxSens() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Studio Zenith")

        #expect(profile.weekendSurchargePercentValue == nil)
        #expect(profile.holidaySurchargePercentValue == nil)

        profile.weekendSurchargePercentValue = 0.25
        profile.holidaySurchargePercentValue = 0.5

        #expect(profile.weekendSurchargePercent?.doubleValue == 0.25)
        #expect(profile.holidaySurchargePercent?.doubleValue == 0.5)

        profile.weekendSurchargePercentValue = nil
        #expect(profile.weekendSurchargePercent == nil)
    }
}
