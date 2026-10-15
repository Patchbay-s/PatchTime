import SwiftUI

struct ToastView: View {
    let message: String
    var icon: String = "checkmark.circle.fill"

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.green)
            Text(message)
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    }
}

extension View {
    func toast(isPresented: Binding<Bool>, message: String, icon: String = "checkmark.circle.fill") -> some View {
        self.overlay(alignment: .bottom) {
            if isPresented.wrappedValue {
                ToastView(message: message, icon: icon)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(999)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isPresented.wrappedValue)
    }
}
