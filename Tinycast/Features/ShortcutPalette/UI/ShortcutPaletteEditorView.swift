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
    @State private var selection: String?
    @State private var key = ""
    @State private var label = ""
    @State private var action = ""
    @State private var search = ""
    @State private var website = ""
    @State private var actionType = ActionType.command

    private enum ActionType: String, CaseIterable, Identifiable {
        case application = "Open an app"
        case website = "Open a website"
        case command = "Run a ZLaunch command"
        case appAction = "Use an app action"
        case workflow = "Run a shortcut or workflow"
        var id: Self { self }
        var searchPrompt: String {
            switch self {
            case .application: "Search apps…"
            case .website: "Website address"
            case .command: "Search ZLaunch commands…"
            case .appAction: "Search app actions…"
            case .workflow: "Search shortcuts and workflows…"
            }
        }

        func includes(_ kind: AppEntry.Kind) -> Bool {
            switch self {
            case .application: kind == .application
            case .website: false
            case .workflow: kind == .appleShortcut || kind == .customCommand
            case .appAction: kind == .extensionCommand || kind == .quicklink
            case .command:
                ![.application, .appleShortcut, .customCommand, .extensionCommand, .quicklink].contains(kind)
            }
        }
    }
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
        .onAppear { registerCloseHandler { requestClose() } }
        .task {
            let result = await Task.detached { Result { try repository.load() } }.value
            guard !Task.isCancelled else { return }
            switch result {
            case .success(let configuration):
                draft = ShortcutPaletteEditing(configuration: configuration)
                savedConfiguration = configuration
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

    private var menuEditor: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    if !draft.path.isEmpty {
                        Button { if apply() { draft.back(); select(nil) } } label: {
                            Image(systemName: "arrow.left")
                        }.help("Back to parent group")
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(draft.path.isEmpty ? "Your menu" : draft.title.components(separatedBy: " › ").last ?? "Group")
                            .font(.headline)
                        Text(draft.path.isEmpty ? "Start here when LaunchDeck opens" : "Your menu" + draft.title.dropFirst(4))
                            .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
                List(draft.items, selection: Binding(
                    get: { selection }, set: { value in if apply() { select(value) } })) { item in
                    HStack(spacing: 10) {
                        Text(item.key.uppercased()).font(.body.monospaced().weight(.semibold))
                            .frame(width: 30, height: 30)
                            .background(Theme.Colors.windowSurface, in: .rect(cornerRadius: 6))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.label).lineLimit(1)
                            Text(item.children.map { "Group · \($0.count) choices" } ?? "Action")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        if item.children != nil {
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4).tag(item.id)
                }
                .scrollContentBackground(.hidden)
                HStack {
                    Button("Add Group", systemImage: "folder.badge.plus") { add(group: true) }
                    Button("Add Action", systemImage: "plus") { add(group: false) }
                }
                .disabled(draft.nextKey == nil)
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
            .padding(16).frame(width: 300)
            .background(Theme.Colors.cardFill, in: .rect(cornerRadius: 12))
            detail
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
                    Text(selectedItem.children == nil ? "Set up an action" : "Set up a group")
                        .font(.title3.weight(.semibold))
                    Text(selectedItem.children == nil ? "Choose what happens when you press this key."
                         : "A group opens another set of keys.")
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
                    Text("\(selectedItem.children?.count ?? 0) choices in this group")
                        .foregroundStyle(.secondary)
                    Button("Edit Group Choices", systemImage: "arrow.right") {
                        guard apply() else { return }
                        draft.enter(key.lowercased()); select(nil)
                    }
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
                        TextField(actionType.searchPrompt, text: $search).textFieldStyle(.roundedBorder)
                        if filteredActions.isEmpty {
                            Text(emptyActionMessage).font(.callout).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        } else {
                            List(filteredActions, selection: $action) { entry in
                                HStack(spacing: 10) {
                                    AppIconView(app: entry, pointSize: 24)
                                        .frame(width: 24, height: 24).accessibilityHidden(true)
                                    VStack(alignment: .leading) {
                                        Text(entry.name)
                                        Text(entry.kind.descriptor.label).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                .tag(entry.id)
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
                     ? "Use Add Action to choose an app, website, or command for this group."
                     : "Select a key on the left to customize it. Add actions to launch things, or groups to organize more keys.")
                    .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if let validationMessage { validation(validationMessage) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var filteredActions: [AppEntry] {
        actions.filter { actionType.includes($0.kind)
            && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
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

    private func add(group: Bool) {
        guard apply() else { return }
        guard let next = draft.nextKey else { return }
        let item = ShortcutPaletteConfiguration.Item(
            key: next, label: group ? "New Group" : "New Action",
            action: group ? nil : "", children: group ? [] : nil)
        do {
            try draft.update(item, replacing: nil)
            select(item.id)
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
