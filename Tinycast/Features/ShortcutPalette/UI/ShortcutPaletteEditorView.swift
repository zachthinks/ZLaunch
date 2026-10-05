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
    @State private var draft = ShortcutPaletteEditing(configuration: .starter)
    @State private var expanded: Set<[String]> = []
    @State private var selection: String?
    @State private var key = ""
    @State private var label = ""
    @State private var action = ""
    @State private var search = ""
    @State private var website = ""
    @State private var actionType = ActionType.command

    private typealias ActionType = ShortcutPaletteActionPicker.ActionType
    @State private var showingActionPicker = false
    @State private var notice: String?
    @State private var validationMessage: String?
    @State private var savedConfiguration: ShortcutPaletteConfiguration?
    @State private var section = Section.menu
    @State private var askingToDiscard = false
    @State private var closeAfterSave = false
    @State private var previewAfterSave = false
    private enum Section: String, CaseIterable { case menu = "Menu", appearance = "Appearance" }

    private struct Revision: Equatable {
        let configuration: ShortcutPaletteConfiguration
        let key: String
        let name: String
        let action: String
        let website: String
        let type: ActionType
        let loaded: Bool
        let selection: String?
        let path: [Int]
    }

    private var revision: Revision {
        Revision(configuration: draft.configuration, key: key, name: label,
                 action: action, website: website, type: actionType, loaded: loaded,
                 selection: selection, path: draft.path)
    }
    @State private var loaded = false
    @State private var saving = false
    @State private var saveTask: Task<Void, Never>?

    private var selectedItem: ShortcutPaletteConfiguration.Item? {
        draft.items.first { $0.id == selection }
    }

    private var hasChanges: Bool {
        guard let savedConfiguration else { return false }
        if draft.configuration != savedConfiguration { return true }
        guard let item = selectedItem else { return false }
        let destination = actionType == .website ? "website:" + website : action
        return key != item.key || label != item.label || (item.children == nil && destination != item.action)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            HStack {
                Picker("Setup section", selection: Binding(get: { section }, set: { value in
                    if apply() { section = value }
                })) {
                    ForEach(Section.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: 240)
                Spacer()
                Label(status, systemImage: statusSymbol)
                    .font(.callout).foregroundStyle(validationMessage == nil ? Color.secondary : Theme.Colors.warning)
                Button("Try LaunchDeck", systemImage: "play") { tryMenu() }
                    .disabled(!loaded || saving || askingToDiscard)
            }
            if section == .menu { menuEditor } else { appearanceEditor }
        }
        .padding(24)
        .disabled(!loaded || saving || askingToDiscard)
        .sheet(isPresented: $showingActionPicker) {
            ShortcutPaletteActionPicker(actions: actions, destination: additionTitle,
                capacity: 26 - additionCount, onAdd: addActions, onWebsite: {
                    showingActionPicker = false
                    add(group: false)
                    actionType = .website
                })
        }
        .onAppear { registerCloseHandler { requestClose() } }
        .task {
            let result = await Task.detached { Result { try repository.load() } }.value
            guard !Task.isCancelled else { return }
            switch result {
            case .success(let configuration):
                draft = ShortcutPaletteEditing(configuration: configuration)
                savedConfiguration = configuration
                expanded = Set(configuration.items.filter { $0.children != nil }.map { [$0.id] })
            case .failure(let error):
                validationMessage = "Couldn’t load your menu: \(error.localizedDescription)"
            }
            loaded = true
        }
        .task(id: revision) {
            guard loaded, savedConfiguration != nil, hasChanges, !saving, !askingToDiscard else { return }
            do { try await Task.sleep(for: .milliseconds(650)) } catch { return }
            guard !Task.isCancelled, !askingToDiscard else { return }
            save()
        }
    }

    private var status: String {
        if saving { return "Saving…" }
        if validationMessage != nil { return "Needs attention" }
        return hasChanges ? "Changes pending" : "All changes saved"
    }

    private var statusSymbol: String {
        if validationMessage != nil { return "exclamationmark.circle" }
        return saving || hasChanges ? "clock" : "checkmark.circle"
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

    private var additionTitle: String {
        if let selectedItem, selectedItem.children != nil { return selectedItem.label }
        return "Main menu" + draft.title.dropFirst(4)
    }

    private var additionDepth: Int { draft.path.count + (selectedItem?.children == nil ? 0 : 1) }
    private var additionCount: Int { selectedItem?.children?.count ?? draft.items.count }

    private var menuEditor: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Button { navigate(to: [], selecting: nil) } label: {
                    Label("Main menu", systemImage: "list.bullet")
                        .font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain).help("Select the main menu to add a top-level item")
                Text("Expand submenus to see and edit their actions.")
                    .font(.caption).foregroundStyle(.secondary)
                List(selection: Binding(
                    get: { selection.map { draft.keys + [$0] } },
                    set: { value in
                        guard let value, let id = value.last else { return }
                        navigate(to: Array(value.dropLast()), selecting: id)
                    })) {
                    ForEach(draft.rows(expanded: expanded)) { row in
                        HStack(spacing: 8) {
                            if row.item.children != nil {
                                Button {
                                    if expanded.contains(row.id) { expanded.remove(row.id) } else { expanded.insert(row.id) }
                                } label: {
                                    Image(systemName: expanded.contains(row.id) ? "chevron.down" : "chevron.right")
                                        .font(.caption).frame(width: 16, height: 24)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(expanded.contains(row.id) ? "Collapse" : "Expand") \(row.item.label)")
                            } else {
                                Color.clear.frame(width: 16, height: 1)
                            }
                            Text(row.item.key.uppercased()).font(.body.monospaced().weight(.semibold))
                                .frame(width: 28, height: 28)
                                .background(Theme.Colors.windowSurface, in: .rect(cornerRadius: 6))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(row.item.label).lineLimit(1)
                                Text(row.item.children.map { "Submenu · \($0.count) items" } ?? "Action")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.leading, CGFloat(row.depth) * 12)
                        .padding(.vertical, 4).tag(row.id)
                    }
                }
                .scrollContentBackground(.hidden)
                Text("Add to: \(additionTitle)")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                HStack {
                    Button("Add Submenu", systemImage: "folder.badge.plus") { add(group: true) }
                        .disabled(additionDepth >= 5)
                    Button("Add Actions…", systemImage: "plus") { if apply() { showingActionPicker = true } }
                }
                .disabled(additionCount >= 26)
                HStack {
                    Button { if apply(), let selection { draft.move(selection, by: -1) } } label: {
                        Image(systemName: "arrow.up")
                    }.help("Move up").disabled(selection == nil || selection == draft.items.first?.id)
                    Button { if apply(), let selection { draft.move(selection, by: 1) } } label: {
                        Image(systemName: "arrow.down")
                    }.help("Move down").disabled(selection == nil || selection == draft.items.last?.id)
                    Spacer()
                    Button("Remove", role: .destructive) { removeChoice() }.disabled(selection == nil)
                }
            }
            .padding(16).frame(width: 330)
            .background(Theme.Colors.controlSurface, in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.Colors.border))
            detail
                .padding(16)
                .background(Theme.Colors.cardFill, in: .rect(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.Colors.border))
        }
        .frame(maxHeight: .infinity)
    }

    private var appearanceEditor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("How your menu looks").font(.title3.weight(.semibold))
                    HStack(spacing: 20) {
                        Text("Display").frame(width: 90, alignment: .leading)
                        Picker("Display", selection: Binding(
                        get: { draft.configuration.displayMode ?? .list },
                        set: { draft.configuration.displayMode = $0 })) {
                        Text("List").tag(ShortcutPaletteConfiguration.DisplayMode.list)
                        Text("Grid").tag(ShortcutPaletteConfiguration.DisplayMode.grid)
                        Text("Floating Tiles").tag(ShortcutPaletteConfiguration.DisplayMode.floatingTiles)
                        }.pickerStyle(.segmented).labelsHidden().frame(width: 300)
                    }
                    Text(displayDescription).foregroundStyle(.secondary)
                    HStack(spacing: 20) {
                        Text("Key size").frame(width: 90, alignment: .leading)
                        Picker("Key size", selection: Binding(
                            get: { draft.configuration.tileSize ?? .medium },
                            set: { draft.configuration.tileSize = $0 })) {
                            Text("Small").tag(ShortcutPaletteConfiguration.TileSize.small)
                            Text("Medium").tag(ShortcutPaletteConfiguration.TileSize.medium)
                            Text("Large").tag(ShortcutPaletteConfiguration.TileSize.large)
                        }.pickerStyle(.segmented).labelsHidden().frame(width: 300)
                            .disabled(draft.configuration.displayMode == nil || draft.configuration.displayMode == .list)
                    }
                    Text("Tiles wrap to fit your screen. List uses a fixed row size.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Divider()
                VStack(alignment: .leading, spacing: 16) {
                    Text("How your menu behaves").font(.title3.weight(.semibold))
                    Toggle("Escape closes the whole menu", isOn: Binding(
                        get: { draft.configuration.escapeClosesAll ?? false },
                        set: { draft.configuration.escapeClosesAll = $0 }))
                    Text("Off: Escape goes back one group, then closes from the first menu.")
                        .font(.caption).foregroundStyle(.secondary)
                    Toggle("Pressing the shortcut again returns to the first menu", isOn: Binding(
                        get: { draft.configuration.repeatTriggerResets ?? false },
                        set: { draft.configuration.repeatTriggerResets = $0 }))
                    Text("Off: pressing the shortcut again closes LaunchDeck.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let validationMessage { validation(validationMessage) }
            }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.Colors.cardFill, in: .rect(cornerRadius: 12))
    }

    private var displayDescription: String {
        switch draft.configuration.displayMode ?? .list {
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

    @ViewBuilder private var detail: some View {
        if let selectedItem {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedItem.children == nil ? "Edit action" : "Edit submenu")
                        .font(.title3.weight(.semibold))
                    Text(selectedItem.children == nil ? "Choose what happens when you press this key."
                         : "Press this key in LaunchDeck to open the actions inside this submenu.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Key").font(.caption).foregroundStyle(.secondary)
                        TextField("A–Z", text: $key).frame(width: 70)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Name").font(.caption).foregroundStyle(.secondary)
                        TextField("Choice name", text: $label)
                    }
                }
                .textFieldStyle(.roundedBorder)
                if selectedItem.children != nil {
                    Text("\(selectedItem.children?.count ?? 0) items in this submenu")
                        .foregroundStyle(.secondary)
                    Text("Use the arrow beside this submenu to expand its items in the menu tree. Select an item to edit it here.")
                        .font(.callout).foregroundStyle(.secondary)
                    HStack {
                        Button("Add Actions Here…", systemImage: "plus") { if apply() { showingActionPicker = true } }
                        Button("Add Submenu Here", systemImage: "folder.badge.plus") { add(group: true) }
                            .disabled(draft.path.count >= 4)
                    }
                    .disabled((selectedItem.children?.count ?? 0) >= 26)
                    Spacer()
                } else {
                    Picker("What should this key do?", selection: Binding(get: { actionType }, set: { type in
                        actionType = type
                        search = ""
                        if !actions.contains(where: { $0.id == action && type.includes($0.kind) }) { action = "" }
                    })) {
                        ForEach(ActionType.allCases) { type in Text(type.rawValue).tag(type) }
                    }
                    if actionType == .website {
                        TextField("https://example.com", text: $website)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Website address")
                        Text("Opens in your default browser. Use a complete http:// or https:// address.")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                            TextField(actionType.searchPrompt, text: $search).textFieldStyle(.plain)
                                .accessibilityLabel("Search actions or categories")
                            if !search.isEmpty {
                                Button { search = "" } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                                .buttonStyle(.plain).help("Clear search")
                                .accessibilityLabel("Clear search")
                            }
                        }
                        .padding(10)
                        .background(Theme.Colors.controlSurface, in: .rect(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.Colors.border))
                        if filteredActions.isEmpty {
                            Text(emptyActionMessage).font(.callout).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        } else {
                            List(selection: $action) {
                                ForEach(actionSections, id: \.kind) { section in
                                    SwiftUI.Section(section.kind.descriptor.sectionTitle) {
                                        ForEach(section.entries) { entry in
                                            HStack(spacing: 10) {
                                                AppIconView(app: entry, pointSize: 24)
                                                    .frame(width: 24, height: 24).accessibilityHidden(true)
                                                VStack(alignment: .leading) {
                                                    Text(entry.name)
                                                    Text(entry.kindLabel).font(.caption).foregroundStyle(.secondary)
                                                }
                                            }
                                            .tag(entry.id)
                                        }
                                    }
                                }
                            }
                        }
                        Text(actions.first(where: { $0.id == action }).map { "Selected action: \($0.name)" }
                             ?? "Choose a destination above.")
                            .font(.caption).foregroundStyle(.secondary)
                        if actionType == .appAction || actionType == .workflow {
                            Text(actionType == .appAction
                                 ? "App actions require an installed extension or an existing Quicklink."
                                 : "Uses existing macOS Shortcuts and custom commands configured in ZLaunch.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                if let validationMessage {
                    validation(validationMessage)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text(draft.items.isEmpty ? "Add your first action" : "Make it yours").font(.title3.weight(.semibold))
                Text(draft.items.isEmpty
                     ? "Use Add Action to choose an app, website, or command for this submenu."
                     : "Select a key on the left to customize it. Add actions to launch things, or submenus to organize more keys.")
                    .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if let validationMessage { validation(validationMessage) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var filteredActions: [AppEntry] { actionSections.flatMap(\.entries) }

    private var actionSections: [(kind: AppEntry.Kind, entries: [AppEntry])] {
        ShortcutPaletteActionPicker.sections(actions: actions, type: actionType, search: search)
    }

    private var emptyActionMessage: String {
        if !search.isEmpty { return "No matching actions. Try another search." }
        switch actionType {
        case .workflow:
            return "No available workflows. Add or enable Shortcuts or custom commands in ZLaunch settings, then reopen setup."
        case .appAction: return "No available app actions. Add an extension or Quicklink in ZLaunch settings, then reopen setup."
        default: return "No available actions in this category. Check ZLaunch settings, then reopen setup."
        }
    }

    private func select(_ id: String?) {
        selection = id
        validationMessage = nil
        guard let item = draft.items.first(where: { $0.id == id }) else { return }
        key = item.key
        label = item.label
        action = item.action ?? ""
        if action.hasPrefix("website:") {
            actionType = .website
            website = String(action.dropFirst("website:".count))
        } else {
            website = ""
            if let entry = actions.first(where: { $0.id == action }) {
                actionType = ActionType.allCases.first { $0.includes(entry.kind) } ?? .command
            }
        }
        search = ""
    }

    private func navigate(to parent: [String], selecting id: String?) {
        guard parent != draft.keys || id != selection else { return }
        if apply() {
            draft.navigate(to: parent)
            select(id)
            return
        }
        askingToDiscard = true
        Task {
            let message = "Discard unfinished edits to this choice and switch items? "
                + "A new action without a destination will be removed."
            let discard = await confirmDiscard(message)
            askingToDiscard = false
            guard discard else { return }
            if let selectedItem, selectedItem.children == nil, selectedItem.action?.isEmpty != false {
                draft.remove(selectedItem.id)
            }
            draft.navigate(to: parent)
            select(id)
        }
    }

    private func addActions(_ entries: [AppEntry]) throws {
        var updated = draft
        if let selectedItem, selectedItem.children != nil { updated.enter(selectedItem.id) }
        let added = try updated.appendActions(entries.map { (label: $0.name, action: $0.id) })
        expanded.insert(updated.keys)
        draft = updated
        select(added.first)
        showingActionPicker = false
    }

    private func add(group: Bool) {
        guard apply() else { return }
        if let selectedItem, selectedItem.children != nil {
            expanded.insert(draft.keys + [selectedItem.id])
            draft.enter(selectedItem.id)
            select(nil)
        }
        guard !group || draft.path.count < 5 else {
            validationMessage = "Submenus support up to six menu levels. Add an action here instead."
            return
        }
        guard let next = draft.nextKey else { return }
        let item = ShortcutPaletteConfiguration.Item(
            key: next, label: group ? "New Submenu" : "New Action",
            action: group ? nil : "", children: group ? [] : nil)
        do {
            try draft.update(item, replacing: nil)
            select(item.id)
            if group { expanded.insert(draft.keys + [item.id]) }
            if !group { actionType = .application }
        } catch { notice = error.localizedDescription }
    }

    @discardableResult private func apply() -> Bool {
        validationMessage = nil
        guard let selectedItem else { return true }
        let destination = actionType == .website
            ? "website:" + website.trimmingCharacters(in: .whitespacesAndNewlines) : action
        if selectedItem.children == nil {
            if actionType == .website && ShortcutPaletteConfiguration.websiteURL(for: destination) == nil {
                validationMessage = "Enter a complete website address, such as https://example.com."
                return false
            }
            if actionType != .website && destination.isEmpty {
                validationMessage = "Choose a destination from the list before saving this action."
                return false
            }
        }
        let resolvedLabel = label == "New Action"
            ? (actionType == .website ? ShortcutPaletteConfiguration.websiteURL(for: destination)?.host
                : actions.first(where: { $0.id == destination })?.name) ?? label : label
        let item = ShortcutPaletteConfiguration.Item(
            key: key.lowercased(), label: resolvedLabel,
            action: selectedItem.children == nil ? destination : nil, children: selectedItem.children)
        do {
            try draft.update(item, replacing: selectedItem.id)
            selection = item.id
            key = item.key
            label = item.label
            if actionType == .website { website = website.trimmingCharacters(in: .whitespacesAndNewlines) }
            notice = nil
            return true
        } catch { validationMessage = error.localizedDescription; return false }
    }

    private func save() {
        guard !saving, savedConfiguration != nil, apply() else { return }
        do { try draft.configuration.validate() } catch { validationMessage = error.localizedDescription; return }
        if !hasChanges { finishSave(); return }
        let configuration = draft.configuration
        saving = true
        saveTask = Task {
            let result = await Task.detached { Result { try repository.save(configuration) } }.value
            guard !Task.isCancelled else { return }
            saving = false
            switch result {
            case .success:
                savedConfiguration = configuration
                notice = nil
                finishSave()
            case .failure(let error):
                closeAfterSave = false
                previewAfterSave = false
                validationMessage = "Couldn’t save: \(error.localizedDescription) Your edits are still here."
                notice = error.localizedDescription
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

    private func removeChoice() {
        guard let item = selectedItem else { return }
        askingToDiscard = true
        Task {
            let suffix = item.children == nil ? "" : " and every choice inside it"
            let confirmed = await confirmRemoval("Remove “\(item.label)”\(suffix)? This change saves immediately.")
            askingToDiscard = false
            if confirmed { draft.remove(item.id); select(nil) }
        }
    }

    private func tryMenu() {
        previewAfterSave = true
        save()
        if !saving && hasChanges { previewAfterSave = false }
    }

    private func requestClose() -> Bool {
        guard !askingToDiscard else { return false }
        if saving { closeAfterSave = true; return false }
        guard hasChanges else { return true }
        closeAfterSave = true
        save()
        if saving || !hasChanges { return false }
        closeAfterSave = false
        askingToDiscard = true
        Task {
            let name = label.isEmpty ? "This choice" : "“\(label)”"
            let message = "\(name) has changes that haven’t been saved. "
                + (validationMessage ?? "Finish editing to save them automatically.")
            let discard = await confirmDiscard(message)
            askingToDiscard = false
            if discard { closeEditor() }
        }
        return false
    }

}
