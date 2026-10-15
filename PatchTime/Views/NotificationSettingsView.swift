import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @AppStorage("notificationEnabled") private var notificationEnabled: Bool = false
    @AppStorage("notificationHour") private var notificationHour: Double = 19.0
    @AppStorage("fiscalReminderEnabled") private var fiscalReminderEnabled: Bool = true
    @AppStorage("fiscalReminderMonth") private var fiscalReminderMonth: Int = 4
    @AppStorage("fiscalReminderDay") private var fiscalReminderDay: Int = 1

    var body: some View {
        Form {
            Section(header: Text("Notification quotidienne")) {
                Toggle("Activer la notification", isOn: $notificationEnabled)
                    .onChange(of: notificationEnabled) { oldValue, newValue in
                        if newValue {
                            requestNotificationAuthorization()
                            scheduleDailyNotification()
                        } else {
                            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyReminder"])
                        }
                    }
                
                if notificationEnabled {
                    HStack {
                        Text("Heure de rappel")
                        Spacer()
                        DatePicker("", selection: Binding(
                            get: {
                                let hour = Int(notificationHour)
                                let minute = Int((notificationHour - Double(hour)) * 60)
                                return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
                            },
                            set: { newDate in
                                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                                notificationHour = Double(comps.hour ?? 19) + Double(comps.minute ?? 0)/60.0
                                scheduleDailyNotification()
                            }
                        ), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                }
            }

            Section(header: Text("Rappel période de déclaration"), footer: Text("La période officielle de déclaration change chaque année — ajustez la date si besoin. Ce rappel pointe vers le Bilan fiscal.")) {
                Toggle("Activer le rappel annuel", isOn: $fiscalReminderEnabled)
                    .onChange(of: fiscalReminderEnabled) { _, newValue in
                        if newValue {
                            requestNotificationAuthorization()
                            scheduleFiscalReminder()
                        } else {
                            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["fiscalDeclarationReminder"])
                        }
                    }

                if fiscalReminderEnabled {
                    Stepper("Mois : \(monthName(fiscalReminderMonth))", value: $fiscalReminderMonth, in: 1...12)
                        .onChange(of: fiscalReminderMonth) { _, _ in scheduleFiscalReminder() }
                    Stepper("Jour : \(fiscalReminderDay)", value: $fiscalReminderDay, in: 1...28)
                        .onChange(of: fiscalReminderDay) { _, _ in scheduleFiscalReminder() }
                }
            }
        }
        .navigationTitle("Notifications")
        .onAppear {
            checkNotificationStatus()
            if fiscalReminderEnabled {
                scheduleFiscalReminder()
            }
        }
    }

    private func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            if success {
                print("Autorisation de notification accordée")
            } else if let error = error {
                print("Erreur d'autorisation de notification: \(error.localizedDescription)")
            }
        }
    }
    
    private func scheduleDailyNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyReminder"])
        
        let content = UNMutableNotificationContent()
        content.title = "PatchTime"
        content.body = "N'oubliez pas d'enregistrer vos heures supplémentaires et vos repas !"
        content.sound = .default
        
        let hour = Int(notificationHour)
        let minute = Int((notificationHour - Double(hour)) * 60)
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "dailyReminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Erreur de planification de la notification: \(error.localizedDescription)")
            }
        }
    }
    
    private func scheduleFiscalReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["fiscalDeclarationReminder"])

        let content = UNMutableNotificationContent()
        content.title = "Période de déclaration fiscale"
        content.body = "Pensez à consulter votre Bilan fiscal pour préparer votre déclaration de revenus."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.month = fiscalReminderMonth
        dateComponents.day = fiscalReminderDay
        dateComponents.hour = 9

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "fiscalDeclarationReminder", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Erreur de planification du rappel fiscal: \(error.localizedDescription)")
            }
        }
    }

    private func monthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.monthSymbols[max(0, min(11, month - 1))].capitalized
    }

    /// Se base sur la présence effective de la requête `"dailyReminder"`, pas seulement sur le
    /// statut d'autorisation système — depuis l'ajout du rappel fiscal (qui demande sa propre
    /// autorisation indépendamment), une autorisation accordée ne signifie plus que le rappel
    /// quotidien est actif : sans cette vérification, ce toggle se rallumerait tout seul à
    /// chaque ouverture de l'écran dès que l'utilisateur a autorisé les notifications via
    /// l'autre rappel, sans qu'aucune notification quotidienne ne soit réellement planifiée.
    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let isAuthorized = settings.authorizationStatus == .authorized
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                let hasDailyReminder = requests.contains { $0.identifier == "dailyReminder" }
                DispatchQueue.main.async {
                    notificationEnabled = isAuthorized && hasDailyReminder
                }
            }
        }
    }
}

#Preview {
    NotificationSettingsView()
} 