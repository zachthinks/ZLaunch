import SwiftUI

struct ShortcutPaletteDestinationPicker: View {
    let actions: [AppEntry]
    let current: String
    let onChoose: (String) -> Void
    let onCancel: () -> Void
    @State private var type = ShortcutPaletteActionPicker.ActionType.command
    @State private var search = ""
    @State private var website = ""

    private var sections: [(kind: AppEntry.Kind, entries: [AppEntry])] {
        ShortcutPaletteActionPicker.sections(actions: actions, type: type, search: search)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Picker("Action type", selection: $type) {
                    ForEach(ShortcutPaletteActionPicker.ActionType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                Spacer()
                Button("Cancel", action: onCancel)
            }
            if type == .website {
                HStack {
                    TextField("https://example.com", text: $website).textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Website address")
                    Button("Use Website") { onChoose("website:" + website.trimmingCharacters(in: .whitespacesAndNewlines)) }
                        .disabled(ShortcutPaletteConfiguration.websiteURL(
                            for: "website:" + website.trimmingCharacters(in: .whitespacesAndNewlines)) == nil)
                }
            } else {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search actions or categories…", text: $search).textFieldStyle(.plain)
                }
                .padding(10)
                .background(Theme.Colors.controlSurface, in: .rect(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.Colors.border))
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(sections, id: \.kind) { section in
                            Text(section.kind.descriptor.sectionTitle).font(.caption.bold()).foregroundStyle(.secondary)
                            ForEach(section.entries) { entry in
                                Button { onChoose(entry.id) } label: {
                                    HStack(spacing: 10) {
                                        AppIconView(app: entry, pointSize: 20).frame(width: 20, height: 20)
                                        Text(entry.name)
                                        Spacer()
                                        if entry.id == current { Image(systemName: "checkmark") }
                                    }
                                    .padding(6).contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        if sections.isEmpty { Text("No matching actions.").foregroundStyle(.secondary) }
                    }
                }
                .frame(height: 220)
            }
        }
        .padding(12)
        .background(Theme.Colors.windowSurface, in: .rect(cornerRadius: 8))
        .onAppear {
            if current.hasPrefix("website:") {
                type = .website
                website = String(current.dropFirst(8))
            } else if let entry = actions.first(where: { $0.id == current }) {
                type = ShortcutPaletteActionPicker.ActionType.allCases.first { $0.includes(entry.kind) } ?? .command
            }
        }
    }
}
