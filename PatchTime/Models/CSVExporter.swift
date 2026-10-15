import Foundation

enum CSVExporter {

    static func generateMonthlyCSV(
        month: Date,
        entries: [OvertimeEntry],
        meals: [MealEntry],
        profiles: [OvertimeProfile],
        employers: [Employer],
        holidays: [PublicHoliday],
        filterProfile: OvertimeProfile?,
        currency: String
    ) -> Data {
        let profileMap: [UUID: OvertimeProfile] = Dictionary(
            uniqueKeysWithValues: profiles.compactMap { p in p.id.map { ($0, p) } }
        )
        let employerMap: [UUID: Employer] = Dictionary(
            uniqueKeysWithValues: employers.compactMap { e in e.id.map { ($0, e) } }
        )

        let decimalFmt = NumberFormatter()
        decimalFmt.numberStyle = .decimal
        decimalFmt.maximumFractionDigits = 2
        decimalFmt.minimumFractionDigits = 2
        decimalFmt.locale = Locale(identifier: "fr_FR")

        var lines: [String] = []

        // En-tête avec devise
        let cal = Calendar.current
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: month)) ?? month
        let monthEnd = cal.date(byAdding: DateComponents(month: 1, second: -1), to: monthStart) ?? monthStart
        let periodeStr = "\(SharedFormatters.pdfDate.string(from: monthStart)) – \(SharedFormatters.pdfDate.string(from: monthEnd))"
        let profileDesc = filterProfile.map { $0.name ?? "Tous" } ?? "Tous les profils"
        lines.append(escapeField("Récapitulatif mensuel — Heures supplémentaires"))
        lines.append(escapeField("Période : \(periodeStr) | Profil : \(profileDesc) | Devise : \(currency)"))
        lines.append("")

        // Section heures supplémentaires
        let overtimeHeader = ["Date", "Type", "Heure début", "Heure fin", "Durée (h)", "Lieu/Motif", "Profil", "Taux brut", "Montant brut", "Taux net", "Montant net", "Statut", "Traité"]
        lines.append(overtimeHeader.joined(separator: ";"))

        let sortedEntries = entries.sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
        for entry in sortedEntries {
            let dateStr = entry.date.map { SharedFormatters.pdfDate.string(from: $0) } ?? ""
            let isRecup = entry.type == "recup"
            let typeStr = isRecup ? "Récupération" : "Heure sup"
            let debutStr = entry.startTime.map { SharedFormatters.pdfTime.string(from: $0) } ?? ""
            // Fin le lendemain (service qui passe minuit) : « 02:00 (+1 j) ».
            var finStr = entry.endTime.map { SharedFormatters.pdfTime.string(from: $0) } ?? ""
            if let s = entry.startTime, let e = entry.endTime {
                let offset = OvertimeTimeRange.dayOffset(start: s, end: e)
                if offset > 0 { finStr += " (+\(offset) j)" }
            }

            var dureeStr = ""
            if let s = entry.startTime, let e = entry.endTime {
                let hours = e.timeIntervalSince(s) / 3600
                dureeStr = decimalFmt.string(from: NSNumber(value: hours)) ?? ""
            }

            let lieu = [entry.location, entry.reason].compactMap { $0 }.first(where: { !$0.isEmpty }) ?? ""
            let profile = entry.profileID.flatMap { profileMap[$0] }
            let profileName = profile?.name ?? ""
            let row = ReportRowCalculator.makeRow(entry: entry, profileMap: profileMap, holidays: holidays)

            let tauxBrutStr = profile?.tauxBrutValue.map { decimalFmt.string(from: NSNumber(value: $0)) ?? "" } ?? ""
            let montantBrutStr = row.earningsBrut.map { decimalFmt.string(from: NSNumber(value: abs($0))) ?? "" } ?? ""
            let tauxNetStr = profile?.tauxNetValue.map { decimalFmt.string(from: NSNumber(value: $0)) ?? "" } ?? ""
            let montantNetStr = row.earningsNet.map { decimalFmt.string(from: NSNumber(value: abs($0))) ?? "" } ?? ""

            let isValidated = entry.value(forKey: "isValidated") as? Bool ?? false
            let statutStr = isValidated ? "Validé" : "Non validé"
            let traitéStr = entry.archived ? "Oui" : "Non"

            let fields = [dateStr, typeStr, debutStr, finStr, dureeStr, lieu, profileName, tauxBrutStr, montantBrutStr, tauxNetStr, montantNetStr, statutStr, traitéStr]
            lines.append(fields.map(escapeField).joined(separator: ";"))
        }

        // Ligne vide + section repas
        lines.append("")
        let mealHeader = ["Date", "Type repas", "Employeur", "Statut", "Traité"]
        lines.append(mealHeader.joined(separator: ";"))

        let sortedMeals = meals.sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
        for meal in sortedMeals {
            let dateStr = meal.date.map { SharedFormatters.pdfDate.string(from: $0) } ?? ""
            let typeRepas = meal.mealType ?? ""
            let employerName = meal.employerID.flatMap { employerMap[$0] }?.name ?? ""
            let isValidated = meal.value(forKey: "isValidated") as? Bool ?? false
            let statutStr = isValidated ? "Validé" : "Non validé"
            let traitéStr = meal.archived ? "Oui" : "Non"

            let fields = [dateStr, typeRepas, employerName, statutStr, traitéStr]
            lines.append(fields.map(escapeField).joined(separator: ";"))
        }

        let csv = lines.joined(separator: "\r\n")
        let bom = Data([0xEF, 0xBB, 0xBF])
        return bom + Data(csv.utf8)
    }

    static func generateFileName(month: Date) -> String {
        "heures_\(SharedFormatters.yearMonth.string(from: month)).csv"
    }

    private static func escapeField(_ field: String) -> String {
        var safeField = field
        let ignoredPrefixCharacters = CharacterSet.whitespacesAndNewlines.union(.controlCharacters)
        if let firstMeaningfulCharacter = safeField.unicodeScalars.first(where: {
            !ignoredPrefixCharacters.contains($0)
        }), "=+-@".unicodeScalars.contains(firstMeaningfulCharacter) {
            safeField.insert("'", at: safeField.startIndex)
        }

        guard safeField.contains(";") || safeField.contains("\"")
                || safeField.contains("\n") || safeField.contains("\r") else {
            return safeField
        }
        return "\"\(safeField.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
