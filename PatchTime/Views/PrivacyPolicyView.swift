import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Politique de confidentialité")
                        .font(.largeTitle.bold())
                    Text("Dernière mise à jour : 15 octobre 2026")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("PatchTime n'a pas de compte utilisateur ni de serveur applicatif.")
                }

                PolicySection(title: "1. Données enregistrées", icon: "internaldrive") {
                    Text("Les horaires, repas, congés, employeurs, contrats, profils de taux et préférences sont enregistrés dans la base de données de l'app. L'app utilise CloudKit pour synchroniser cette base dans votre compte iCloud privé. L'éditeur n'a pas accès à cette base.")
                    Text("Les widgets lisent un résumé local de vos données. Les rappels et alertes sont programmés sur votre appareil.")
                        .foregroundColor(.secondary)
                }

                PolicySection(title: "2. Services réseau", icon: "network") {
                    Text("Pour télécharger les jours fériés français, l'app consulte calendrier.api.gouv.fr. Aucune donnée personnelle n'est envoyée dans cette requête.")
                }

                PolicySection(title: "3. Vos choix et vos droits", icon: "person.badge.shield.checkmark") {
                    BulletList(items: [
                        "**Accès, modification et export** : depuis les fonctionnalités de l'app",
                        "**Suppression** : supprimez les entrées dans l'app et gérez les données iCloud depuis les réglages de votre compte Apple",
                        "**Réclamation** : auprès de la CNIL (cnil.fr)"
                    ])
                }

                PolicySection(title: "4. Contact", icon: "envelope") {
                    Text("Pour une question sur cette politique ou vos données, écrivez à patchbay-s@proton.me ou passez par la page d'assistance du site PatchTime.")
                    if let mailURL = URL(string: "mailto:patchbay-s@proton.me?subject=PatchTime") {
                        Link("Écrire à patchbay-s@proton.me", destination: mailURL)
                    }
                    if let supportURL = URL(string: "https://patchbay-s.github.io/PatchTime/") {
                        Link("Ouvrir l'assistance PatchTime", destination: supportURL)
                    }
                }
            }
            .padding()
        }
        .readableContentWidth()
        .navigationTitle("Confidentialité")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PolicySection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                    .font(.headline)
                Text(title)
                    .font(.headline)
            }
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .font(.body)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

private struct BulletList: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Text("•").foregroundColor(.accentColor)
                    Text(LocalizedStringKey(item))
                }
            }
        }
    }
}

#Preview {
    NavigationStack { PrivacyPolicyView() }
}
