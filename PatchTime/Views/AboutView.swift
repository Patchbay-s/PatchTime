//
//  AboutView.swift
//  PatchTime
//
//  À propos : identité de l'app (nom, icône, version et build lus depuis le Bundle), résumé
//  des données, avertissement sur les estimations, licences et note.
//

import SwiftUI
import StoreKit

struct AboutView: View {
    @Environment(\.requestReview) private var requestReview
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section {
                VStack(spacing: 10) {
                    AppIconImage()
                        .frame(width: 84, height: 84)
                        .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                        .accessibilityHidden(true)
                    Text(AppInfo.displayName)
                        .font(.title2.bold())
                    Text("\(SupportText.localized("about.version")) \(AppInfo.version) (\(AppInfo.build))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("about.description")
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section {
                Button {
                    rateApp()
                } label: {
                    Label("about.rate", systemImage: "star")
                }
            } header: {
                Text("about.section.actions")
            }

            Section {
                Label("about.data.device", systemImage: "iphone")
                Label("about.data.icloud", systemImage: "icloud")
            } header: {
                Text("about.section.data")
            }
            .font(.callout)

            Section {
                Text("about.disclaimer")
                    .font(.callout)
                LabeledContent {
                    Text(baremeDetail(source: KmBareme.default2026.source, verified: KmBareme.default2026.verifiedDate))
                } label: {
                    Text("about.bareme.km")
                }
                LabeledContent {
                    Text(baremeDetail(source: MealBareme.default2026.source, verified: MealBareme.default2026.verifiedDate))
                } label: {
                    Text("about.bareme.meal")
                }
            } header: {
                Text("about.section.disclaimer")
            }
            .font(.callout)

            Section {
                licenseRow(title: "about.license.holidays", detail: "about.license.holidays.detail")
            } header: {
                Text("about.section.licenses")
            }
        }
        .readableContentWidth()
        .navigationTitle(Text("about.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func licenseRow(title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func baremeDetail(source: String, verified: String) -> String {
        "\(source) · \(SupportText.localized("about.bareme.verified")) \(verified)"
    }

    /// Avec l'identifiant App Store connu : page « Écrire un avis » ; sinon la demande de
    /// note système (qu'iOS peut choisir de ne pas afficher).
    private func rateApp() {
        if let appStoreURL = AppConstants.appStoreURL,
           let reviewURL = URL(string: appStoreURL.absoluteString + "?action=write-review") {
            openURL(reviewURL)
        } else {
            requestReview()
        }
    }
}

/// Icône principale de l'app, lue depuis le Bundle ; pictogramme de repli sinon.
private struct AppIconImage: View {
    var body: some View {
        if let icon = Self.primaryIcon {
            Image(uiImage: icon)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "clock.badge.checkmark")
                .resizable()
                .scaledToFit()
                .padding(16)
                .foregroundStyle(.tint)
                .background(Color(.secondarySystemBackground))
        }
    }

    private static var primaryIcon: UIImage? {
        guard let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
              let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let files = primary["CFBundleIconFiles"] as? [String],
              let name = files.last
        else { return nil }
        return UIImage(named: name)
    }
}

#Preview {
    NavigationStack { AboutView() }
}
