//
//  HelpSupportView.swift
//  PatchTime
//
//  Aide & Support : FAQ cherchable groupée par thème.
//

import SwiftUI

struct HelpSupportView: View {
    @State private var searchText = ""
    @State private var expandedItems: Set<String> = []

    private var themes: [FAQTheme] { SupportContent.filteredThemes(matching: searchText) }
    private var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespaces).isEmpty }
    private var supportURL: URL? { URL(string: "https://patchbay-s.github.io/PatchTime/") }

    var body: some View {
        List {
            if themes.isEmpty {
                Section {
                    Text("help.noResults")
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(themes) { theme in
                Section(theme.title) {
                    ForEach(theme.items) { item in
                        DisclosureGroup(isExpanded: expansionBinding(for: item.id)) {
                            Text(item.answer)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .padding(.vertical, 4)
                        } label: {
                            Text(item.question)
                        }
                    }
                }
            }

            Section {
                Text("help.contact.description")
                if let supportURL {
                    Link("help.contact.website", destination: supportURL)
                }
            } header: {
                Text("help.section.contact")
            }

        }
        .readableContentWidth()
        .searchable(text: $searchText, prompt: Text("help.search.prompt"))
        .navigationTitle(Text("help.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func expansionBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { isSearching || expandedItems.contains(id) },
            set: { isExpanded in
                if isExpanded { expandedItems.insert(id) } else { expandedItems.remove(id) }
            }
        )
    }

}

#Preview {
    NavigationStack { HelpSupportView() }
}
