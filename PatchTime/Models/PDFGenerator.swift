import UIKit
import CoreData

enum PDFGenerator {

    // MARK: - Public API

    static func generateMonthlyReport(
        month: Date,
        entries: [OvertimeEntry],
        meals: [MealEntry],
        profiles: [OvertimeProfile],
        holidays: [PublicHoliday],
        filterProfile: OvertimeProfile?,
        currency: String
    ) -> Data {
        let profileMap: [UUID: OvertimeProfile] = Dictionary(
            uniqueKeysWithValues: profiles.compactMap { p in p.id.map { ($0, p) } }
        )
        let activeEntries   = entries.filter { !$0.archived }
        let archivedEntries = entries.filter {  $0.archived }

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.lightPDFData { ctx in
            ctx.beginPage()
            var y = drawHeader(month: month, filterProfile: filterProfile, currency: currency)
            y = drawTableHeader(yOffset: y)

            let sorted = activeEntries.sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
            var rowIndex = 0
            var totalHours = 0.0
            var totalEarningsBrut = 0.0
            var totalEarningsNet = 0.0
            var validatedCount = 0

            for entry in sorted {
                if y > pageRect.height - margin - footerReserve {
                    ctx.beginPage()
                    y = margin
                    y = drawTableHeader(yOffset: y)
                }
                let result = drawRow(entry: entry, profileMap: profileMap, holidays: holidays,
                                     currency: currency, rowIndex: rowIndex, yOffset: y)
                y = result.nextY
                totalHours += result.hours
                totalEarningsBrut += result.earningsBrut ?? 0
                totalEarningsNet += result.earningsNet ?? 0
                rowIndex += 1
                if entry.value(forKey: "isValidated") as? Bool ?? false { validatedCount += 1 }
            }

            y = drawTotalRow(hours: totalHours, earningsBrut: totalEarningsBrut, earningsNet: totalEarningsNet, currency: currency, yOffset: y)

            // Section des entrées traitées (saisies en comptabilité)
            if !archivedEntries.isEmpty {
                if y > pageRect.height - margin - footerReserve - 60 {
                    ctx.beginPage(); y = margin
                }
                y = drawArchivedSectionHeader(yOffset: y + 12)
                y = drawTableHeader(yOffset: y)

                let sortedArch = archivedEntries.sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
                var archRowIndex = 0
                var archHours = 0.0
                var archEarningsBrut = 0.0
                var archEarningsNet = 0.0

                for entry in sortedArch {
                    if y > pageRect.height - margin - footerReserve {
                        ctx.beginPage(); y = margin
                        y = drawTableHeader(yOffset: y)
                    }
                    let result = drawRow(entry: entry, profileMap: profileMap, holidays: holidays,
                                         currency: currency, rowIndex: archRowIndex, yOffset: y)
                    y = result.nextY
                    archHours += result.hours
                    archEarningsBrut += result.earningsBrut ?? 0
                    archEarningsNet += result.earningsNet ?? 0
                    archRowIndex += 1
                    if entry.value(forKey: "isValidated") as? Bool ?? false { validatedCount += 1 }
                }
                y = drawTotalRow(hours: archHours, earningsBrut: archEarningsBrut, earningsNet: archEarningsNet, currency: currency, yOffset: y)
            }

            drawFooter(validated: validatedCount,
                       nonValidated: entries.count - validatedCount,
                       meals: meals.count,
                       yOffset: y + 14)
        }
    }

    // MARK: - Layout

    private static let pageRect    = CGRect(x: 0, y: 0, width: 595.28, height: 841.89)
    private static let margin: CGFloat        = 40
    private static let rowHeight: CGFloat     = 22
    private static let headerHeight: CGFloat  = 26
    private static let footerReserve: CGFloat = 72

    private static let colDate     = (x: CGFloat(40),  w: CGFloat(56))
    private static let colType     = (x: CGFloat(100), w: CGFloat(56))
    private static let colHoraires = (x: CGFloat(160), w: CGFloat(102))
    private static let colDuree    = (x: CGFloat(264), w: CGFloat(34))
    private static let colLieu     = (x: CGFloat(300), w: CGFloat(106))
    private static let colMontantBrut = (x: CGFloat(410), w: CGFloat(70))
    private static let colMontantNet  = (x: CGFloat(484), w: CGFloat(70))

    // MARK: - Colors

    private static let clrBlue     = UIColor(red: 0.15, green: 0.39, blue: 0.92, alpha: 1)
    private static let clrBlueBg   = UIColor(red: 0.92, green: 0.95, blue: 1.00, alpha: 1)
    private static let clrTableHd  = UIColor(red: 0.93, green: 0.94, blue: 0.96, alpha: 1)
    private static let clrAlt      = UIColor(red: 0.97, green: 0.97, blue: 0.98, alpha: 1)
    private static let clrGreen    = UIColor(red: 0.10, green: 0.53, blue: 0.25, alpha: 1)
    private static let clrRed      = UIColor(red: 0.78, green: 0.13, blue: 0.13, alpha: 1)
    private static let clrOrange   = UIColor(red: 0.85, green: 0.45, blue: 0.00, alpha: 1)
    private static let clrArchived = UIColor(red: 0.55, green: 0.55, blue: 0.57, alpha: 1)

    // MARK: - Text helpers

    private static func attr(
        _ size: CGFloat,
        weight: UIFont.Weight = .regular,
        color: UIColor = .black,
        align: NSTextAlignment = .left
    ) -> [NSAttributedString.Key: Any] {
        let ps = NSMutableParagraphStyle()
        ps.alignment = align
        ps.lineBreakMode = .byTruncatingTail
        return [.font: UIFont.systemFont(ofSize: size, weight: weight),
                .foregroundColor: color,
                .paragraphStyle: ps]
    }

    private static func draw(_ text: String, _ rect: CGRect, _ attributes: [NSAttributedString.Key: Any]) {
        text.draw(in: rect, withAttributes: attributes)
    }

    // MARK: - Header

    @discardableResult
    private static func drawHeader(month: Date, filterProfile: OvertimeProfile?, currency: String) -> CGFloat {
        clrBlue.setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: pageRect.width, height: 108))

        draw("Récapitulatif mensuel — Heures supplémentaires",
             CGRect(x: margin, y: 20, width: 440, height: 26),
             attr(15, weight: .bold, color: .white))

        draw(SharedFormatters.frenchMonthYear.string(from: month).capitalized,
             CGRect(x: margin, y: 48, width: 300, height: 20),
             attr(12, weight: .semibold, color: UIColor(white: 0.88, alpha: 1)))

        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: month)) ?? month
        let end   = cal.date(byAdding: DateComponents(month: 1, day: -1), to: start) ?? start
        let profileDesc = filterProfile.map { rateDescription(for: $0, currency: currency) } ?? "Tous les profils"
        draw("\(profileDesc)    Période : \(SharedFormatters.pdfDate.string(from: start)) – \(SharedFormatters.pdfDate.string(from: end))",
             CGRect(x: margin, y: 72, width: 500, height: 16),
             attr(8.5, color: UIColor(white: 0.80, alpha: 1)))

        return 116
    }

    // MARK: - Table header

    @discardableResult
    private static func drawTableHeader(yOffset: CGFloat) -> CGFloat {
        clrTableHd.setFill()
        UIRectFill(CGRect(x: 0, y: yOffset, width: pageRect.width, height: headerHeight))

        let line = UIBezierPath()
        line.move(to: CGPoint(x: 0, y: yOffset + headerHeight))
        line.addLine(to: CGPoint(x: pageRect.width, y: yOffset + headerHeight))
        line.lineWidth = 0.5; UIColor.lightGray.setStroke(); line.stroke()

        let y = yOffset + 7
        let a  = attr(8, weight: .semibold, color: .darkGray)
        let ar = attr(8, weight: .semibold, color: .darkGray, align: .right)
        draw("DATE",         CGRect(x: colDate.x,     y: y, width: colDate.w,     height: 14), a)
        draw("TYPE",         CGRect(x: colType.x,     y: y, width: colType.w,     height: 14), a)
        draw("HORAIRES",     CGRect(x: colHoraires.x, y: y, width: colHoraires.w, height: 14), a)
        draw("DURÉE",        CGRect(x: colDuree.x,    y: y, width: colDuree.w,    height: 14), a)
        draw("LIEU / MOTIF", CGRect(x: colLieu.x,     y: y, width: colLieu.w,     height: 14), a)
        draw("BRUT",         CGRect(x: colMontantBrut.x, y: y, width: colMontantBrut.w, height: 14), ar)
        draw("NET",          CGRect(x: colMontantNet.x,  y: y, width: colMontantNet.w,  height: 14), ar)
        return yOffset + headerHeight
    }

    // MARK: - Treated section header

    @discardableResult
    private static func drawArchivedSectionHeader(yOffset: CGFloat) -> CGFloat {
        draw("Entrées traitées / Saisies en comptabilité",
             CGRect(x: margin, y: yOffset, width: 300, height: 16),
             attr(9, weight: .semibold, color: clrArchived))
        let line = UIBezierPath()
        line.move(to: CGPoint(x: margin, y: yOffset + 18))
        line.addLine(to: CGPoint(x: pageRect.width - margin, y: yOffset + 18))
        line.lineWidth = 0.5; UIColor.lightGray.setStroke(); line.stroke()
        return yOffset + 26
    }

    // MARK: - Data row

    private struct RowResult { let nextY: CGFloat; let hours: Double; let earningsBrut: Double?; let earningsNet: Double? }

    private static func drawRow(
        entry: OvertimeEntry,
        profileMap: [UUID: OvertimeProfile],
        holidays: [PublicHoliday],
        currency: String,
        rowIndex: Int,
        yOffset: CGFloat
    ) -> RowResult {
        if rowIndex % 2 == 1 {
            clrAlt.setFill()
            UIRectFill(CGRect(x: 0, y: yOffset, width: pageRect.width, height: rowHeight))
        }

        let row = ReportRowCalculator.makeRow(entry: entry, profileMap: profileMap, holidays: holidays)

        (row.isValidated ? clrGreen : clrOrange).setFill()
        UIBezierPath(ovalIn: CGRect(x: margin - 14, y: yOffset + rowHeight/2 - 3, width: 6, height: 6)).fill()

        let y = yOffset + 5

        draw(entry.date.map { SharedFormatters.pdfDate.string(from: $0) } ?? "—",
             CGRect(x: colDate.x, y: y, width: colDate.w, height: 14),
             attr(8.5))

        draw(row.isRecup ? "Récupération" : "Heure Sup",
             CGRect(x: colType.x, y: y, width: colType.w, height: 14),
             attr(8, weight: .medium, color: row.isRecup ? clrOrange : clrGreen))

        var horairesStr = "—"; var dureeStr = "—"
        if let s = entry.startTime, let e = entry.endTime {
            horairesStr = OvertimeTimeRange.displayText(start: s, end: e)
            let unsignedHours = Swift.abs(row.hours)
            let h = Int(unsignedHours); let m = Int((unsignedHours - Double(h)) * 60)
            dureeStr = m == 0 ? "\(h)h" : String(format: "%dh%02d", h, m)
        }
        draw(horairesStr, CGRect(x: colHoraires.x, y: y, width: colHoraires.w, height: 14), attr(8.5))
        draw(dureeStr,    CGRect(x: colDuree.x,    y: y, width: colDuree.w,    height: 14), attr(8.5))

        let lieu = [entry.location, entry.reason].compactMap { $0 }.first(where: { !$0.isEmpty }) ?? "—"
        draw(lieu, CGRect(x: colLieu.x, y: y, width: colLieu.w, height: 14), attr(8.5, color: .darkGray))

        drawMontant(row.earningsBrut, at: colMontantBrut, y: y)
        drawMontant(row.earningsNet, at: colMontantNet, y: y)

        let sep = UIBezierPath()
        sep.move(to: CGPoint(x: margin, y: yOffset + rowHeight))
        sep.addLine(to: CGPoint(x: pageRect.width - margin, y: yOffset + rowHeight))
        sep.lineWidth = 0.3; UIColor(white: 0.87, alpha: 1).setStroke(); sep.stroke()

        return RowResult(nextY: yOffset + rowHeight, hours: row.hours, earningsBrut: row.earningsBrut, earningsNet: row.earningsNet)

        func drawMontant(_ value: Double?, at col: (x: CGFloat, w: CGFloat), y: CGFloat) {
            let montantStr: String
            if let value {
                let sign = value < 0 ? "" : "+"
                montantStr = "\(sign)\(amountStr(value, currency: currency))"
            } else {
                montantStr = "—"
            }
            let mColor: UIColor = (value ?? 0) < 0 ? clrRed : ((value ?? 0) > 0 ? clrGreen : .darkGray)
            draw(montantStr, CGRect(x: col.x, y: y, width: col.w, height: 14), attr(8.5, weight: .semibold, color: mColor, align: .right))
        }
    }

    // MARK: - Total row

    @discardableResult
    private static func drawTotalRow(hours: Double, earningsBrut: Double, earningsNet: Double, currency: String, yOffset: CGFloat) -> CGFloat {
        let y = yOffset + 5
        clrBlueBg.setFill()
        UIRectFill(CGRect(x: 0, y: y, width: pageRect.width, height: 28))

        draw("TOTAL", CGRect(x: colDate.x, y: y + 7, width: 100, height: 16),
             attr(9, weight: .bold, color: clrBlue))

        let ah = Swift.abs(hours); let hh = Int(ah); let mh = Int((ah - Double(hh)) * 60)
        let hoursStr = mh == 0 ? "\(hh)h" : String(format: "%dh%02d", hh, mh)
        let signH = hours < 0 ? "-" : "+"
        draw("\(signH)\(hoursStr)",
             CGRect(x: colDuree.x, y: y + 7, width: colDuree.w, height: 16),
             attr(9, weight: .bold, color: hours >= 0 ? clrGreen : clrRed))

        let signBrut = earningsBrut < 0 ? "" : "+"
        draw("\(signBrut)\(amountStr(earningsBrut, currency: currency))",
             CGRect(x: colMontantBrut.x, y: y + 7, width: colMontantBrut.w, height: 16),
             attr(9, weight: .bold, color: earningsBrut >= 0 ? clrGreen : clrRed, align: .right))

        let signNet = earningsNet < 0 ? "" : "+"
        draw("\(signNet)\(amountStr(earningsNet, currency: currency))",
             CGRect(x: colMontantNet.x, y: y + 7, width: colMontantNet.w, height: 16),
             attr(9, weight: .bold, color: earningsNet >= 0 ? clrGreen : clrRed, align: .right))

        return y + 28
    }

    // MARK: - Footer

    private static func drawFooter(validated: Int, nonValidated: Int, meals: Int, yOffset: CGFloat) {
        var y = yOffset

        draw("✓ Validées : \(validated)     ⚠ Non validées : \(nonValidated)     Repas professionnels : \(meals)",
             CGRect(x: margin, y: y, width: 500, height: 16),
             attr(8.5, color: .darkGray))
        y += 20

        let line = UIBezierPath()
        line.move(to: CGPoint(x: margin, y: y))
        line.addLine(to: CGPoint(x: pageRect.width - margin, y: y))
        line.lineWidth = 0.5; UIColor.lightGray.setStroke(); line.stroke()
        y += 8

        draw("Généré le \(SharedFormatters.frenchDateTime.string(from: Date())) · PatchTime",
             CGRect(x: margin, y: y, width: 400, height: 14),
             attr(7.5, color: .lightGray))
    }

    // MARK: - Helpers

    private static func rateDescription(for profile: OvertimeProfile, currency: String) -> String {
        let name = profile.name ?? ""
        switch (profile.tauxBrutValue, profile.tauxNetValue) {
        case let (.some(b), .some(n)): return "\(name) · \(String(format: "%.2f", b))/\(String(format: "%.2f", n)) \(currency)/h (brut/net)"
        case let (.some(b), .none): return "\(name) · \(String(format: "%.2f", b)) \(currency)/h brut"
        case let (.none, .some(n)): return "\(name) · \(String(format: "%.2f", n)) \(currency)/h net"
        case (.none, .none): return name
        }
    }

    private static func amountStr(_ value: Double, currency: String) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.maximumFractionDigits = 2; fmt.minimumFractionDigits = 2
        fmt.locale = Locale(identifier: "fr_FR")
        return "\(fmt.string(from: NSNumber(value: Swift.abs(value))) ?? "0,00") \(currency)"
    }
}

extension UIGraphicsPDFRenderer {
    /// Rendu PDF toujours en apparence claire, quel que soit le mode de l'appareil : les
    /// couleurs dynamiques (label, systemBackground…) se résolvent en variante claire.
    func lightPDFData(actions: (UIGraphicsPDFRendererContext) -> Void) -> Data {
        var data = Data()
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            data = pdfData(actions: actions)
        }
        return data
    }
}
