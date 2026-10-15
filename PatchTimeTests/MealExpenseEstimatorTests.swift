import Testing
import Foundation
@testable import PatchTime

struct MealExpenseEstimatorTests {
    @Test func multiplieLesJoursTravaillesParLaDeductionMax() async throws {
        let result = MealExpenseEstimator.estimate(workedDaysCount: 120)
        #expect(abs(result - (120.0 * 15.65)) < 0.001)
    }

    @Test func zeroJourTravailleDonneUneDeductionNulle() async throws {
        let result = MealExpenseEstimator.estimate(workedDaysCount: 0)
        #expect(result == 0.0)
    }

    @Test func accepteUnBaremePersonnalise() async throws {
        let customBareme = MealBareme(homeAllowance: 6.0, expenseCap: 22.0, maxDeduction: 16.0, verifiedDate: "2027", source: "Test")
        let result = MealExpenseEstimator.estimate(workedDaysCount: 10, bareme: customBareme)
        #expect(result == 160.0)
    }
}
