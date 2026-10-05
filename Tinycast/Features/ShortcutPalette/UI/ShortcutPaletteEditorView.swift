import SwiftUI

struct ShortcutPaletteEditorView: View {
    @Environment(HotKeyManager.self) private var hotKeys
    let repository: ShortcutPaletteRepository
    let actions: [AppEntry]
    let confirmDiscard: (String) async -> Bool
    let confirmRemoval: (String) async -> Bool
    let registerCloseHandler: (@escaping () -> Bool) -> Void
    let closeEditor: () -> Void
    let preview: (ShortcutPaletteConfiguration) -> Void
    @State private var draft = ShortcutPaletteMenuDraft(configuration: .starter)
    @State private var expanded: Set<UUID> = []
    @State private var selectedMenu: UUID?
    @State private var choosingAction: UUID?
    @State private var additionRequest: AdditionRequest?
    private struct AdditionRequest: Identifiable {
        let id = UUID()
        let parent: UUID?
    }
    @State private var savedConfiguration: ShortcutPaletteConfiguration?
    @State private var validationMessage: String?
    @State private var section = Section.menu
    @State private var loaded = false
    @State private var saving = false
    @State private var askingToDiscard = false
    @State private var closeAfterSave = false
    @State private var previewAfterSave = false
    @State private var saveTask: Task<Void, Never>?
    private enum Section: String, CaseIterable { case menu = "Menu", appearance = "Appearance" }

    private var hasChanges: Bool { savedConfiguration.map { $0 != draft.configuration } ?? false }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            HStack {
                Picker("Setup section", selection: $section) {
                    ForEach(Section.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: 240)
                Spacer()
                Label(status, systemImage: validationMessage == nil ? "checkmark.circle" : "exclamationmark.circle")
                    .font(.callout).foregroundStyle(validationMessage == nil ? Color.secondary : Theme.Colors.warning)
                Button("Try LaunchDeck", systemImage: "play") { previewAfterSave = true; save() }
            }
            if section == .menu { menuEditor } else { appearanceEditor }
        }
        .padding(24)
        .disabled(!loaded || saving || askingToDiscard)
        .sheet(item: $additionRequest) { request in
            let parent = request.parent
            let title = parent.flatMap { draft.node($0)?.label } ?? "Main menu"
            let count = parent.flatMap { draft.node($0)?.children?.count } ?? draft.nodes.count
            ShortcutPaletteActionPicker(actions: actions, destination: title,
                capacity: ShortcutPaletteConfiguration.maximumItems - count, onAdd: { entries in
                    _ = try draft.append(entries.map { (label: $0.name, action: Optional($0.id)) }, to: parent)
                    if let parent { expanded.insert(parent) }
                    additionRequest = nil
                }, onWebsite: {
                    do {
                        let ids = try draft.append([("New Website", "website:")], to: parent)
                        if let parent { expanded.insert(parent) }
                        choosingAction = ids.first
                        additionRequest = nil
                    } catch { validationMessage = error.localizedDescription }
                })
        }
        .onAppear { registerCloseHandler { requestClose() } }
        .task {
            let result = await Task.detached { Result { try repository.load() } }.value
            guard !Task.isCancelled else { return }
            switch result {
            case .success(let configuration):
                draft = ShortcutPaletteMenuDraft(configuration: configuration)
                savedConfiguration = configuration
                expanded = Set(draft.nodes.filter { $0.children != nil }.map(\.id))
            case .failure(let error): validationMessage = "Couldn’t load your menu: \(error.localizedDescription)"
            }
            loaded = true
        }
        .task(id: draft) {
            guard loaded, savedConfiguration != nil, !saving, !askingToDiscard else { return }
            guard hasChanges else { validationMessage = nil; return }
            do { try await Task.sleep(for: .milliseconds(650)) } catch { return }
            guard !Task.isCancelled else { return }
            save()
        }
    }

    private var status: String {
        if saving { return "Saving…" }
        if validationMessage != nil { return "Needs attention" }
        return hasChanges ? "Changes pending" : "All changes saved"
    }

    private var menuEditor: some View {
        ShortcutPaletteMenuEditor(draft: $draft, expanded: $expanded, selectedMenu: $selectedMenu,
            choosingAction: $choosingAction, actions: actions, validationMessage: validationMessage,
            onAddActions: openBatch, onAddSubmenu: addSubmenu, onRemove: remove)
    }

    private func openBatch(in parent: UUID?) {
        additionRequest = AdditionRequest(parent: parent)
    }

    private func addSubmenu(to parent: UUID?) {
        do {
            let ids = try draft.append([("New Submenu", nil)], to: parent)
            expanded.formUnion(ids)
            selectedMenu = ids.first
            choosingAction = nil
            if let parent { expanded.insert(parent) }
        } catch { validationMessage = error.localizedDescription }
    }

    private func remove(_ id: UUID) {
        guard let node = draft.node(id) else { return }
        askingToDiscard = true
        Task {
            let suffix = node.children == nil ? "" : " and every item inside it"
            let confirmed = await confirmRemoval("Remove “\(node.label)”\(suffix)? This change saves immediately.")
            askingToDiscard = false
            if confirmed {
                draft.remove(id)
                expanded.remove(id)
                if let selectedMenu, draft.node(selectedMenu) == nil { self.selectedMenu = nil }
                if let choosingAction, draft.node(choosingAction) == nil { self.choosingAction = nil }
            }
        }
    }
    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                Text("LaunchDeck").font(.title.bold())
                Text("Your shortcuts, one key at a time.").foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text("Open LaunchDeck from anywhere").font(.caption).foregroundStyle(.secondary)
                HStack {
                    ShortcutRecorder(action: .command(.shortcutPalette))
                    Button("Change…") { hotKeys.recordingAction = .command(.shortcutPalette) }
                }
            }
        }
    }

    private var appearanceEditor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("How your menu looks").font(.title3.weight(.semibold))
                    HStack(spacing: 20) {
                        Text("Display").frame(width: 90, alignment: .leading)
                        Picker("Display", selection: Binding(
                        get: { draft.appearance.displayMode ?? .list },
                        set: { draft.appearance.displayMode = $0; save() })) {
                        Text("List").tag(ShortcutPaletteConfiguration.DisplayMode.list)
                        Text("Grid").tag(ShortcutPaletteConfiguration.DisplayMode.grid)
                        Text("Floating Tiles").tag(ShortcutPaletteConfiguration.DisplayMode.floatingTiles)
                        Text("Liquid Glass").tag(ShortcutPaletteConfiguration.DisplayMode.liquidGlass)
                        }.pickerStyle(.segmented).labelsHidden().frame(width: 400)
                    }
                    Text(displayDescription).foregroundStyle(.secondary)
                    HStack(spacing: 20) {
                        Text("Key size").frame(width: 90, alignment: .leading)
                        Picker("Key size", selection: Binding(
                            get: { draft.appearance.tileSize ?? .medium },
                            set: { draft.appearance.tileSize = $0; save() })) {
                            Text("Small").tag(ShortcutPaletteConfiguration.TileSize.small)
                            Text("Medium").tag(ShortcutPaletteConfiguration.TileSize.medium)
                            Text("Large").tag(ShortcutPaletteConfiguration.TileSize.large)
                        }.pickerStyle(.segmented).labelsHidden().frame(width: 300)
                            .disabled(draft.appearance.displayMode == nil || draft.appearance.displayMode == .list)
                    }
                    Text("Tiles wrap to fit your screen. List uses a fixed row size.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Divider()
                VStack(alignment: .leading, spacing: 16) {
                    Text("How your menu behaves").font(.title3.weight(.semibold))
                    Toggle("Escape closes the whole menu", isOn: Binding(
                        get: { draft.appearance.escapeClosesAll ?? false },
                        set: { draft.appearance.escapeClosesAll = $0 }))
                    Text("Off: Escape goes back one submenu, then closes from the first menu.")
                        .font(.caption).foregroundStyle(.secondary)
                    Toggle("Pressing the shortcut again returns to the first menu", isOn: Binding(
                        get: { draft.appearance.repeatTriggerResets ?? false },
                        set: { draft.appearance.repeatTriggerResets = $0 }))
                    Text("Off: pressing the shortcut again closes LaunchDeck.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let validationMessage { validation(validationMessage) }
            }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.Colors.cardFill, in: .rect(cornerRadius: 12))
    }

    private var displayDescription: String {
        switch draft.appearance.displayMode ?? .list {
        case .list: "A compact text menu with a key beside each choice."
        case .grid: "Square keys arranged together in a single window."
        case .floatingTiles: "Individual keys float over your desktop, with only the current choices visible."
        case .liquidGlass: "Rounded keys float over your desktop on native macOS Liquid Glass."
        }
    }

    private func validation(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle")
            .font(.callout).foregroundStyle(Theme.Colors.warning)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func save() {
        guard !saving, savedConfiguration != nil else { return }
        validationMessage = nil
        let configuration = draft.configuration
        do { try configuration.validate() } catch {
            validationMessage = error.localizedDescription
            previewAfterSave = false
            return
        }
        if !hasChanges { finishSave(); return }
        saving = true
        saveTask = Task {
            let result = await Task.detached { Result { try repository.save(configuration) } }.value
            guard !Task.isCancelled else { return }
            saving = false
            switch result {
            case .success: savedConfiguration = configuration; finishSave()
            case .failure(let error):
                closeAfterSave = false
                previewAfterSave = false
                validationMessage = "Couldn’t save: \(error.localizedDescription) Your edits are still here."
            }
        }
    }

    private func finishSave() {
        if closeAfterSave {
            closeAfterSave = false
            closeEditor()
        } else if previewAfterSave {
            previewAfterSave = false
            if let savedConfiguration { preview(savedConfiguration) }
        }
    }

    private func requestClose() -> Bool {
        guard !askingToDiscard else { return false }
        if saving { closeAfterSave = true; return false }
        guard hasChanges else { return true }
        closeAfterSave = true
        save()
        if saving { return false }
        closeAfterSave = false
        askingToDiscard = true
        Task {
            let discard = await confirmDiscard("Your menu has unfinished edits. "
                + (validationMessage ?? "Finish editing to save them automatically."))
            askingToDiscard = false
            if discard { closeEditor() }
        }
        return false
    }
}
