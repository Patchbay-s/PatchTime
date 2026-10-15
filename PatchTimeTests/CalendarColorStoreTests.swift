import Testing
@testable import PatchTime

// .serialized : CalendarColorStore écrit dans UserDefaults.standard, partagé par tout le
// process ; en parallèle, un test peut lire les couleurs posées par un autre.
@Suite(.serialized)
struct CalendarColorStoreTests {
    @Test func retombeSurLaCouleurParDefautSiRienNestSauvegarde() async throws {
        CalendarColorStore.resetToDefaults()
        for category in CalendarDotCategory.allCases {
            #expect(CalendarColorStore.paletteColor(for: category) == category.defaultPaletteColor)
        }
    }

    @Test func sauvegardeEtRechargeUnChoixParCategorie() async throws {
        CalendarColorStore.resetToDefaults()
        CalendarColorStore.setPaletteColor(.indigo, for: .meal)

        #expect(CalendarColorStore.paletteColor(for: .meal) == .indigo)
        #expect(CalendarColorStore.paletteColor(for: .workedDay) == CalendarDotCategory.workedDay.defaultPaletteColor)

        CalendarColorStore.resetToDefaults()
    }

    @Test func resetToDefaultsEffaceTousLesChoixSauvegardes() async throws {
        for category in CalendarDotCategory.allCases {
            CalendarColorStore.setPaletteColor(.pink, for: category)
        }
        CalendarColorStore.resetToDefaults()

        for category in CalendarDotCategory.allCases {
            #expect(CalendarColorStore.paletteColor(for: category) == category.defaultPaletteColor)
        }
    }

    @Test func categoryColorRefleteLeChoixSauvegarde() async throws {
        CalendarColorStore.resetToDefaults()
        CalendarDotCategory.toValidate.setColor(.gray)

        #expect(CalendarDotCategory.toValidate.color == CalendarPaletteColor.gray.swiftUIColor)

        CalendarColorStore.resetToDefaults()
    }

    @Test func laPaletteAAuMoinsDixCouleursDistinctes() async throws {
        let colors = Set(CalendarPaletteColor.allCases.map { $0.swiftUIColor })
        #expect(CalendarPaletteColor.allCases.count >= 10)
        #expect(colors.count == CalendarPaletteColor.allCases.count)
    }
}
