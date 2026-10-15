import Testing
import Foundation
@testable import PatchTime

struct MealBaremeTests {
    @Test func valeursSourceesDuBaremeDefaut2026() async throws {
        let bareme = MealBareme.default2026

        #expect(bareme.homeAllowance == 5.45)
        #expect(bareme.expenseCap == 21.10)
        #expect(bareme.maxDeduction == 15.65)
        #expect(!bareme.source.isEmpty)
        #expect(!bareme.verifiedDate.isEmpty)
    }
}
