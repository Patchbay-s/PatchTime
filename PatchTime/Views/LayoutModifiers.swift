//
//  LayoutModifiers.swift
//  PatchTime
//
//  Largeur de lecture maximale pour les listes et formulaires : sur iPad (et Mac), le
//  contenu ne s'étire pas sur toute la largeur d'un écran 13". Sans effet sur iPhone.
//

import SwiftUI

private struct ReadableContentWidth: ViewModifier {
    let maxWidth: CGFloat
    @State private var containerWidth: CGFloat = 0

    func body(content: Content) -> some View {
        content
            // nil = marges par défaut du système (iPhone, fenêtres étroites, Split View).
            .contentMargins(.horizontal, horizontalMargin, for: .scrollContent)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { width in
                containerWidth = width
            }
    }

    private var horizontalMargin: CGFloat? {
        containerWidth > maxWidth + 40 ? (containerWidth - maxWidth) / 2 : nil
    }
}

extension View {
    /// À appliquer sur une `List`, un `Form` ou une `ScrollView`.
    func readableContentWidth(_ maxWidth: CGFloat = 700) -> some View {
        modifier(ReadableContentWidth(maxWidth: maxWidth))
    }
}
