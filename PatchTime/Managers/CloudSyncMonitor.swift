import CoreData
import SwiftUI

@MainActor
class CloudSyncMonitor: ObservableObject {

    enum SyncState: Equatable {
        case notAvailable
        case idle
        case syncing
        case error(String)

        var label: String {
            switch self {
            case .notAvailable: return "Non disponible"
            case .idle:         return "Synchronisé"
            case .syncing:      return "Synchronisation…"
            case .error:        return "Erreur de synchronisation"
            }
        }

        var systemImage: String {
            switch self {
            case .notAvailable: return "icloud.slash"
            case .idle:         return "icloud.fill"
            case .syncing:      return "arrow.clockwise.icloud"
            case .error:        return "exclamationmark.icloud"
            }
        }

        var color: Color {
            switch self {
            case .notAvailable: return .secondary
            case .idle:         return .green
            case .syncing:      return .blue
            case .error:        return .red
            }
        }
    }

    @Published var syncState: SyncState = .notAvailable
    @Published var lastSyncDate: Date? = {
        let ts = UserDefaults.standard.double(forKey: "cloudSync_lastSuccessTimestamp")
        return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }()

    private let dateKey = "cloudSync_lastSuccessTimestamp"

    init() {
        guard CoreDataManager.shared.isCloudSyncEnabled else { return }

        syncState = .idle
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCloudKitEvent(_:)),
            name: NSPersistentCloudKitContainer.eventChangedNotification,
            object: CoreDataManager.shared.container
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private nonisolated func handleCloudKitEvent(_ notification: Notification) {
        guard
            let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event
        else { return }

        Task { @MainActor in
            self.applyEvent(event)
        }
    }

    private func applyEvent(_ event: NSPersistentCloudKitContainer.Event) {
        switch event.type {
        case .setup:
            if event.endDate != nil {
                syncState = event.succeeded ? .idle : .error(event.error?.localizedDescription ?? "Erreur d'initialisation CloudKit")
            } else {
                syncState = .syncing
            }

        case .import:
            if event.endDate != nil {
                if event.succeeded {
                    markSyncSuccess()
                } else {
                    syncState = .error(event.error?.localizedDescription ?? "Erreur d'importation CloudKit")
                }
            } else {
                syncState = .syncing
            }

        case .export:
            if event.endDate != nil {
                if event.succeeded {
                    markSyncSuccess()
                } else {
                    syncState = .error(event.error?.localizedDescription ?? "Erreur d'exportation CloudKit")
                }
            } else {
                syncState = .syncing
            }

        @unknown default:
            break
        }
    }

    private func markSyncSuccess() {
        let now = Date()
        lastSyncDate = now
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: dateKey)
        syncState = .idle
    }
}
