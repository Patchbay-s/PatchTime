import SwiftUI
import CoreData

/// Sélecteur du Bilan annuel, similaire à "Base de calcul" du Bilan fiscal — voir
/// `AnnualReportValidationMode` pour la distinction exacte entre les deux modes.
enum AnnualValidationDisplayMode: String, CaseIterable, Identifiable {
    case validatedAndArchived
    case complete

    var id: String { rawValue }

    var label: String {
        switch self {
        case .validatedAndArchived: return "Validées et traitées"
        case .complete: return "Complet"
        }
    }

    var calculatorMode: AnnualReportValidationMode {
        switch self {
        case .validatedAndArchived: return .validatedAndArchived
        case .complete: return .complete
        }
    }
}

struct AnnualSummaryView: View {
    @AppStorage("currency") private var currency: String = "€"

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \OvertimeEntry.date, ascending: true)]
    ) private var allEntries: FetchedResults<OvertimeEntry>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \OvertimeProfile.name, ascending: true)]
    ) private var profiles: FetchedResults<OvertimeProfile>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \PublicHoliday.date, ascending: true)]
    ) private var holidays: FetchedResults<PublicHoliday>

    @AppStorage("annualSummaryValidationMode") private var validationModeRaw: String = AnnualValidationDisplayMode.complete.rawValue

    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var showShareSheet = false
    @State private var exportURL: URL? = nil
    @State private var isGenerating = false
    @State private var showExportError = false
    @State private var exportError = ""

    private var currentYear: Int { Calendar.current.component(.year, from: Date()) }

    private var validationDisplayMode: AnnualValidationDisplayMode {
        AnnualValidationDisplayMode(rawValue: validationModeRaw) ?? .complete
    }

    private var summary: AnnualSummary {
        AnnualReportCalculator.summary(year: selectedYear, entries: Array(allEntries), profiles: Array(profiles), holidays: Array(holidays), validationMode: validationDisplayMode.calculatorMode)
    }

    private var previousSummary: AnnualSummary {
        AnnualReportCalculator.summary(year: selectedYear - 1, entries: Array(allEntries), profiles: Array(profiles), holidays: Array(holidays), validationMode: validationDisplayMode.calculatorMode)
    }

    var body: some View {
        Form {
            Section(header: Text("Année")) {
                HStack {
                    Button {
                        selectedYear -= 1
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3.bold())
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Année précédente")

                    Spacer()

                    Text(String(selectedYear))
                        .font(.headline)

                    Spacer()

                    Button {
                        selectedYear += 1
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.title3.bold())
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Année suivante")
                    .disabled(selectedYear >= currentYear)
                }
            }

            Section(
                header: Text("Mode d'affichage"),
                footer: Text(validationDisplayMode == .validatedAndArchived
                    ? "Uniquement les heures sup à la fois validées et déjà traitées/archivées."
                    : "Toutes les heures sup validées, traitées ou non — exclut toujours les heures à valider.")
            ) {
                Picker("Mode d'affichage", selection: $validationModeRaw) {
                    ForEach(AnnualValidationDisplayMode.allCases) { mode in
                        Text(mode.label).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(header: Text("Total \(String(selectedYear))")) {
                LabeledContent("Heures nettes") {
                    Text(formattedHours(summary.totalHours))
                        .foregroundColor(summary.totalHours >= 0 ? .green : .orange)
                        .fontWeight(.semibold)
                }
                LabeledContent("Revenus estimés") {
                    Text(formattedAmount(summary.totalEarnings))
                        .foregroundColor(summary.totalEarnings >= 0 ? .green : .red)
                        .fontWeight(.semibold)
                }
                LabeledContent("Jours travaillés") {
                    Text("\(summary.workedDaysCount)")
                        .foregroundColor(.secondary)
                }
                LabeledContent("Entrées") {
                    Text("\(summary.entryCount)")
                        .foregroundColor(.secondary)
                }
            }

            if previousSummary.entryCount > 0 {
                Section(header: Text("Comparaison avec \(String(selectedYear - 1))")) {
                    LabeledContent("Heures") {
                        Text(hoursComparisonText())
                            .foregroundColor(.secondary)
                    }
                    LabeledContent("Revenus") {
                        Text(earningsComparisonText())
                            .foregroundColor(.secondary)
                    }
                }
            }

            if !summary.employerBreakdown.isEmpty {
                Section(header: Text("Répartition par employeur")) {
                    ForEach(summary.employerBreakdown) { breakdown in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(breakdown.displayName)
                                .font(.subheadline.weight(.medium))
                            HStack {
                                Text(formattedHours(breakdown.hours))
                                    .font(.caption)
                                    .foregroundColor(breakdown.hours >= 0 ? .green : .orange)
                                Spacer()
                                Text(formattedAmount(breakdown.earnings))
                                    .font(.caption)
                                    .foregroundColor(breakdown.earnings >= 0 ? .green : .red)
                                Spacer()
                                Text("\(breakdown.entryCount) entrée\(breakdown.entryCount > 1 ? "s" : "")")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            if summary.entryCount == 0 {
                Section {
                    Text("Aucune entrée active pour \(String(selectedYear)).")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
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
                        Text(isGenerating ? "Génération en cours…" : "Exporter le bilan (PDF)")
                            .font(.headline)
                    }
                }
                .disabled(summary.entryCount == 0 || isGenerating)
            }
        }
        .navigationTitle("Bilan annuel")
        .activityShareSheet(isPresented: $showShareSheet, items: exportURL.map { [$0] } ?? [])
        .alert("Erreur d'export", isPresented: $showExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError)
        }
    }

    // MARK: - Formatting

    private func formattedHours(_ h: Double) -> String {
        let sign = h < 0 ? "-" : "+"
        let abs = Swift.abs(h)
        let hh = Int(abs); let mm = Int((abs - Double(hh)) * 60)
        return mm == 0 ? "\(sign)\(hh)h" : String(format: "\(sign)%dh%02d", hh, mm)
    }

    private func formattedAmount(_ value: Double) -> String {
        let fmt = SharedFormatters.frenchDecimalAmount
        let sign = value < 0 ? "-" : "+"
        return "\(sign)\(fmt.string(from: NSNumber(value: Swift.abs(value))) ?? "0,00") \(currency)"
    }

    private func hoursComparisonText() -> String {
        let delta = summary.totalHours - previousSummary.totalHours
        let sign = delta >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", delta))h"
    }

    private func earningsComparisonText() -> String {
        let delta = summary.totalEarnings - previousSummary.totalEarnings
        let sign = delta >= 0 ? "+" : ""
        let fmt = SharedFormatters.frenchDecimalAmount
        return "\(sign)\(fmt.string(from: NSNumber(value: delta)) ?? "0,00") \(currency)"
    }

    // MARK: - Export

    private func handleExport() {
        generateAndShare()
    }

    private func generateAndShare() {
        isGenerating = true
        let currentSummary = summary
        let comparisonSummary = previousSummary.entryCount > 0 ? previousSummary : nil
        let curr = currency
        let year = selectedYear

        Task { @MainActor in
            let data = AnnualPDFGenerator.generateAnnualReport(
                summary: currentSummary,
                previousSummary: comparisonSummary,
                currency: curr
            )
            let name = "bilan_annuel_\(year).pdf"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
            do {
                try data.write(to: url)
                exportURL = url
                showShareSheet = true
            } catch {
                exportError = "Impossible d'écrire le fichier PDF. Vérifiez l'espace disque disponible."
                showExportError = true
            }
            isGenerating = false
        }
    }
}

#Preview {
    NavigationStack {
        AnnualSummaryView()
            .environment(\.managedObjectContext, CoreDataManager.shared.container.viewContext)
    }
}
