import SwiftUI

struct CloudSyncStatusView: View {
    @EnvironmentObject private var syncMonitor: CloudSyncMonitor

    var body: some View {
        HStack(spacing: 12) {
            if case .syncing = syncMonitor.syncState {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: syncMonitor.syncState.systemImage)
                    .foregroundColor(syncMonitor.syncState.color)
                    .font(.title3)
                    .frame(width: 28)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(syncMonitor.syncState.label)
                    .font(.subheadline)
                    .foregroundColor(syncMonitor.syncState.color)

                if let date = syncMonitor.lastSyncDate {
                    Text("Dernière sync : \(SharedFormatters.frenchDateTime.string(from: date))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else if case .error(let msg) = syncMonitor.syncState {
                    Text(msg)
                        .font(.caption2)
                        .foregroundColor(.red)
                        .lineLimit(2)
                } else if !CoreDataManager.shared.isCloudSyncEnabled {
                    Text("Redémarrez l'app pour activer la sync")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    List {
        CloudSyncStatusView()
            .environmentObject(CloudSyncMonitor())
    }
}
