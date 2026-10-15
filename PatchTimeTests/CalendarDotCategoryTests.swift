import Testing
@testable import PatchTime

struct CalendarDotCategoryTests {
    @Test func aucuneCategorieActivePourUnJourSansEvenement() async throws {
        let result = CalendarDotCategory.activeCategories(
            holidayOrLeave: false, workedDay: false, meal: false, validatedOvertime: false, toValidate: false
        )
        #expect(result.isEmpty)
    }

    @Test func toutesLesCategoriesActivesRestentDansLOrdreDAllCases() async throws {
        let result = CalendarDotCategory.activeCategories(
            holidayOrLeave: true, workedDay: true, meal: true, validatedOvertime: true, toValidate: true
        )
        #expect(result == CalendarDotCategory.allCases)
    }

    @Test func exempleDuChantierHeuresTravailleesRepasAValider() async throws {
        // Reprend l'exemple du prompt : "heures travaillées + repas + à valider" cumulés le même jour.
        let result = CalendarDotCategory.activeCategories(
            holidayOrLeave: false, workedDay: true, meal: true, validatedOvertime: false, toValidate: true
        )
        #expect(result == [.workedDay, .meal, .toValidate])
    }

    @Test func heureSupValideeNAffichePasToValider() async throws {
        let result = CalendarDotCategory.activeCategories(
            holidayOrLeave: false, workedDay: true, meal: false, validatedOvertime: true, toValidate: false
        )
        #expect(result == [.workedDay, .validatedOvertime])
    }

    @Test func chaqueCategorieADefinitUneCouleurDeDefautDistincte() async throws {
        let colors = Set(CalendarDotCategory.allCases.map { $0.defaultColor })
        #expect(colors.count == CalendarDotCategory.allCases.count)
    }
}
