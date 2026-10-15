import SwiftUI

/// Palette fixe proposée pour personnaliser les couleurs du calendrier (Réglages > Couleurs
/// du calendrier) — pas de color picker libre, pour garder des couleurs lisibles et
/// distinctes entre elles.
enum CalendarPaletteColor: String, CaseIterable, Identifiable {
    case red, blue, green, yellow, brown, purple, orange, gray, pink, indigo

    var id: String { rawValue }

    var label: String {
        switch self {
        case .red: return "Rouge"
        case .blue: return "Bleu"
        case .green: return "Vert"
        case .yellow: return "Jaune"
        case .brown: return "Marron"
        case .purple: return "Violet"
        case .orange: return "Orange"
        case .gray: return "Gris"
        case .pink: return "Rose"
        case .indigo: return "Indigo"
        }
    }

    var swiftUIColor: Color {
        switch self {
        case .red: return .red
        case .blue: return .blue
        case .green: return .green
        case .yellow: return .yellow
        case .brown: return .brown
        case .purple: return .purple
        case .orange: return .orange
        case .gray: return .gray
        case .pink: return .pink
        case .indigo: return .indigo
        }
    }
}
