//
//  UIApplication+TopViewController.swift
//  PatchTime
//
//  Contrôleur actuellement au premier plan, pour présenter du contenu UIKit (App Open Ad,
//  formulaires de consentement UMP) par-dessus une sheet SwiftUI éventuellement ouverte :
//  présenter depuis le rootViewController échoue silencieusement quand il présente déjà
//  quelque chose.
//

import UIKit

extension UIApplication {
    /// Fenêtre clé de la scène active au premier plan (iPad Split View / Slide Over :
    /// plusieurs scènes peuvent coexister, on prend celle qui est active).
    var activeKeyWindow: UIWindow? {
        let scenes = connectedScenes.compactMap { $0 as? UIWindowScene }
        let activeScenes = scenes.filter { $0.activationState == .foregroundActive }
        return (activeScenes.isEmpty ? scenes : activeScenes)
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }

    /// Contrôleur le plus haut de la pile de présentation de la fenêtre clé.
    var topViewController: UIViewController? {
        var top = activeKeyWindow?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}
