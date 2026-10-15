import SwiftUI

enum DisplayPeriod: String, CaseIterable, Identifiable {
    case all = "Tous"
    case year = "Année en cours"
    case month = "Mois en cours"
    case last30Days = "30 derniers jours"
    case week = "Semaine en cours"
    case custom = "Personnalisé"
    
    var id: String { self.rawValue }
}

enum Currency: String, CaseIterable, Identifiable {
    case euro = "€"
    case dollar = "$"
    case pound = "£"
    
    var id: String { self.rawValue }
}

struct SettingsView: View {
    @AppStorage("displayPeriod") private var displayPeriod: String = DisplayPeriod.all.rawValue
    @AppStorage("customStartDate") private var customStartDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @AppStorage("customEndDate") private var customEndDate: Date = Date()
    @AppStorage("currency") private var currency: String = Currency.euro.rawValue
    @AppStorage("defaultProfileId") private var defaultProfileId: String = ""
    
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \OvertimeProfile.name, ascending: true)],
        animation: .default)
    private var profiles: FetchedResults<OvertimeProfile>
    
    var body: some View {
        Form {
            Section(header: Text("Réglages")) {
                NavigationLink(destination: EmployerListView()) {
                    Label("Employeurs / Contrats", systemImage: "building.2")
                }
                NavigationLink(destination: LeaveListView()) {
                    Label("Congés / Récup", systemImage: "calendar.badge.minus")
                }
                NavigationLink(destination: NotificationSettingsView()) {
                    Label("Notifications", systemImage: "bell")
                }
                NavigationLink(destination: MonthlyReportView()) {
                    Label("Export PDF mensuel", systemImage: "doc.richtext")
                }
                NavigationLink(destination: CSVExportView()) {
                    Label("Export CSV comptable", systemImage: "tablecells")
                }
                NavigationLink(destination: HolidaySettingsView()) {
                    Label("Pays / jours fériés", systemImage: "calendar.badge.exclamationmark")
                }
            }

            Section(header: Text("Fonctionnalités")) {
                CloudSyncStatusView()
                NavigationLink(destination: RatesSettingsView()) {
                    Label("Barèmes & frais", systemImage: "slider.horizontal.3")
                }
                NavigationLink(destination: ConsolidatedReportView()) {
                    Label("Vue consolidée multi-employeurs", systemImage: "chart.bar.doc.horizontal")
                }
                NavigationLink(destination: AnnualSummaryView()) {
                    Label("Bilan annuel", systemImage: "doc.text.magnifyingglass")
                }
                NavigationLink(destination: FiscalSummaryView()) {
                    Label("Bilan fiscal", systemImage: "percent")
                }
                NavigationLink(destination: ThresholdSettingsView()) {
                    Label("Alertes & Seuils", systemImage: "bell.badge")
                }
                NavigationLink(destination: BackupRestoreView()) {
                    Label("Sauvegarde / Restauration", systemImage: "clock.arrow.circlepath")
                }
                NavigationLink(destination: CalendarColorSettingsView()) {
                    Label("Couleurs du calendrier", systemImage: "paintpalette")
                }
            }

            Section(header: Text("Affichage")) {
                Picker("Période", selection: $displayPeriod) {
                    ForEach(DisplayPeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period.rawValue)
                    }
                }

                if displayPeriod == DisplayPeriod.custom.rawValue {
                    DatePicker("Date de début", selection: $customStartDate, displayedComponents: .date)
                    DatePicker("Date de fin", selection: $customEndDate, displayedComponents: .date)
                }

                Picker("Profil par défaut", selection: $defaultProfileId) {
                    Text("Tous les profils").tag("")
                    ForEach(profiles) { profile in
                        Text(profile.name ?? "").tag(profile.id?.uuidString ?? "")
                    }
                }

                Picker("Devise", selection: $currency) {
                    ForEach(Currency.allCases, id: \.self) { currency in
                        Text(currency.rawValue).tag(currency.rawValue)
                    }
                }
            }

            Section(header: Text("Assistance")) {
                NavigationLink(destination: HelpSupportView()) {
                    Label("Aide & Support", systemImage: "questionmark.circle")
                }
                NavigationLink(destination: AboutView()) {
                    Label("À propos", systemImage: "info.circle")
                }
            }

            Section(header: Text("Légal")) {
                NavigationLink(destination: PrivacyPolicyView()) {
                    Label("Politique de confidentialité", systemImage: "hand.raised.fill")
                }
            }
        }
        .navigationTitle("Réglages")
    }
}

#Preview {
    SettingsView()
        .environmentObject(CloudSyncMonitor())
}
 
