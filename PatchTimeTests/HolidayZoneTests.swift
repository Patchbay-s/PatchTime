import Testing
import Foundation
@testable import PatchTime

struct HolidayZoneTests {
    @Test func monacoNEstJamaisRecuperableParLAPI() async throws {
        #expect(HolidayZone.monaco.isFetchableFromAPI == false)
        #expect(HolidayZone.metropole.isFetchableFromAPI == true)
    }

    @Test func laListeDesZonesEstRestreinteAFranceEtMonaco() async throws {
        #expect(HolidayZone.allCases == [.metropole, .monaco])
    }

    @Test func bridgeParDefautSurMetropoleEtSourceCustom() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let holiday = PublicHoliday(context: context)
        holiday.id = UUID()
        holiday.countryZone = nil
        holiday.source = nil

        #expect(holiday.zone == .metropole)
        #expect(holiday.sourceValue == .custom)

        holiday.zone = .monaco
        holiday.sourceValue = .seed
        #expect(holiday.countryZone == "monaco")
        #expect(holiday.source == "seed")
    }
}
