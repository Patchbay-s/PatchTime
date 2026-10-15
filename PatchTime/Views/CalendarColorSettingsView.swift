import SwiftUI

struct CalendarColorSettingsView: View {
    /// Cache local synchronisé avec `CalendarColorStore` à chaque écriture.
    @State private var selections: [CalendarDotCategory: CalendarPaletteColor] = Dictionary(
        uniqueKeysWithValues: CalendarDotCategory.allCases.map { ($0, CalendarColorStore.paletteColor(for: $0)) }
    )
    @State private var showResetConfirmation = false
    @State private var showSavedToast = false

    var body: some View {
        Form {
            Section(header: Text("Couleurs par catégorie"), footer: Text("Un jour peut cumuler plusieurs pastilles à la fois (ex: jour travaillé + repas + à valider).")) {
                ForEach(CalendarDotCategory.allCases, id: \.self) { category in
                    Picker(selection: binding(for: category)) {
                        ForEach(CalendarPaletteColor.allCases) { palette in
                            Label {
                                Text(palette.label)
                            } icon: {
                                Circle().fill(palette.swiftUIColor).overlay(Circle().strokeBorder(Color.primary.opacity(0.25), lineWidth: 0.5)).frame(width: 14, height: 14)
                            }
                            .tag(palette)
                        }
                    } label: {
                        HStack {
                            Circle().fill((selections[category] ?? category.defaultPaletteColor).swiftUIColor).overlay(Circle().strokeBorder(Color.primary.opacity(0.25), lineWidth: 0.5)).frame(width: 14, height: 14)
                            Text(category.label)
                        }
                    }
                }
            }

            Section(footer: Text("La sauvegarde se fait normalement automatiquement à chaque changement — ce bouton force une écriture immédiate si vous préférez vous en assurer explicitement.")) {
                Button {
                    saveAllColors()
                } label: {
                    Label("Enregistrer", systemImage: "checkmark.circle")
                }
            }

            Section {
                Button("Réinitialiser aux couleurs par défaut", role: .destructive) {
                    showResetConfirmation = true
                }
            }
        }
        .navigationTitle("Couleurs du calendrier")
        .toast(isPresented: $showSavedToast, message: "Couleurs enregistrées")
        .alert("Réinitialiser les couleurs ?", isPresented: $showResetConfirmation) {
            Button("Annuler", role: .cancel) {}
            Button("Réinitialiser", role: .destructive) {
                CalendarColorStore.resetToDefaults()
                selections = Dictionary(uniqueKeysWithValues: CalendarDotCategory.allCases.map { ($0, $0.defaultPaletteColor) })
            }
        } message: {
            Text("Chaque catégorie retrouvera sa couleur par défaut.")
        }
    }

    /// Écrit à la fois dans le cache local (`selections`, pour un rendu immédiat observé par
    /// SwiftUI) et dans `CalendarColorStore` (persistance UserDefaults lue par `CalendarView`)
    /// — l'écriture est persistée immédiatement pour que l'affichage reste cohérent.
    private func binding(for category: CalendarDotCategory) -> Binding<CalendarPaletteColor> {
        Binding(
            get: { selections[category] ?? category.defaultPaletteColor },
            set: { newValue in
                selections[category] = newValue
                CalendarColorStore.setPaletteColor(newValue, for: category)
            }
        )
    }

    /// Garantie de sauvegarde indépendante de tout mécanisme réactif : réécrit explicitement
    /// chaque sélection et force `synchronize()` — la voie réactive de `binding(for:)` écrit
    /// déjà à chaque changement, mais ce bouton ne doit dépendre d'aucun de ses chemins internes
    /// pour rester fiable si l'un d'eux échoue silencieusement.
    private func saveAllColors() {
        for category in CalendarDotCategory.allCases {
            CalendarColorStore.setPaletteColor(selections[category] ?? category.defaultPaletteColor, for: category)
        }
        UserDefaults.standard.synchronize()
        showSavedToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { showSavedToast = false }
    }
}

#Preview {
    NavigationStack {
        CalendarColorSettingsView()
    }
}
