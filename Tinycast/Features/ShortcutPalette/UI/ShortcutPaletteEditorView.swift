import SwiftUI

struct ShortcutPaletteEditorView: View {
    @Environment(HotKeyManager.self) private var hotKeys
    let repository: ShortcutPaletteRepository
    let actions: [AppEntry]
    let confirmDiscard: (String) async -> Bool
    let confirmRemoval: (String) async -> Bool
    let registerCloseHandler: (@escaping () -> Bool) -> Void
    let closeEditor: () -> Void
    let preview: () -> Void
    @State private var draft = ShortcutPaletteMenuDraft(configuration: .starter)
    @State private var expanded: Set<UUID> = []
    @State private var choosingAction: UUID?
    @State private var additionParent: UUID?
    @State private var showingActionPicker = false
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
    private var additionTitle: String { additionParent.flatMap { draft.node($0)?.label } ?? "Main menu" }
    private var additionCount: Int { additionParent.flatMap { draft.node($0)?.children?.count } ?? draft.nodes.count }

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
        .sheet(isPresented: $showingActionPicker) {
            ShortcutPaletteActionPicker(actions: actions, destination: additionTitle,
                capacity: 26 - additionCount, onAdd: { entries in
                    _ = try draft.append(entries.map { (label: $0.name, action: Optional($0.id)) }, to: additionParent)
                    if let additionParent { expanded.insert(additionParent) }
                    showingActionPicker = false
                }, onWebsite: {
                    do {
                        let ids = try draft.append([("New Website", "website:")], to: additionParent)
                        if let additionParent { expanded.insert(additionParent) }
                        choosingAction = ids.first
                        showingActionPicker = false
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your menu").font(.title3.bold())
                    Text("Edit keys and names here. Expand a submenu or choose an action to change it.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Add Submenu", systemImage: "folder.badge.plus") { addSubmenu(to: nil) }
                    .disabled(draft.nodes.count >= 26)
                Button("Add Actions…", systemImage: "plus") { openBatch(in: nil) }
                    .disabled(draft.nodes.count >= 26)
            }
            HStack {
                Text("Key").frame(width: 60)
                Text("Name").frame(maxWidth: .infinity, alignment: .leading)
                Text("Action / Submenu").frame(maxWidth: .infinity, alignment: .leading)
                Color.clear.frame(width: 92, height: 1)
            }
            .font(.caption).foregroundStyle(.secondary).padding(.leading, 32)
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(draft.rows(expanded: expanded)) { row in
                        VStack(alignment: .leading, spacing: 10) {
                            editorRow(row)
                            if let issue = draft.issue(for: row.id) { validation(issue) }
                            if choosingAction == row.id, row.node.children == nil {
                                ShortcutPaletteDestinationPicker(actions: actions, current: row.node.action ?? "") { action in
                                    draft.edit(row.id) {
                                        $0.action = action
                                        if $0.label == "New Website",
                                            let host = ShortcutPaletteConfiguration.websiteURL(for: action)?.host {
                                            $0.label = host
                                        }
                                    }
                                    choosingAction = nil
                                } onCancel: { choosingAction = nil }
                                .id(row.id)
                            }
                            if let children = row.node.children, expanded.contains(row.id) {
                                HStack {
                                    Button("Add Actions…", systemImage: "plus") { openBatch(in: row.id) }
                                    Button("Add Submenu", systemImage: "folder.badge.plus") { addSubmenu(to: row.id) }
                                        .disabled(row.depth >= 4)
                                    Text("Inside \(row.node.label)").font(.caption).foregroundStyle(.secondary)
                                }
                                .disabled(children.count >= 26)
                            }
                        }
                        .padding(12)
                        .background(row.node.children == nil ? Theme.Colors.cardFill : Theme.Colors.controlSurface,
                                    in: .rect(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.Colors.border))
                        .padding(.leading, CGFloat(row.depth) * 20)
                    }
                }
            }
            if let validationMessage { validation(validationMessage) }
        }
        .padding(16)
        .background(Theme.Colors.cardFill, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.Colors.border))
    }

    private func editorRow(_ row: ShortcutPaletteMenuDraft.Row) -> some View {
        HStack(spacing: 8) {
            if row.node.children != nil {
                Button {
                    if expanded.contains(row.id) { expanded.remove(row.id) } else { expanded.insert(row.id) }
                } label: {
                    Image(systemName: expanded.contains(row.id) ? "chevron.down" : "chevron.right")
                        .frame(width: 16)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(expanded.contains(row.id) ? "Collapse" : "Expand") \(row.node.label)")
            } else { Color.clear.frame(width: 16, height: 1) }
            TextField("A–Z", text: Binding(
                get: { draft.node(row.id)?.key ?? "" }, set: { value in draft.edit(row.id) { $0.key = value } }))
                .frame(width: 48).accessibilityLabel("Key for \(row.node.label)")
            TextField("Name", text: Binding(
                get: { draft.node(row.id)?.label ?? "" }, set: { value in draft.edit(row.id) { $0.label = value } }))
                .frame(minWidth: 100, maxWidth: .infinity).accessibilityLabel("Name for \(row.node.label)")
            if let children = row.node.children {
                Text("Submenu · \(children.count) items")
                    .foregroundStyle(.secondary).frame(minWidth: 130, maxWidth: .infinity, alignment: .leading)
            } else {
                Button { choosingAction = choosingAction == row.id ? nil : row.id } label: {
                    HStack {
                        Text(actionName(row.node.action)).lineLimit(1)
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.up.chevron.down").font(.caption)
                    }
                }
                .frame(minWidth: 130, maxWidth: .infinity)
                .accessibilityLabel("Change action for \(row.node.label): \(actionName(row.node.action))")
            }
            HStack(spacing: 4) {
                Button { draft.move(row.id, by: -1) } label: { Image(systemName: "arrow.up") }
                    .disabled(row.position == 0).help("Move up").accessibilityLabel("Move \(row.node.label) up")
                Button { draft.move(row.id, by: 1) } label: { Image(systemName: "arrow.down") }
                    .disabled(row.position == row.count - 1).help("Move down").accessibilityLabel("Move \(row.node.label) down")
                Button(role: .destructive) { remove(row.id) } label: { Image(systemName: "trash") }
                    .help("Remove").accessibilityLabel("Remove \(row.node.label)")
            }
            .buttonStyle(.borderless).frame(width: 92)
        }
        .textFieldStyle(.roundedBorder)
    }

    private func actionName(_ action: String?) -> String {
        guard let action, !action.isEmpty else { return "Choose action…" }
        if action.hasPrefix("website:") {
            let address = String(action.dropFirst(8))
            return address.isEmpty ? "Enter website…" : address
        }
        return actions.first { $0.id == action }?.name ?? "Unavailable: \(action)"
    }

    private func openBatch(in parent: UUID?) {
        additionParent = parent
        showingActionPicker = true
    }

    private func addSubmenu(to parent: UUID?) {
        do {
            let ids = try draft.append([("New Submenu", nil)], to: parent)
            expanded.formUnion(ids)
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
            if confirmed { draft.remove(id); expanded.remove(id) }
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
                        set: { draft.appearance.displayMode = $0 })) {
                        Text("List").tag(ShortcutPaletteConfiguration.DisplayMode.list)
                        Text("Grid").tag(ShortcutPaletteConfiguration.DisplayMode.grid)
                        Text("Floating Tiles").tag(ShortcutPaletteConfiguration.DisplayMode.floatingTiles)
                        }.pickerStyle(.segmented).labelsHidden().frame(width: 300)
                    }
                    Text(displayDescription).foregroundStyle(.secondary)
                    HStack(spacing: 20) {
                        Text("Key size").frame(width: 90, alignment: .leading)
                        Picker("Key size", selection: Binding(
                            get: { draft.appearance.tileSize ?? .medium },
                            set: { draft.appearance.tileSize = $0 })) {
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
        case .list: "A compact text menu with a letter beside each choice."
        case .grid: "Square keys arranged together in a single window."
        case .floatingTiles: "Individual keys float over your desktop, with only the current choices visible."
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
            preview()
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
