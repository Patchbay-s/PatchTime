import Testing
import Foundation
@testable import PatchTime

struct FiscalReportPDFGeneratorSmokeTests {
    @Test func genereUnPDFValideAvecUnBilanNonVide() async throws {
        let summary = FiscalSummary(
            year: 2026, workedDaysCount: 120, congesPayesCount: 25, recuperationCount: 5,
            totalHours: 240.0, totalEarnings: 4800.0, majoratedHoursCount: 12.0, majorationSurcharge: 60.0,
            kmTotalDistance: 1200.0, kmDeduction: 727.2, mealDeduction: 1878.0, totalFraisReels: 2605.2,
            abattementForfaitaire: 480.0, recommendedRegime: .fraisReels, incomeIsManual: true,
            daysSource: .actualEntries, typicalWeekTemplateDaysCount: 0, typicalWeekExtraDaysCount: 0
        )

        let data = FiscalReportPDFGenerator.generateReport(summary: summary, currency: "€")

        #expect(data.count > 0)
        let magicBytes = data.prefix(5)
        #expect(magicBytes == Data("%PDF-".utf8))
    }
}
