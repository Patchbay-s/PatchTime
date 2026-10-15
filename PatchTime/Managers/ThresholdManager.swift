import Foundation
import UserNotifications
import SwiftUI

@MainActor
class ThresholdManager: ObservableObject {

    // MARK: - Seuils configurables (stockés dans UserDefaults)
    // Valeurs par défaut réalistes pour un intermittent du spectacle :
    // - 507 heures sur 12 mois = seuil d'ouverture de droits ARE (à titre indicatif, vérifier la réglementation)
    // - Ces valeurs sont des défauts modifiables, pas des valeurs légales figées.

    @AppStorage("threshold_monthlyHours") var monthlyHoursThreshold: Double = 35
    @AppStorage("threshold_weeklyHours") var weeklyHoursThreshold: Double = 48
    @AppStorage("threshold_monthlyMeals") var monthlyMealsThreshold: Int = 20
    @AppStorage("threshold_annualHours") var annualHoursThreshold: Double = 507
    @AppStorage("threshold_enabled") var thresholdsEnabled: Bool = true

    // MARK: - Vérification des seuils

    /// Vérifie si les seuils sont atteints ou approchés et envoie des notifications si besoin.
    /// Ne notifie qu'un changement d'état (aucun → approche → atteint) pour éviter de spammer
    /// l'utilisateur à chaque sauvegarde tant qu'un seuil reste dépassé.
    func checkThresholds(
        currentMonthHours: Double,
        currentWeekHours: Double,
        currentMonthMeals: Int,
        currentAnnualHours: Double
    ) async {
        guard thresholdsEnabled else { return }

        let authorized = await requestNotificationPermission()
        guard authorized else { return }

        let monthlyRatio = monthlyHoursThreshold > 0 ? currentMonthHours / monthlyHoursThreshold : 0
        await notifyOnStateChange(
            current: currentMonthHours, limit: monthlyHoursThreshold, stateKey: "threshold_monthly_lastState",
            reachedIdentifier: "threshold_monthly_reached", approachingIdentifier: "threshold_monthly_approaching",
            reachedTitle: "Seuil mensuel atteint",
            reachedBody: String(format: "Vous avez atteint votre seuil mensuel de %.0fh (%.1fh saisies).",
                                 monthlyHoursThreshold, currentMonthHours),
            approachingTitle: "Approche du seuil mensuel",
            approachingBody: String(format: "Vous êtes à %.0f %% de votre seuil mensuel de %.0fh (%.1fh saisies).",
                                     monthlyRatio * 100, monthlyHoursThreshold, currentMonthHours)
        )

        let weeklyRatio = weeklyHoursThreshold > 0 ? currentWeekHours / weeklyHoursThreshold : 0
        await notifyOnStateChange(
            current: currentWeekHours, limit: weeklyHoursThreshold, stateKey: "threshold_weekly_lastState",
            reachedIdentifier: "threshold_weekly_reached", approachingIdentifier: "threshold_weekly_approaching",
            reachedTitle: "Seuil hebdomadaire atteint",
            reachedBody: String(format: "Vous avez atteint votre seuil hebdomadaire de %.0fh (%.1fh saisies).",
                                 weeklyHoursThreshold, currentWeekHours),
            approachingTitle: "Approche du seuil hebdomadaire",
            approachingBody: String(format: "Vous êtes à %.0f %% de votre seuil hebdomadaire de %.0fh (%.1fh saisies).",
                                     weeklyRatio * 100, weeklyHoursThreshold, currentWeekHours)
        )

        let annualRatio = annualHoursThreshold > 0 ? currentAnnualHours / annualHoursThreshold : 0
        await notifyOnStateChange(
            current: currentAnnualHours, limit: annualHoursThreshold, stateKey: "threshold_annual_lastState",
            reachedIdentifier: "threshold_annual_reached", approachingIdentifier: "threshold_annual_approaching",
            reachedTitle: "Seuil annuel atteint — vérifiez votre situation",
            reachedBody: String(format: "Vous avez dépassé %.0fh annuelles (%.1fh saisies). Vérifiez votre situation France Travail.",
                                 annualHoursThreshold, currentAnnualHours),
            approachingTitle: "Approche du seuil annuel France Travail",
            approachingBody: String(format: "Vous êtes à %.0f %% du seuil indicatif de %.0fh (%.1fh saisies).",
                                     annualRatio * 100, annualHoursThreshold, currentAnnualHours)
        )
    }

    /// Envoie une notification uniquement si l'état de seuil (aucun/approche/atteint) a changé
    /// depuis le dernier appel, pour éviter les doublons à chaque sauvegarde CoreData.
    private func notifyOnStateChange(
        current: Double,
        limit: Double,
        stateKey: String,
        reachedIdentifier: String,
        approachingIdentifier: String,
        reachedTitle: String,
        reachedBody: String,
        approachingTitle: String,
        approachingBody: String
    ) async {
        let newState = Self.crossing(current: current, limit: limit)
        let lastState = UserDefaults.standard.string(forKey: stateKey).flatMap(ThresholdCrossing.init(rawValue:)) ?? .none
        guard newState != lastState else { return }
        UserDefaults.standard.set(newState.rawValue, forKey: stateKey)

        switch newState {
        case .reached:
            await scheduleNotification(title: reachedTitle, body: reachedBody, identifier: reachedIdentifier)
        case .approaching:
            await scheduleNotification(title: approachingTitle, body: approachingBody, identifier: approachingIdentifier)
        case .none:
            break
        }
    }

    // MARK: - Logique de seuil (testable)

    enum ThresholdCrossing: String { case none, approaching, reached }

    /// Calcul pur (aucun accès à self/UserDefaults) : non-isolé pour rester appelable et
    /// testable sans @MainActor, malgré l'isolation de la classe englobante.
    nonisolated static func crossing(current: Double, limit: Double) -> ThresholdCrossing {
        guard limit > 0 else { return .none }
        let ratio = current / limit
        if ratio >= 1.0 { return .reached }
        if ratio >= 0.8 { return .approaching }
        return .none
    }

    // MARK: - Permission de notification

    /// Demande la permission de notification si elle n'a pas encore été accordée.
    /// - Returns: `true` si l'autorisation est accordée, `false` sinon.
    func requestNotificationPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
                return granted
            } catch {
                print("ThresholdManager — erreur demande autorisation : \(error.localizedDescription)")
                return false
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Envoi de notification locale

    /// Envoie une notification locale immédiate avec l'identifiant donné.
    /// Supprime toute notification pendante portant le même identifiant avant d'en ajouter une nouvelle.
    private func scheduleNotification(title: String, body: String, identifier: String) async {
        let center = UNUserNotificationCenter.current()

        // Supprimer l'éventuelle notification pendante portant le même identifiant
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        // Déclenchement immédiat (1 seconde de délai minimum requis par iOS)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
        } catch {
            print("ThresholdManager — erreur planification notification (\(identifier)) : \(error.localizedDescription)")
        }
    }
}
