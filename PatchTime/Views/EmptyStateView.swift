import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 52, weight: .light))
                .foregroundColor(.secondary.opacity(0.6))
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .padding(.top, 4)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}
