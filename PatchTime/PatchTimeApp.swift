//
//  PatchTimeApp.swift
//  PatchTime
//
//  Created by Admin on 30/04/2025.
//

import SwiftUI
import CoreData

@main
struct PatchTimeApp: App {
    let persistenceController = CoreDataManager.shared
    @StateObject private var thresholdManager = ThresholdManager()
    @StateObject private var cloudSyncMonitor = CloudSyncMonitor()
    @StateObject private var holidayManager = HolidayManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(thresholdManager)
                .environmentObject(cloudSyncMonitor)
                .environmentObject(holidayManager)
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: NSManagedObjectContext.didSaveObjectsNotification,
                        object: persistenceController.container.viewContext
                    )
                ) { _ in
                    WidgetDataStore.updateSnapshot(context: persistenceController.container.viewContext)
                    Task { await checkOvertimeThresholds() }
                }
                .onAppear {
                    Self.applyMacMinimumWindowSize()
                    holidayManager.seedMonacoIfNeeded()
                    let zone = HolidayZone(rawValue: UserDefaults.standard.string(forKey: "holidayCountryZone") ?? "") ?? .metropole
                    let year = Calendar.current.component(.year, from: Date())
                    Task {
                        await holidayManager.syncIfNeeded(zone: zone, year: year)
                        await holidayManager.syncIfNeeded(zone: zone, year: year + 1)
                    }
                }
        }
    }

    /// Mac (« Designed for iPad ») : la fenêtre est redimensionnable librement ; en dessous
    /// de cette taille, formulaires et roues de saisie deviennent inutilisables.
    private static func applyMacMinimumWindowSize() {
        guard ProcessInfo.processInfo.isiOSAppOnMac else { return }
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            scene.sizeRestrictions?.minimumSize = CGSize(width: 600, height: 700)
        }
    }

    /// Calcule les heures nettes (semaine / mois / année en cours) et les repas du mois,
    /// puis délègue à ThresholdManager la vérification des seuils et l'envoi de notifications.
    @MainActor
    private func checkOvertimeThresholds() async {
        let context = persistenceController.container.viewContext
        let calendar = Calendar.current
        let now = Date()

        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start,
              let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now))
        else { return }

        let overtimeRequest: NSFetchRequest<OvertimeEntry> = OvertimeEntry.fetchRequest()
        overtimeRequest.predicate = NSPredicate(format: "archived == NO AND date >= %@", startOfYear as NSDate)
        guard let annualEntries = try? context.fetch(overtimeRequest) else { return }

        let mealRequest: NSFetchRequest<MealEntry> = MealEntry.fetchRequest()
        mealRequest.predicate = NSPredicate(
            format: "archived == NO AND date >= %@ AND date <= %@",
            startOfMonth as NSDate, now as NSDate
        )
        let monthMeals = (try? context.fetch(mealRequest))?.count ?? 0

        func netHours(_ entries: [OvertimeEntry]) -> Double {
            entries.reduce(0.0) { sum, entry in
                guard let start = entry.startTime, let end = entry.endTime else { return sum }
                let hours = end.timeIntervalSince(start) / 3600
                return entry.type == "recup" ? sum - hours : sum + hours
            }
        }

        let monthEntries = annualEntries.filter { ($0.date ?? .distantPast) >= startOfMonth }
        let weekEntries = annualEntries.filter { ($0.date ?? .distantPast) >= startOfWeek }

        await thresholdManager.checkThresholds(
            currentMonthHours: netHours(monthEntries),
            currentWeekHours: netHours(weekEntries),
            currentMonthMeals: monthMeals,
            currentAnnualHours: netHours(annualEntries)
        )
    }
}
