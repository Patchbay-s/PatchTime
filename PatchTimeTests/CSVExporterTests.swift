import Testing
import Foundation
@testable import PatchTime

struct CSVExporterTests {

    // MARK: - Helpers

    private func allLines(_ data: Data) -> [String] {
        let str = String(data: data, encoding: .utf8) ?? ""
        let withoutBOM = str.hasPrefix("\u{FEFF}") ? String(str.dropFirst()) : str
        return withoutBOM.components(separatedBy: "\r\n")
    }

    private func nonEmptyLines(_ data: Data) -> [String] {
        allLines(data).filter { !$0.isEmpty }
    }

    private func makeMonth() -> Date {
        Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 1))!
    }

    private func makeTime(hour: Int, minute: Int, base: Date) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: base)!
    }

    // Retourne les champs de la Nième ligne de données d'overtime (0-indexé)
    private func overtimeRow(_ data: Data, index: Int) -> [String] {
        let lines = nonEmptyLines(data)
        guard let headerIdx = lines.firstIndex(where: { $0.hasPrefix("Date;Type;") }) else {
            return []
        }
        let rowIdx = headerIdx + 1 + index
        guard rowIdx < lines.count else { return [] }
        return lines[rowIdx].components(separatedBy: ";")
    }

    // MARK: - BOM + structure

    @Test func commenceParUnBOMUTF8() async throws {
        let data = CSVExporter.generateMonthlyCSV(
            month: makeMonth(), entries: [], meals: [], profiles: [], employers: [], holidays: [], filterProfile: nil, currency: "€"
        )
        #expect(data.prefix(3) == Data([0xEF, 0xBB, 0xBF]))
    }

    @Test func enTeteOvertimeExact() async throws {
        let data = CSVExporter.generateMonthlyCSV(
            month: makeMonth(), entries: [], meals: [], profiles: [], employers: [], holidays: [], filterProfile: nil, currency: "€"
        )
        let lines = nonEmptyLines(data)
        let header = lines.first(where: { $0.hasPrefix("Date;Type;") })
        #expect(header == "Date;Type;Heure début;Heure fin;Durée (h);Lieu/Motif;Profil;Taux brut;Montant brut;Taux net;Montant net;Statut;Traité")
    }

    @Test func enTeteRepasExact() async throws {
        let data = CSVExporter.generateMonthlyCSV(
            month: makeMonth(), entries: [], meals: [], profiles: [], employers: [], holidays: [], filterProfile: nil, currency: "€"
        )
        let lines = nonEmptyLines(data)
        let header = lines.first(where: { $0.hasPrefix("Date;Type repas;") })
        #expect(header == "Date;Type repas;Employeur;Statut;Traité")
    }

    // MARK: - Repas / Employeur

    // Retourne les champs de la Nième ligne de données de repas (0-indexé)
    private func mealRow(_ data: Data, index: Int) -> [String] {
        let lines = nonEmptyLines(data)
        guard let headerIdx = lines.firstIndex(where: { $0.hasPrefix("Date;Type repas;") }) else {
            return []
        }
        let rowIdx = headerIdx + 1 + index
        guard rowIdx < lines.count else { return [] }
        return lines[rowIdx].components(separatedBy: ";")
    }

    @Test func repasAvecEmployeurAfficheLeNomDeLEmployeur() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let employer = Employer(context: context)
        employer.id = UUID()
        employer.name = "Théâtre Municipal"
        let day = makeMonth()
        let meal = CoreDataTestHelpers.makeMealEntry(context: context, date: day, mealType: "Midi", profileID: nil)
        meal.employerID = employer.id

        let data = CSVExporter.generateMonthlyCSV(
            month: day, entries: [], meals: [meal], profiles: [], employers: [employer], holidays: [], filterProfile: nil, currency: "€"
        )
        let fields = mealRow(data, index: 0)
        #expect(fields.count == 5)
        #expect(fields[2] == "Théâtre Municipal")
    }

    @Test func repasSansEmployeurAfficheUneColonneVide() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let day = makeMonth()
        let meal = CoreDataTestHelpers.makeMealEntry(context: context, date: day, mealType: "Midi", profileID: nil)
        // meal.employerID reste nil

        let data = CSVExporter.generateMonthlyCSV(
            month: day, entries: [], meals: [meal], profiles: [], employers: [], holidays: [], filterProfile: nil, currency: "€"
        )
        let fields = mealRow(data, index: 0)
        #expect(fields.count == 5)
        #expect(fields[2] == "")
    }

    // MARK: - Heures supplémentaires

    @Test func heureSupDuréeEtMontantCorrects() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Studio Zenith", tauxBrut: 20.0, tauxNet: 15.6)
        let day = makeMonth()
        let start = makeTime(hour: 8, minute: 0, base: day)
        let end = makeTime(hour: 10, minute: 0, base: day)  // 2h

        let entry = CoreDataTestHelpers.makeOvertimeEntry(
            context: context, date: day, startTime: start, endTime: end,
            type: "sup", profileID: profile.id, isValidated: true
        )
        let data = CSVExporter.generateMonthlyCSV(
            month: day, entries: [entry], meals: [], profiles: [profile], employers: [], holidays: [], filterProfile: nil, currency: "€"
        )
        let fields = overtimeRow(data, index: 0)
        #expect(fields.count == 13)
        #expect(fields[1] == "Heure sup")      // Type
        #expect(fields[4] == "2,00")           // Durée (h) — virgule décimale FR
        #expect(fields[6] == "Studio Zenith")  // Profil
        #expect(fields[7] == "20,00")          // Taux brut
        #expect(fields[8] == "40,00")          // Montant brut = 2 × 20
        #expect(fields[9] == "15,60")          // Taux net
        #expect(fields[10] == "31,20")         // Montant net = 2 × 15,6
        #expect(fields[11] == "Validé")        // Statut
    }

    @Test func neutraliseLesFormulesDansLesChampsTexteDuCSV() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let day = makeMonth()
        let injections = ["=1+1", " \t+1", "\u{0000}@SUM(1,1)", "-1+1"]
        let entries = injections.map { value in
            let entry = CoreDataTestHelpers.makeOvertimeEntry(
                context: context,
                date: day,
                startTime: makeTime(hour: 8, minute: 0, base: day),
                endTime: makeTime(hour: 9, minute: 0, base: day),
                type: "sup",
                profileID: nil
            )
            entry.setValue(value, forKey: "location")
            return entry
        }

        let data = CSVExporter.generateMonthlyCSV(
            month: day, entries: entries, meals: [], profiles: [], employers: [], holidays: [], filterProfile: nil, currency: "€"
        )

        for index in injections.indices {
            #expect(overtimeRow(data, index: index)[5].hasPrefix("'"))
        }
    }

    @Test func recupDuréeNégativeEtMontantNegatifSigne() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Studio Zenith", tauxBrut: 20.0)
        let day = makeMonth()
        let start = makeTime(hour: 9, minute: 0, base: day)
        let end = makeTime(hour: 10, minute: 30, base: day)  // 1,5h

        let entry = CoreDataTestHelpers.makeOvertimeEntry(
            context: context, date: day, startTime: start, endTime: end,
            type: "recup", profileID: profile.id
        )
        let data = CSVExporter.generateMonthlyCSV(
            month: day, entries: [entry], meals: [], profiles: [profile], employers: [], holidays: [], filterProfile: nil, currency: "€"
        )
        let fields = overtimeRow(data, index: 0)
        #expect(fields[1] == "Récupération")
        #expect(fields[4] == "1,50")   // Durée brute (non signée dans la colonne Durée)
        #expect(fields[7] == "20,00")  // Taux brut
        #expect(fields[8] == "30,00")  // Montant brut = abs(1,5 × 20) — toujours positif dans la colonne
        #expect(fields[9] == "")       // Taux net inconnu pour ce profil → colonne vide
        #expect(fields[10] == "")      // Montant net inconnu pour ce profil → colonne vide
    }

    @Test func formatDateFRJJmmAAAA() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "P")
        let day = Calendar.current.date(from: DateComponents(year: 2025, month: 6, day: 3))!
        let entry = CoreDataTestHelpers.makeOvertimeEntry(
            context: context, date: day, startTime: day, endTime: day.addingTimeInterval(3600),
            type: "sup", profileID: profile.id
        )
        let data = CSVExporter.generateMonthlyCSV(
            month: day, entries: [entry], meals: [], profiles: [profile], employers: [], holidays: [], filterProfile: nil, currency: "€"
        )
        let fields = overtimeRow(data, index: 0)
        #expect(fields[0] == "03/06/2025")  // format dd/MM/yyyy
    }

    @Test func séparateurEstPointVirgule() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "P", tauxBrut: 10)
        let day = makeMonth()
        let entry = CoreDataTestHelpers.makeOvertimeEntry(
            context: context, date: day, startTime: day, endTime: day.addingTimeInterval(3600),
            type: "sup", profileID: profile.id
        )
        let data = CSVExporter.generateMonthlyCSV(
            month: day, entries: [entry], meals: [], profiles: [profile], employers: [], holidays: [], filterProfile: nil, currency: "€"
        )
        let nonEmptyRows = nonEmptyLines(data)
        let headerRow = nonEmptyRows.first(where: { $0.hasPrefix("Date;Type;") })!
        #expect(headerRow.components(separatedBy: ";").count == 13)
    }

    @Test func echappementPointVirguleEtGuillemets() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "Le \"Grand\"; Théâtre", tauxBrut: 10.0)
        let day = makeMonth()
        let entry = CoreDataTestHelpers.makeOvertimeEntry(
            context: context, date: day, startTime: day, endTime: day.addingTimeInterval(3600),
            type: "sup", profileID: profile.id
        )
        let data = CSVExporter.generateMonthlyCSV(
            month: day, entries: [entry], meals: [], profiles: [profile], employers: [], holidays: [], filterProfile: nil, currency: "€"
        )
        let lines = nonEmptyLines(data)
        // Find the data line (contains the date) — can't naively split because the escaped field contains ";"
        let dataLine = lines.first(where: { $0.hasPrefix(SharedFormatters.pdfDate.string(from: day)) }) ?? ""
        #expect(dataLine.contains("\"Le \"\"Grand\"\"; Théâtre\""))
    }

    @Test func triParDateCroissante() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "P")
        let month = makeMonth()
        let dayEarlier = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 5))!
        let dayLater   = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 20))!

        let entryLater = CoreDataTestHelpers.makeOvertimeEntry(
            context: context, date: dayLater, startTime: dayLater, endTime: dayLater.addingTimeInterval(3600),
            type: "sup", profileID: profile.id
        )
        let entryEarlier = CoreDataTestHelpers.makeOvertimeEntry(
            context: context, date: dayEarlier, startTime: dayEarlier, endTime: dayEarlier.addingTimeInterval(3600),
            type: "sup", profileID: profile.id
        )
        let data = CSVExporter.generateMonthlyCSV(
            month: month, entries: [entryLater, entryEarlier], meals: [],
            profiles: [profile], employers: [], holidays: [], filterProfile: nil, currency: "€"
        )
        #expect(overtimeRow(data, index: 0)[0] == SharedFormatters.pdfDate.string(from: dayEarlier))
        #expect(overtimeRow(data, index: 1)[0] == SharedFormatters.pdfDate.string(from: dayLater))
    }

    // MARK: - Cohérence CSV / PDF

    @Test func montantCSVEgalMontantPDFPourRecup() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "TestProfile", tauxBrut: 20.0)
        let day = makeMonth()
        let start = makeTime(hour: 14, minute: 0, base: day)
        let end   = makeTime(hour: 15, minute: 30, base: day)  // 1,5h × 20,0 = 30,0 — exact

        let entry = CoreDataTestHelpers.makeOvertimeEntry(
            context: context, date: day, startTime: start, endTime: end,
            type: "recup", profileID: profile.id
        )

        let csvData = CSVExporter.generateMonthlyCSV(
            month: day, entries: [entry], meals: [], profiles: [profile], employers: [], holidays: [], filterProfile: nil, currency: "€"
        )
        let csvFields = overtimeRow(csvData, index: 0)
        let frFmt = NumberFormatter()
        frFmt.locale = Locale(identifier: "fr_FR")
        frFmt.numberStyle = .decimal
        let csvAmount = frFmt.number(from: csvFields[8])?.doubleValue ?? -1

        let profileMap: [UUID: OvertimeProfile] = [profile.id!: profile]
        let row = ReportRowCalculator.makeRow(entry: entry, profileMap: profileMap, holidays: [])
        let pdfAmount = row.earningsBrut.map(abs) ?? -1

        #expect(csvAmount == pdfAmount)
    }

    @Test func montantCSVEgalMontantPDFPourSup() async throws {
        let context = CoreDataTestHelpers.makeInMemoryContext()
        let profile = CoreDataTestHelpers.makeProfile(context: context, name: "TestProfile", tauxBrut: 18.0)
        let day = makeMonth()
        let start = makeTime(hour: 8, minute: 0, base: day)
        let end   = makeTime(hour: 11, minute: 30, base: day)  // 3,5h

        let entry = CoreDataTestHelpers.makeOvertimeEntry(
            context: context, date: day, startTime: start, endTime: end,
            type: "sup", profileID: profile.id
        )

        let csvData = CSVExporter.generateMonthlyCSV(
            month: day, entries: [entry], meals: [], profiles: [profile], employers: [], holidays: [], filterProfile: nil, currency: "€"
        )
        let csvFields = overtimeRow(csvData, index: 0)
        let frFmt = NumberFormatter()
        frFmt.locale = Locale(identifier: "fr_FR")
        frFmt.numberStyle = .decimal
        let csvAmount = frFmt.number(from: csvFields[8])?.doubleValue ?? -1

        let profileMap: [UUID: OvertimeProfile] = [profile.id!: profile]
        let row = ReportRowCalculator.makeRow(entry: entry, profileMap: profileMap, holidays: [])
        let pdfAmount = row.earningsBrut.map(abs) ?? -1

        #expect(csvAmount == pdfAmount)
    }
}
