import Foundation

enum KmExpenseEstimator {
    static func estimate(
        year: Int,
        contracts: [Contract],
        overtimeEntries: [OvertimeEntry],
        bareme: KmBareme = .default2026,
        fiscalPower: Int,
        isElectric: Bool,
        calendar: Calendar = .current
    ) -> (totalKm: Double, deduction: Double) {
        var totalKm = 0.0
        for contract in contracts {
            guard let distance = contract.effectiveKmDistanceRoundTrip else { continue }
            let days = contract.workedDaysCount(in: year, overtimeEntries: overtimeEntries, calendar: calendar)
            totalKm += distance * Double(days)
        }

        let deduction = bareme.deduction(distanceKm: totalKm, fiscalPower: fiscalPower, isElectric: isElectric)
        return (totalKm, deduction)
    }
}
