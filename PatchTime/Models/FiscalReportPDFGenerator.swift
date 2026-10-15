import UIKit

/// Gabarit distinct d'AnnualPDFGenerator (bilan annuel) : synthèse fiscale à part, avec le
/// bandeau de non-responsabilité et le comparatif frais réels vs abattement. Mêmes helpers
/// de dessin que AnnualPDFGenerator.swift (même style de rapport PDF dessiné à la main).
enum FiscalReportPDFGenerator {

    static func generateReport(summary: FiscalSummary, currency: String) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.lightPDFData { ctx in
            ctx.beginPage()
            var y = drawHeader(year: summary.year)
            y = drawDisclaimerBanner(yOffset: y)
            y = drawWorkedDaysSection(summary: summary, yOffset: y)
            y = drawMajorationSection(summary: summary, currency: currency, yOffset: y)
            y = drawFraisReelsSection(summary: summary, currency: currency, yOffset: y)
            y = drawComparisonSection(summary: summary, currency: currency, yOffset: y)
            drawFooter(yOffset: y)
        }
    }

    // MARK: - Layout constants

    private static let pageRect = CGRect(x: 0, y: 0, width: 595.28, height: 841.89) // A4
    private static let margin: CGFloat = 40

    private static let clrBlue    = UIColor(red: 0.15, green: 0.39, blue: 0.92, alpha: 1)
    private static let clrBlueBg  = UIColor(red: 0.92, green: 0.95, blue: 1.00, alpha: 1)
    private static let clrGreen   = UIColor(red: 0.10, green: 0.53, blue: 0.25, alpha: 1)
    private static let clrRed     = UIColor(red: 0.78, green: 0.13, blue: 0.13, alpha: 1)
    private static let clrGray    = UIColor(white: 0.55, alpha: 1)

    private static func attr(
        _ size: CGFloat, weight: UIFont.Weight = .regular, color: UIColor = .black, align: NSTextAlignment = .left
    ) -> [NSAttributedString.Key: Any] {
        let ps = NSMutableParagraphStyle()
        ps.alignment = align
        return [.font: UIFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .paragraphStyle: ps]
    }

    private static func draw(_ text: String, _ rect: CGRect, _ attributes: [NSAttributedString.Key: Any]) {
        text.draw(in: rect, withAttributes: attributes)
    }

    private static func amountStr(_ value: Double, currency: String) -> String {
        let fmt = SharedFormatters.frenchDecimalAmount
        return "\(fmt.string(from: NSNumber(value: Swift.abs(value))) ?? "0,00") \(currency)"
    }

    // MARK: - Sections

    @discardableResult
    private static func drawHeader(year: Int) -> CGFloat {
        clrBlue.setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: pageRect.width, height: 70))
        draw("Bilan fiscal \(year)", CGRect(x: margin, y: 24, width: pageRect.width - 2 * margin, height: 30),
             attr(20, weight: .bold, color: .white))
        return 90
    }

    @discardableResult
    private static func drawDisclaimerBanner(yOffset: CGFloat) -> CGFloat {
        let bannerRect = CGRect(x: margin, y: yOffset, width: pageRect.width - 2 * margin, height: 44)
        clrBlueBg.setFill()
        UIRectFill(bannerRect)
        let text = "Ceci est une estimation d'aide à la décision, pas un conseil fiscal. Les barèmes doivent être vérifiés chaque année. Vous restez responsable de votre déclaration."
        draw(text, bannerRect.insetBy(dx: 8, dy: 6), attr(8, color: .darkGray))
        return yOffset + 56
    }

    @discardableResult
    private static func drawWorkedDaysSection(summary: FiscalSummary, yOffset: CGFloat) -> CGFloat {
        var y = yOffset
        draw("Jours et heures", CGRect(x: margin, y: y, width: 200, height: 18), attr(13, weight: .bold, color: clrBlue))
        y += 22
        draw("Jours travaillés : \(summary.workedDaysCount)", CGRect(x: margin, y: y, width: 300, height: 16), attr(10))
        y += 18
        draw("Jours de congés payés : \(summary.congesPayesCount)", CGRect(x: margin, y: y, width: 300, height: 16), attr(10))
        y += 18
        draw("Jours de récupération : \(summary.recuperationCount)", CGRect(x: margin, y: y, width: 300, height: 16), attr(10))
        y += 18
        draw("Heures totales : \(String(format: "%.1f", summary.totalHours))h", CGRect(x: margin, y: y, width: 300, height: 16), attr(10))
        return y + 26
    }

    @discardableResult
    private static func drawMajorationSection(summary: FiscalSummary, currency: String, yOffset: CGFloat) -> CGFloat {
        var y = yOffset
        draw("Majoration weekend / jour férié", CGRect(x: margin, y: y, width: 300, height: 18), attr(13, weight: .bold, color: clrBlue))
        y += 22
        draw("Heures majorées : \(String(format: "%.1f", summary.majoratedHoursCount))h", CGRect(x: margin, y: y, width: 300, height: 16), attr(10))
        y += 18
        draw("Surcoût généré : \(amountStr(summary.majorationSurcharge, currency: currency))", CGRect(x: margin, y: y, width: 300, height: 16), attr(10, color: clrGreen))
        return y + 26
    }

    @discardableResult
    private static func drawFraisReelsSection(summary: FiscalSummary, currency: String, yOffset: CGFloat) -> CGFloat {
        var y = yOffset
        draw("Frais réels estimés", CGRect(x: margin, y: y, width: 300, height: 18), attr(13, weight: .bold, color: clrBlue))
        y += 22
        let sourceLabel = summary.daysSource == .typicalWeek ? "Semaine type" : "Heures saisies"
        draw("Base de calcul : \(sourceLabel)", CGRect(x: margin, y: y, width: 300, height: 16), attr(9, color: .darkGray))
        y += 16
        draw("Distance annuelle : \(String(format: "%.0f", summary.kmTotalDistance)) km", CGRect(x: margin, y: y, width: 300, height: 16), attr(10))
        y += 18
        draw("Frais kilométriques : \(amountStr(summary.kmDeduction, currency: currency))", CGRect(x: margin, y: y, width: 300, height: 16), attr(10))
        y += 18
        draw("Frais de repas : \(amountStr(summary.mealDeduction, currency: currency))", CGRect(x: margin, y: y, width: 300, height: 16), attr(10))
        y += 18
        draw("Total frais réels : \(amountStr(summary.totalFraisReels, currency: currency))", CGRect(x: margin, y: y, width: 300, height: 16), attr(10, weight: .bold))
        return y + 26
    }

    @discardableResult
    private static func drawComparisonSection(summary: FiscalSummary, currency: String, yOffset: CGFloat) -> CGFloat {
        var y = yOffset
        draw("Frais réels vs abattement forfaitaire 10 %", CGRect(x: margin, y: y, width: 320, height: 18), attr(13, weight: .bold, color: clrBlue))
        y += 22
        draw("Abattement forfaitaire (10 %) : \(amountStr(summary.abattementForfaitaire, currency: currency))", CGRect(x: margin, y: y, width: 320, height: 16), attr(10))
        y += 18
        if summary.incomeIsManual {
            let recommendationText = summary.recommendedRegime == .fraisReels
                ? "Régime conseillé : frais réels (plus avantageux)"
                : "Régime conseillé : abattement forfaitaire 10 % (plus avantageux)"
            draw(recommendationText, CGRect(x: margin, y: y, width: 320, height: 16), attr(10, weight: .bold, color: clrGreen))
        } else {
            draw("Revenu net imposable non saisi : comparaison indicative uniquement (abattement basé sur les gains d'heures sup suivis par l'app).",
                 CGRect(x: margin, y: y, width: pageRect.width - 2 * margin, height: 28), attr(8, color: .darkGray))
            y += 12
        }
        return y + 26
    }

    private static func drawFooter(yOffset: CGFloat) {
        draw("Document généré le \(SharedFormatters.frenchDateTime.string(from: Date())) — estimation, pas une pièce officielle.",
             CGRect(x: margin, y: yOffset, width: pageRect.width - 2 * margin, height: 14), attr(7, color: .gray))
    }
}
