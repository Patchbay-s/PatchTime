import SwiftUI

/// Bouton toolbar qui révèle/masque une section repliée par défaut, avec animation —
/// pattern introduit pour le bandeau de filtres de `OvertimeListView` (Chantier 5), factorisé
/// ici pour être réutilisé sans dupliquer le `Button`/`withAnimation`/icône conditionnelle par
/// d'autres écrans avec le même besoin (ex: le réglage des blocs affichés dans Statistiques).
struct ToolbarDisclosureButton: View {
    @Binding var isExpanded: Bool
    var systemImage: String
    /// Icône alternative pour l'état déplié — pas tous les symboles SF ont une variante
    /// `.fill` correspondante, donc pas de dérivation automatique du nom : par défaut, même
    /// icône dans les deux états (seul le libellé d'accessibilité change).
    var systemImageExpanded: String? = nil
    var expandedLabel: String
    var collapsedLabel: String

    var body: some View {
        Button {
            withAnimation { isExpanded.toggle() }
        } label: {
            Image(systemName: isExpanded ? (systemImageExpanded ?? systemImage) : systemImage)
        }
        .accessibilityLabel(isExpanded ? expandedLabel : collapsedLabel)
    }
}
