import UIKit

/// Gabarit distinct de PDFGenerator (rapport mensuel détaillé) : une page synthétique pensée
/// pour être jointe à une déclaration (totaux, répartition par employeur, comparatif N-1),
/// sans le détail entrée par entrée.
enum AnnualPDFGenerator {

    static func generateAnnualReport(
        summary: AnnualSummary,
        previousSummary: AnnualSummary?,
        currency: String
    ) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.lightPDFData { ctx in
            ctx.beginPage()
            var y = drawHeader(year: summary.year)
            y = drawTotalsBlock(summary: summary, currency: currency, yOffset: y + 16)

            if let previousSummary, previousSummary.entryCount > 0 {
                y = drawComparisonBlock(current: summary, previous: previousSummary, currency: currency, yOffset: y + 12)
            }

            if !summary.employerBreakdown.isEmpty {
                y = drawEmployerTable(breakdown: summary.employerBreakdown, currency: currency, yOffset: y + 16, pageContext: ctx)
            }

            drawFooter(yOffset: pageRect.height - margin - 20)
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
    private static let clrTableHd = UIColor(red: 0.93, green: 0.94, blue: 0.96, alpha: 1)

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

    private static func hoursStr(_ hours: Double) -> String {
        let abs = Swift.abs(hours)
        let h = Int(abs); let m = Int((abs - Double(h)) * 60)
        return m == 0 ? "\(h)h" : String(format: "%dh%02d", h, m)
    }

    // MARK: - Sections

    @discardableResult
    private static func drawHeader(year: Int) -> CGFloat {
        clrBlue.setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: pageRect.width, height: 92))

        draw("Bilan annuel \(year)",
             CGRect(x: margin, y: 26, width: 400, height: 30),
             attr(20, weight: .bold, color: .white))

        draw("Récapitulatif pour votre déclaration",
             CGRect(x: margin, y: 58, width: 400, height: 18),
             attr(11, color: UIColor(white: 0.88, alpha: 1)))

        return 92
    }

    @discardableResult
    private static func drawTotalsBlock(summary: AnnualSummary, currency: String, yOffset: CGFloat) -> CGFloat {
        var y = yOffset
        clrBlueBg.setFill()
        UIRectFill(CGRect(x: margin, y: y, width: pageRect.width - margin * 2, height: 96))

        let colWidth = (pageRect.width - margin * 2) / 2
        let rows: [(String, String, UIColor)] = [
            ("Heures nettes", "\(summary.totalHours < 0 ? "-" : "+")\(hoursStr(summary.totalHours))",
             summary.totalHours >= 0 ? clrGreen : UIColor(red: 0.85, green: 0.45, blue: 0.0, alpha: 1)),
            ("Revenus estimés", "\(summary.totalEarnings < 0 ? "-" : "+")\(amountStr(summary.totalEarnings, currency: currency))",
             summary.totalEarnings >= 0 ? clrGreen : clrRed),
            ("Jours travaillés", "\(summary.workedDaysCount)", .black),
            ("Entrées", "\(summary.entryCount)", .black),
        ]

        y += 12
        for (index, row) in rows.enumerated() {
            let col = index % 2
            let line = index / 2
            let x = margin + CGFloat(col) * colWidth + 16
            let rowY = y + CGFloat(line) * 38
            draw(row.0, CGRect(x: x, y: rowY, width: colWidth - 32, height: 14), attr(9, color: clrGray))
            draw(row.1, CGRect(x: x, y: rowY + 15, width: colWidth - 32, height: 20), attr(16, weight: .bold, color: row.2))
        }

        return yOffset + 96
    }

    @discardableResult
    private static func drawComparisonBlock(current: AnnualSummary, previous: AnnualSummary, currency: String, yOffset: CGFloat) -> CGFloat {
        let hoursDelta = current.totalHours - previous.totalHours
        let earningsDelta = current.totalEarnings - previous.totalEarnings

        draw("Comparaison avec \(previous.year)",
             CGRect(x: margin, y: yOffset, width: 300, height: 16),
             attr(11, weight: .semibold, color: clrGray))

        let hoursSign = hoursDelta >= 0 ? "+" : "-"
        let earningsSign = earningsDelta >= 0 ? "+" : "-"
        let text = "Heures : \(hoursSign)\(hoursStr(hoursDelta))    Revenus : \(earningsSign)\(amountStr(earningsDelta, currency: currency))"
        draw(text, CGRect(x: margin, y: yOffset + 18, width: pageRect.width - margin * 2, height: 16),
             attr(10, color: .darkGray))

        return yOffset + 38
    }

    @discardableResult
    private static func drawEmployerTable(breakdown: [AnnualEmployerBreakdown], currency: String, yOffset: CGFloat, pageContext: UIGraphicsPDFRendererContext) -> CGFloat {
        var y = yOffset

        draw("Répartition par employeur",
             CGRect(x: margin, y: y, width: 300, height: 16),
             attr(11, weight: .semibold, color: clrGray))
        y += 20

        let colName = margin
        let colHours: CGFloat = margin + 260
        let colEarnings: CGFloat = margin + 350
        let colCount: CGFloat = pageRect.width - margin - 60

        clrTableHd.setFill()
        UIRectFill(CGRect(x: margin, y: y, width: pageRect.width - margin * 2, height: 22))
        draw("EMPLOYEUR", CGRect(x: colName + 6, y: y + 5, width: 200, height: 14), attr(8, weight: .semibold, color: .darkGray))
        draw("HEURES", CGRect(x: colHours, y: y + 5, width: 80, height: 14), attr(8, weight: .semibold, color: .darkGray))
        draw("GAINS", CGRect(x: colEarnings, y: y + 5, width: 90, height: 14), attr(8, weight: .semibold, color: .darkGray))
        draw("ENTR.", CGRect(x: colCount, y: y + 5, width: 60, height: 14), attr(8, weight: .semibold, color: .darkGray))
        y += 22

        for (index, row) in breakdown.enumerated() {
            if y > pageRect.height - margin - 60 {
                pageContext.beginPage()
                y = margin
            }
            if index % 2 == 1 {
                UIColor(white: 0.97, alpha: 1).setFill()
                UIRectFill(CGRect(x: margin, y: y, width: pageRect.width - margin * 2, height: 22))
            }
            draw(row.displayName, CGRect(x: colName + 6, y: y + 5, width: 250, height: 14), attr(9))
            let hoursSign = row.hours < 0 ? "-" : "+"
            draw("\(hoursSign)\(hoursStr(row.hours))", CGRect(x: colHours, y: y + 5, width: 80, height: 14),
                 attr(9, color: row.hours >= 0 ? clrGreen : UIColor(red: 0.85, green: 0.45, blue: 0.0, alpha: 1)))
            let earningsSign = row.earnings < 0 ? "-" : "+"
            draw("\(earningsSign)\(amountStr(row.earnings, currency: currency))", CGRect(x: colEarnings, y: y + 5, width: 90, height: 14),
                 attr(9, color: row.earnings >= 0 ? clrGreen : clrRed))
            draw("\(row.entryCount)", CGRect(x: colCount, y: y + 5, width: 60, height: 14), attr(9, color: .darkGray))
            y += 22
        }

        return y
    }

    private static func drawFooter(yOffset: CGFloat) {
        let line = UIBezierPath()
        line.move(to: CGPoint(x: margin, y: yOffset))
        line.addLine(to: CGPoint(x: pageRect.width - margin, y: yOffset))
        line.lineWidth = 0.5
        UIColor.lightGray.setStroke()
        line.stroke()

        draw("Généré le \(SharedFormatters.frenchDateTime.string(from: Date())) · PatchTime — document indicatif, à vérifier avant transmission",
             CGRect(x: margin, y: yOffset + 6, width: pageRect.width - margin * 2, height: 14),
             attr(7.5, color: .lightGray))
    }
}
