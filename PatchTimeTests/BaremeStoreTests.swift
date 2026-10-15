import Testing
import Foundation
@testable import PatchTime

struct BaremeStoreTests {
    @Test func kmBaremeRetombeSurLeDefautSiRienNestSauvegarde() async throws {
        BaremeStore.resetToDefaults()
        #expect(BaremeStore.kmBareme.tiers == KmBareme.default2026.tiers)
    }

    @Test func kmBaremeSauvegardeEtRechargeUneModification() async throws {
        BaremeStore.resetToDefaults()
        let modified = KmBareme(tiers: KmBareme.default2026.tiers, verifiedDate: "2027-01-01", source: "Test")

        BaremeStore.kmBareme = modified

        #expect(BaremeStore.kmBareme.verifiedDate == "2027-01-01")
        #expect(BaremeStore.kmBareme.source == "Test")

        BaremeStore.resetToDefaults()
    }

    @Test func mealBaremeRetombeSurLeDefautSiRienNestSauvegarde() async throws {
        BaremeStore.resetToDefaults()
        #expect(BaremeStore.mealBareme.maxDeduction == MealBareme.default2026.maxDeduction)
    }

    @Test func mealBaremeSauvegardeEtRechargeUneModification() async throws {
        BaremeStore.resetToDefaults()
        BaremeStore.mealBareme = MealBareme(homeAllowance: 6.0, expenseCap: 22.0, maxDeduction: 16.0, verifiedDate: "2027", source: "Test")

        #expect(BaremeStore.mealBareme.maxDeduction == 16.0)

        BaremeStore.resetToDefaults()
    }

    @Test func resetToDefaultsEffaceLesModificationsSauvegardees() async throws {
        BaremeStore.mealBareme = MealBareme(homeAllowance: 6.0, expenseCap: 22.0, maxDeduction: 16.0, verifiedDate: "2027", source: "Test")
        BaremeStore.resetToDefaults()

        #expect(BaremeStore.mealBareme.maxDeduction == MealBareme.default2026.maxDeduction)
    }
}
