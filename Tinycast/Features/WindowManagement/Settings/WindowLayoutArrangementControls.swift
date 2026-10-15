import SwiftUI

struct WindowLayoutArrangementControls: View {
    let draft: WindowLayoutDraft
    let screens: [WindowLayoutScreen]
    @State private var showingNameEditor = false
    @State private var renaming = false
    @State private var proposedName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Picker("Arrangement", selection: Binding(
                    get: { draft.selectedArrangementID }, set: { draft.selectArrangement($0) }
                )) {
                    Text("Default").tag(UUID?.none)
                    ForEach(draft.arrangements) { arrangement in
                        Text(arrangement.name).tag(Optional(arrangement.id))
                    }
                }
                .labelsHidden()
                .accessibilityLabel("Arrangement")
                .frame(maxWidth: .infinity, alignment: .leading)
                Button("Add display setup…") {
                    renaming = false
                    proposedName = suggestedName
                    showingNameEditor = true
                }
                .disabled(draft.entries.isEmpty || screens.isEmpty || currentSetup != nil)
                .help(currentSetup.map { "Already saved as “\($0.name)”; choose it from Arrangement." }
                      ?? "Copy this arrangement for the currently connected displays")
                Menu {
                    Button("Rename setup…") {
                        renaming = true
                        proposedName = draft.arrangementName
                        showingNameEditor = true
                    }
                    .disabled(draft.selectedArrangementID == nil)
                    Button("Remove setup", role: .destructive) { draft.removeArrangement() }
                        .disabled(draft.selectedArrangementID == nil)
                } label: {
                    Image(systemName: "ellipsis").frame(width: Theme.Size.settingsRowIcon)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .accessibilityLabel("Arrangement options")
            }
            Text(draft.selectedArrangementID == nil
                 ? "Default runs when no display setup matches."
                 : "Runs with: \(matchNames)")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .popover(isPresented: $showingNameEditor) {
            WindowLayoutSetupNameEditor(name: $proposedName, renaming: $renaming,
                displayNames: screens.map(\.display.name).joined(separator: ", "),
                cancel: { showingNameEditor = false }, save: saveName)
        }
    }

    private func saveName() {
        let value = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        if renaming {
            draft.arrangementName = value
        } else {
            draft.createArrangement(displays: screens.map(\.snapshot), name: value)
        }
        showingNameEditor = false
    }

    private var currentSetup: WindowLayoutArrangement? {
        let ids = Set(screens.map { $0.display.uuid.lowercased() })
        return draft.arrangements.first { $0.displaySet == ids }
    }

    private var suggestedName: String {
        let base = screens.count == 1
            ? (screens[0].isBuiltin ? "Laptop only" : screens[0].display.name) : "Docked"
        let existing = Set(draft.arrangements.map(\.name))
        if !existing.contains(base) { return base }
        var number = 2
        while existing.contains("\(base) \(number)") { number += 1 }
        return "\(base) \(number)"
    }

    private var matchNames: String {
        guard let value = draft.arrangements.first(where: { $0.id == draft.selectedArrangementID }) else { return "" }
        return value.displayIDs.map { id in value.displays.first { $0.id == id.lowercased() }?.display.name ?? id }
            .joined(separator: ", ")
    }
}

private struct WindowLayoutSetupNameEditor: View {
    @Binding var name: String
    @Binding var renaming: Bool
    let displayNames: String
    let cancel: () -> Void
    let save: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text(renaming ? "Rename display setup" : "Add display setup").font(.headline)
            TextField("Setup name", text: $name).onSubmit(save)
            if !renaming {
                Text("For: \(displayNames)").font(.caption).foregroundStyle(.secondary)
                Text("Copies the selected arrangement. Save below keeps the new setup.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button("Cancel", action: cancel)
                Button(renaming ? "Done" : "Add setup", action: save)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(width: Theme.Size.layoutInspectorColumn)
    }
}
