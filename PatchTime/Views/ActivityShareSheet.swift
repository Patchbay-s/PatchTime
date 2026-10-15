//
//  ActivityShareSheet.swift
//  PatchTime
//
//  Feuille de partage système pour les exports (PDF, CSV, sauvegarde). Présentée depuis le
//  contrôleur au premier plan : feuille classique sur iPhone, popover centré sur iPad et
//  Mac (UIActivityViewController exige une ancre en popover, sinon plantage ou feuille vide).
//

import SwiftUI
import UIKit

extension View {
    func activityShareSheet(isPresented: Binding<Bool>, items: [Any]) -> some View {
        background(ActivitySharePresenter(isPresented: isPresented, items: items))
    }
}

private struct ActivitySharePresenter: UIViewRepresentable {
    @Binding var isPresented: Bool
    let items: [Any]

    final class Coordinator {
        var controller: UIActivityViewController?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ anchor: UIView, context: Context) {
        guard isPresented, context.coordinator.controller == nil else { return }
        let binding = $isPresented
        guard !items.isEmpty else {
            DispatchQueue.main.async { binding.wrappedValue = false }
            return
        }

        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        let coordinator = context.coordinator
        controller.completionWithItemsHandler = { _, _, _, _ in
            coordinator.controller = nil
            binding.wrappedValue = false
        }
        if let popover = controller.popoverPresentationController {
            popover.sourceView = anchor
            popover.sourceRect = CGRect(x: anchor.bounds.midX, y: anchor.bounds.midY, width: 1, height: 1)
            popover.permittedArrowDirections = []
        }
        coordinator.controller = controller

        DispatchQueue.main.async {
            guard let presenter = UIApplication.shared.topViewController else {
                coordinator.controller = nil
                binding.wrappedValue = false
                return
            }
            presenter.present(controller, animated: true)
        }
    }
}
