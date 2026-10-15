import SwiftUI
import UserNotifications

// Si MealCategory n'est pas défini ailleurs dans votre projet,
// assurez-vous qu'il existe. Exemple :
// enum MealCategory { case midi, soir }

struct ThresholdSettingsView: View {
    @EnvironmentObject private var thresholdManager: ThresholdManager

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var showPermissionAlert = false

    var body: some View {
        settingsContent
        .navigationTitle("Alertes & Seuils")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            checkNotificationStatus()
        }
        .alert("Permission de notification", isPresented: $showPermissionAlert) {
            Button("Ouvrir les Réglages") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Les notifications ont été refusées. Vous pouvez les autoriser dans les Réglages de l'appareil.")
        }
    }

    // MARK: - Contenu principal

    private var settingsContent: some View {
        Form {
            // Toggle principal
            Section {
                Toggle("Activer les alertes", isOn: $thresholdManager.thresholdsEnabled)
            } footer: {
                Text("Les alertes vous préviennent lorsque vous approchez ou dépassez vos seuils d'heures et de repas.")
            }

            if thresholdManager.thresholdsEnabled {

                // --- Seuils mensuels ---
                Section {
                    Stepper(
                        value: $thresholdManager.monthlyHoursThreshold,
                        in: 10...200,
                        step: 1
                    ) {
                        HStack {
                            Text("Heures / mois")
                            Spacer()
                            Text("\(Int(thresholdManager.monthlyHoursThreshold)) h")
                                .foregroundColor(.secondary)
                        }
                    }

                    Stepper(
                        value: Binding(
                            get: { Double(thresholdManager.monthlyMealsThreshold) },
                            set: { thresholdManager.monthlyMealsThreshold = Int($0) }
                        ),
                        in: 5...50,
                        step: 1
                    ) {
                        HStack {
                            Text("Repas / mois")
                            Spacer()
                            Text("\(thresholdManager.monthlyMealsThreshold) repas")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Seuils mensuels")
                }

                // --- Seuil hebdomadaire ---
                Section {
                    Stepper(
                        value: $thresholdManager.weeklyHoursThreshold,
                        in: 15...60,
                        step: 1
                    ) {
                        HStack {
                            Text("Heures / semaine")
                            Spacer()
                            Text("\(Int(thresholdManager.weeklyHoursThreshold)) h")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Seuil hebdomadaire")
                }

                // --- Seuil annuel ---
                Section {
                    Stepper(
                        value: $thresholdManager.annualHoursThreshold,
                        in: 100...600,
                        step: 10
                    ) {
                        HStack {
                            Text("Heures / an")
                            Spacer()
                            Text("\(Int(thresholdManager.annualHoursThreshold)) h")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Seuil annuel (indicatif)")
                } footer: {
                    Text("À titre indicatif uniquement. Vérifiez la réglementation France Travail en vigueur.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // --- Statut des permissions ---
                Section {
                    HStack {
                        Label {
                            Text("Notifications")
                        } icon: {
                            Image(systemName: notificationStatusIcon)
                                .foregroundColor(notificationStatusColor)
                        }
                        Spacer()
                        Text(notificationStatusLabel)
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }

                    if notificationStatus == .notDetermined {
                        Button {
                            Task {
                                let granted = await thresholdManager.requestNotificationPermission()
                                await MainActor.run {
                                    notificationStatus = granted ? .authorized : .denied
                                }
                            }
                        } label: {
                            Label("Demander la permission de notification", systemImage: "bell.badge")
                        }
                    } else if notificationStatus == .denied {
                        Button {
                            showPermissionAlert = true
                        } label: {
                            Label("Autoriser dans les Réglages", systemImage: "gear")
                        }
                    }
                } header: {
                    Text("Statut des permissions")
                }
            }
        }
        .onAppear {
            checkNotificationStatus()
        }
    }

    // MARK: - Helpers

    private var notificationStatusIcon: String {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: return "bell.fill"
        case .denied: return "bell.slash.fill"
        case .notDetermined: return "bell"
        @unknown default: return "bell"
        }
    }

    private var notificationStatusColor: Color {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: return .green
        case .denied: return .red
        case .notDetermined: return .orange
        @unknown default: return .secondary
        }
    }

    private var notificationStatusLabel: String {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: return "Autorisées"
        case .denied: return "Refusées"
        case .notDetermined: return "Non demandé"
        @unknown default: return "Inconnu"
        }
    }

    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationStatus = settings.authorizationStatus
            }
        }
    }
}

#Preview {
    NavigationStack {
        ThresholdSettingsView()
            .environmentObject(ThresholdManager())
    }
}
