import SwiftUI
import CoreData

enum ExportFormat: String, CaseIterable, Identifiable {
    case pdf = "PDF"
    case csv = "CSV"
    var id: String { rawValue }
}

struct MonthlyReportView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("currency") private var currency: String = "€"

    // Pas de filtre archived : le PDF inclut actives + traitées
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \OvertimeEntry.date, ascending: true)]
    ) private var allEntries: FetchedResults<OvertimeEntry>

    // Pas de filtre archived : symétrique à allEntries ci-dessus, le PDF/CSV inclut les repas
    // actifs + traités (avant cette correction, seuls les repas actifs étaient exportables,
    // contrairement aux heures sup qui incluaient déjà les traitées).
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MealEntry.date, ascending: true)]
    ) private var allMeals: FetchedResults<MealEntry>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \OvertimeProfile.name, ascending: true)]
    ) private var profiles: FetchedResults<OvertimeProfile>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Employer.name, ascending: true)]
    ) private var employers: FetchedResults<Employer>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \PublicHoliday.date, ascending: true)]
    ) private var holidays: FetchedResults<PublicHoliday>

    @State private var selectedMonth: Date = {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
    }()
    @State private var selectedProfileID: String = ""
    @State private var showShareSheet = false
    @State private var exportURL: URL? = nil
    @State private var exportFormat: ExportFormat = .pdf
    @State private var isGenerating = false
    @State private var showExportError = false
    @State private var exportError: String = ""

    private var calendar: Calendar { Calendar.current }

    private var monthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth)) ?? selectedMonth
    }
    private var monthEnd: Date {
        calendar.date(byAdding: DateComponents(month: 1, second: -1), to: monthStart) ?? monthStart
    }

    private var selectedProfile: OvertimeProfile? {
        guard !selectedProfileID.isEmpty, let uuid = UUID(uuidString: selectedProfileID) else { return nil }
        return profiles.first { $0.id == uuid }
    }

    // Entrées actives uniquement (stats de l'aperçu)
    private var filteredEntries: [OvertimeEntry] {
        allEntries.filter { entry in
            guard let date = entry.date, date >= monthStart, date <= monthEnd, !entry.archived else { return false }
            if let profile = selectedProfile { return entry.profileID == profile.id }
            return true
        }
    }

    // Actives + traitées (transmis au PDFGenerator)
    private var allFilteredEntries: [OvertimeEntry] {
        allEntries.filter { entry in
            guard let date = entry.date, date >= monthStart, date <= monthEnd else { return false }
            if let profile = selectedProfile { return entry.profileID == profile.id }
            return true
        }
    }

    // Actives uniquement (aperçu, symétrique à filteredEntries)
    private var filteredActiveMeals: [MealEntry] {
        filteredMeals.filter { !$0.archived }
    }

    // Actives + traitées (transmis au PDFGenerator/CSVExporter, symétrique à allFilteredEntries)
    private var filteredMeals: [MealEntry] {
        allMeals.filter { meal in
            guard let date = meal.date, date >= monthStart, date <= monthEnd else { return false }
            if let profile = selectedProfile { return meal.profileID == profile.id }
            return true
        }
    }

    private var totalHours: Double {
        filteredEntries.reduce(0.0) { sum, entry in
            guard let s = entry.startTime, let e = entry.endTime else { return sum }
            let h = e.timeIntervalSince(s) / 3600
            return entry.type == "recup" ? sum - h : sum + h
        }
    }

    private var totalEarnings: Double {
        let profileMap: [UUID: OvertimeProfile] = Dictionary(uniqueKeysWithValues: profiles.compactMap { p in p.id.map { ($0, p) } })
        return filteredEntries.reduce(0.0) { sum, entry in
            guard let s = entry.startTime, let e = entry.endTime else { return sum }
            let h = e.timeIntervalSince(s) / 3600
            let profile = entry.profileID.flatMap { profileMap[$0] }
            let rate = ReportRowCalculator.bestEffortRate(for: profile)
            let isRecup = entry.type == "recup"
            let multiplier = isRecup ? 1.0 : OvertimeSurcharge.multiplier(for: entry, profile: profile, holidays: Array(holidays))
            return isRecup ? sum - h * rate : sum + h * rate * multiplier
        }
    }

    var body: some View {
        Form {
            Section(header: Text("Période")) {
                HStack {
                    Button {
                        if let prev = calendar.date(byAdding: .month, value: -1, to: selectedMonth) {
                            selectedMonth = prev
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3.bold())
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Mois précédent")

                    Spacer()

                    Text(monthName)
                        .font(.headline)
                        .animation(.none, value: monthName)

                    Spacer()

                    Button {
                        if let next = calendar.date(byAdding: .month, value: 1, to: selectedMonth) {
                            selectedMonth = next
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.title3.bold())
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Mois suivant")
                }
            }

            Section(header: Text("Profil")) {
                Picker("Profil", selection: $selectedProfileID) {
                    Text("Tous les profils").tag("")
                    ForEach(profiles) { profile in
                        Text(profile.name ?? "").tag(profile.id?.uuidString ?? "")
                    }
                }
            }

            Section(header: Text("Aperçu")) {
                LabeledContent("Entrées actives") {
                    Text("\(filteredEntries.count)")
                        .foregroundColor(.secondary)
                }
                LabeledContent("Repas") {
                    Text("\(filteredActiveMeals.count)")
                        .foregroundColor(.secondary)
                }
                LabeledContent("Total heures") {
                    Text(formattedHours(totalHours))
                        .foregroundColor(totalHours >= 0 ? .green : .orange)
                        .fontWeight(.medium)
                }
                LabeledContent("Total gains") {
                    Text(formattedAmount(totalEarnings))
                        .foregroundColor(totalEarnings >= 0 ? .green : .red)
                        .fontWeight(.medium)
                }
                if allFilteredEntries.count > filteredEntries.count {
                    LabeledContent("Traitées incluses dans le PDF") {
                        Text("\(allFilteredEntries.count - filteredEntries.count)")
                            .foregroundColor(.secondary)
                    }
                }
                if filteredMeals.count > filteredActiveMeals.count {
                    LabeledContent("Repas traités inclus dans le PDF") {
                        Text("\(filteredMeals.count - filteredActiveMeals.count)")
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section(header: Text("Format")) {
                Picker("Format", selection: $exportFormat) {
                    ForEach(ExportFormat.allCases) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                Button {
                    handleExport()
                } label: {
                    HStack {
                        if isGenerating {
                            ProgressView().padding(.trailing, 6)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.accentColor)
                        }
                        Text(isGenerating ? "Génération en cours…" : "Exporter en \(exportFormat.rawValue)")
                            .font(.headline)
                    }
                }
                .disabled(allFilteredEntries.isEmpty || isGenerating)

                if allFilteredEntries.isEmpty {
                    Text("Aucune entrée pour ce mois")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Export")
        .activityShareSheet(isPresented: $showShareSheet, items: exportURL.map { [$0] } ?? [])
        .alert("Erreur d'export", isPresented: $showExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError)
        }
    }

    private func handleExport() {
        generateAndShare()
    }

    private var monthName: String {
        SharedFormatters.frenchMonthYear.string(from: selectedMonth).capitalized
    }

    private func generateAndShare() {
        isGenerating = true
        let entries  = allFilteredEntries
        let meals    = filteredMeals
        let profs    = Array(profiles)
        let emps     = Array(employers)
        let hols     = Array(holidays)
        let month    = selectedMonth
        let profile  = selectedProfile
        let curr     = currency
        let format   = exportFormat

        Task { @MainActor in
            let data: Data
            switch format {
            case .pdf:
                data = PDFGenerator.generateMonthlyReport(
                    month: month,
                    entries: entries,
                    meals: meals,
                    profiles: profs,
                    holidays: hols,
                    filterProfile: profile,
                    currency: curr
                )
            case .csv:
                data = CSVExporter.generateMonthlyCSV(
                    month: month,
                    entries: entries,
                    meals: meals,
                    profiles: profs,
                    employers: emps,
                    holidays: hols,
                    filterProfile: profile,
                    currency: curr
                )
            }
            if let url = makeTempURL(from: data, month: month, format: format) {
                exportURL = url
                showShareSheet = true
            } else {
                exportError = "Impossible d'écrire le fichier \(format.rawValue). Vérifiez l'espace disque disponible."
                showExportError = true
            }
            isGenerating = false
        }
    }

    private func makeTempURL(from data: Data, month: Date, format: ExportFormat) -> URL? {
        let ext = format == .pdf ? "pdf" : "csv"
        let name = "heures_\(SharedFormatters.yearMonth.string(from: month)).\(ext)"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    private func formattedHours(_ h: Double) -> String {
        let sign = h < 0 ? "-" : "+"
        let abs  = Swift.abs(h)
        let hh   = Int(abs); let mm = Int((abs - Double(hh)) * 60)
        return mm == 0 ? "\(sign)\(hh)h" : String(format: "\(sign)%dh%02d", hh, mm)
    }

    private func formattedAmount(_ value: Double) -> String {
        let fmt = SharedFormatters.frenchDecimalAmount
        let sign = value < 0 ? "-" : "+"
        return "\(sign)\(fmt.string(from: NSNumber(value: Swift.abs(value))) ?? "0,00") \(currency)"
    }
}

#Preview {
    NavigationStack { MonthlyReportView() }
}
