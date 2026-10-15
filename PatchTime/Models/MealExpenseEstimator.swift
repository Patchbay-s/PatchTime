import Foundation

enum MealExpenseEstimator {
    static func estimate(workedDaysCount: Int, bareme: MealBareme = .default2026) -> Double {
        Double(workedDaysCount) * bareme.maxDeduction
    }
}
