import SwiftUI
import CoreData

struct FiscalSummaryView: View {
    @AppStorage("currency") private var currency: String = "€"
    @AppStorage("vehicleFiscalPower") private var vehicleFiscalPower: Int = 5
    @AppStorage("vehicleMotorisation") private var vehicleMotorisation: String = "thermique"

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \OvertimeEntry.date, ascending: true)])
    private var allEntries: FetchedResults<OvertimeEntry>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \OvertimeProfile.name, ascending: true)])
    private var profiles: FetchedResults<OvertimeProfile>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \PublicHoliday.date, ascending: true)])
    private var holidays: FetchedResults<PublicHoliday>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \LeaveEntry.date, ascending: true)])
    private var leaveEntries: FetchedResults<LeaveEntry>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Employer.name, ascending: true)])
    private var employers: FetchedResults<Employer>

    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedDaysSource: FiscalDaysSource = .actualEntries
    @State private var manualIncomeText: String = ""
    @State private var showShareSheet = false
    @State private var exportURL: URL? = nil
    @State private var isGenerating = false
    @State private var showExportError = false
    @State private var exportError = ""

    private var currentYear: Int { Calendar.current.component(.year, from: Date()) }
    private var isElectric: Bool { vehicleMotorisation == "electrique" }

    private var allContracts: [Contract] {
        employers.flatMap { CoreDataManager.shared.fetchContracts(for: $0) }
    }

    private var summary: FiscalSummary {
        FiscalReportCalculator.summary(
            year: selectedYear,
            // Filtré aux entrées actives : FiscalReportCalculator ne filtre plus par archived en
            // interne (voir sa documentation) — ce filtre reste explicite ici pour préserver la
            // portée historique du Bilan fiscal (aucun réglage d'inclusion des entrées traitées
            // sur cet écran, contrairement à Statistiques).
            overtimeEntries: allEntries.filter { !$0.archived },
            profiles: Array(profiles),
            leaveEntries: Array(leaveEntries),
            holidays: Array(holidays),
            contracts: allContracts,
            fiscalPower: vehicleFiscalPower,
            isElectric: isElectric,
            kmBareme: BaremeStore.kmBareme,
            mealBareme: BaremeStore.mealBareme,
            manualNetIncome: FiscalIncomeStore.value(forYear: selectedYear),
            daysSource: selectedDaysSource,
            // Toujours incluse ici (pas d'option pour la désactiver) : utile/nécessaire au
            // calcul frais km/repas qui est la raison d'être de cet écran — contrairement à
            // Statistiques, où elle reste un filtre optionnel désactivé par défaut.
            includeTypicalWeekDays: true
        )
    }

    var body: some View {
        let summary = self.summary

        Form {
            Section {
                Text("Ceci est une estimation d'aide à la décision, pas un conseil fiscal. Les barèmes doivent être vérifiés chaque année. Vous restez responsable de votre déclaration.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .listRowBackground(Color.orange.opacity(0.12))

            Section(header: Text("Année")) {
                HStack {
                    Button { selectedYear -= 1 } label: {
                        Image(systemName: "chevron.left").font(.title3.bold()).frame(width: 44, height: 44)
                    }
                    .buttonStyle(.borderless)
                    Spacer()
                    Text(String(selectedYear)).font(.headline)
                    Spacer()
                    Button { selectedYear += 1 } label: {
                        Image(systemName: "chevron.right").font(.title3.bold()).frame(width: 44, height: 44)
                    }
                    .buttonStyle(.borderless)
                    .disabled(selectedYear >= currentYear)
                }
            }

            Section(
                header: Text("Jours et heures"),
                footer: Text("La projection Semaine type est incluse systématiquement dans ce bilan (nécessaire au calcul frais km/repas ci-dessous).")
            ) {
                LabeledContent("Jours travaillés") { Text("\(summary.workedDaysCount)") }
                LabeledContent("Jours de congés payés") { Text("\(summary.congesPayesCount)") }
                LabeledContent("Jours de récupération") { Text("\(summary.recuperationCount)") }
                LabeledContent("Heures totales") { Text(String(format: "%.1fh", summary.totalHours)) }
                LabeledContent("Jours travaillés (dont Semaine type)") {
                    Text("\(summary.typicalWeekTemplateDaysCount + summary.typicalWeekExtraDaysCount)")
                }
                if summary.typicalWeekExtraDaysCount > 0 {
                    LabeledContent("dont jours sup au-delà du rythme habituel") {
                        Text("\(summary.typicalWeekExtraDaysCount)").foregroundColor(.orange)
                    }
                }
            }

            Section(header: Text("Majoration weekend / jour férié")) {
                LabeledContent("Heures majorées") { Text(String(format: "%.1fh", summary.majoratedHoursCount)) }
                LabeledContent("Surcoût généré") { Text(formattedAmount(summary.majorationSurcharge)).foregroundColor(.green) }
            }

            Section(header: Text("Véhicule")) {
                Stepper("Puissance fiscale : \(vehicleFiscalPower) CV", value: $vehicleFiscalPower, in: 1...20)
                Picker("Motorisation", selection: $vehicleMotorisation) {
                    Text("Thermique").tag("thermique")
                    Text("Électrique").tag("electrique")
                }
            }

            Section(
                header: Text("Base de calcul (frais km / repas)"),
                footer: Text(baseCalculFooter)
            ) {
                Picker("Base de calcul", selection: $selectedDaysSource) {
                    ForEach(FiscalDaysSource.allCases) { source in
                        Text(source.label).tag(source)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedDaysSource) { _, newValue in
                    FiscalDaysSourceStore.setValue(newValue, forYear: selectedYear)
                }
            }

            Section(header: Text("Frais réels estimés")) {
                LabeledContent("Distance annuelle") { Text("\(Int(summary.kmTotalDistance)) km") }
                LabeledContent("Frais kilométriques") { Text(formattedAmount(summary.kmDeduction)) }
                LabeledContent("Frais de repas") { Text(formattedAmount(summary.mealDeduction)) }
                LabeledContent("Total frais réels") { Text(formattedAmount(summary.totalFraisReels)).fontWeight(.semibold) }
            }

            Section(header: Text("Revenu net imposable (optionnel)"), footer: Text("Si vide, le total des montants nets suivis par l'app pour \(String(selectedYear)) est utilisé à la place.")) {
                TextField("ex: 24000", text: $manualIncomeText)
                    .keyboardType(.decimalPad)
                    .onChange(of: manualIncomeText) { _, newValue in
                        FiscalIncomeStore.setValue(Double(newValue.replacingOccurrences(of: ",", with: ".")), forYear: selectedYear)
                    }
            }

            Section(header: Text("Frais réels vs abattement forfaitaire 10 %")) {
                LabeledContent("Abattement forfaitaire (10 %)") { Text(formattedAmount(summary.abattementForfaitaire)) }
                LabeledContent("Total frais réels") { Text(formattedAmount(summary.totalFraisReels)) }
                if summary.incomeIsManual {
                    Text(summary.recommendedRegime == .fraisReels
                         ? "Régime conseillé : frais réels (plus avantageux)"
                         : "Régime conseillé : abattement forfaitaire 10 % (plus avantageux)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.green)
                } else {
                    Text("Saisissez votre revenu net imposable ci-dessus pour une comparaison fiable : l'abattement affiché est basé sur les gains d'heures sup suivis par l'app, une base généralement très inférieure à votre revenu réel.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Section {
                Button {
                    handleExport()
                } label: {
                    HStack {
                        if isGenerating { ProgressView().padding(.trailing, 6) }
                        else { Image(systemName: "square.and.arrow.up").foregroundColor(.accentColor) }
                        Text(isGenerating ? "Génération en cours…" : "Exporter le bilan fiscal (PDF)").font(.headline)
                    }
                }
                .disabled(isGenerating)
            }
        }
        .navigationTitle("Bilan fiscal")
        .activityShareSheet(isPresented: $showShareSheet, items: exportURL.map { [$0] } ?? [])
        .alert("Erreur d'export", isPresented: $showExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError)
        }
        .onAppear {
            manualIncomeText = FiscalIncomeStore.value(forYear: selectedYear).map { String($0) } ?? ""
            selectedDaysSource = FiscalDaysSourceStore.value(forYear: selectedYear)
        }
        .onChange(of: selectedYear) { _, newYear in
            manualIncomeText = FiscalIncomeStore.value(forYear: newYear).map { String($0) } ?? ""
            selectedDaysSource = FiscalDaysSourceStore.value(forYear: newYear)
        }
    }

    private var baseCalculFooter: String {
        switch selectedDaysSource {
        case .typicalWeek:
            return "Estimation à partir de la Semaine type de chaque employeur qui en a une active — n'affecte pas les heures/gains ci-dessus, toujours basés sur vos entrées réelles."
        case .combined:
            return "Combine les deux sources : un jour avec entrée réelle compte ses heures saisies, un jour sans entrée réelle mais prévu par la Semaine type est comblé par la projection — jamais les deux à la fois."
        case .actualEntries:
            return "Basé sur vos heures sup réellement saisies. Choisissez \"Semaine type\" ou \"Combiner les 2\" pour estimer à partir d'un patron hebdomadaire plutôt que de saisir une entrée chaque jour travaillé."
        }
    }

    private func formattedAmount(_ value: Double) -> String {
        let fmt = SharedFormatters.frenchDecimalAmount
        let sign = value < 0 ? "-" : ""
        return "\(sign)\(fmt.string(from: NSNumber(value: Swift.abs(value))) ?? "0,00") \(currency)"
    }

    private func handleExport() {
        isGenerating = true
        let currentSummary = summary
        let curr = currency
        let year = selectedYear

        Task { @MainActor in
            let data = FiscalReportPDFGenerator.generateReport(summary: currentSummary, currency: curr)
            let name = "bilan_fiscal_\(year).pdf"
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
        FiscalSummaryView()
            .environment(\.managedObjectContext, CoreDataManager.shared.container.viewContext)
    }
}
