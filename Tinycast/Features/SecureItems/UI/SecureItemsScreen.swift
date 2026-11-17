import SwiftUI

struct SecureItemsScreen: PaletteScreen {
    let coordinator: SecureItemsCoordinator
    let vm: PaletteState

    var rows: [SecureItem] {
        coordinator.items.filter { $0.matches(vm.query) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    var primaryActionTitle: String {
        if coordinator.isShowingSettings { return String(localized: "Done") }
        if vm.mode == .secureItemEditor { return String(localized: "Save") }
        return coordinator.isUnlocked ? String(localized: "Copy") : String(localized: "Unlock")
    }
    var hidesSearchField: Bool { coordinator.isShowingSettings || !coordinator.isUnlocked || vm.mode == .secureItemEditor }
    var actsWithoutRows: Bool { true }
    func hasActions(at selection: Int) -> Bool { !coordinator.isShowingSettings && vm.mode != .secureItemEditor }
    func ownsVerticalKeys(at selection: Int) -> Bool { vm.mode == .secureItemEditor }
    func isPrimaryActionEnabled(at selection: Int) -> Bool {
        guard !coordinator.isBusy else { return false }
        if coordinator.isShowingSettings { return true }
        if vm.mode == .secureItemEditor { return coordinator.draft?.isValid == true }
        return !coordinator.isUnlocked || rows.indices.contains(selection)
    }
    func activate(at selection: Int) {
        if coordinator.isShowingSettings {
            coordinator.isShowingSettings = false
        } else if !coordinator.isUnlocked {
            coordinator.unlock()
        } else if vm.mode == .secureItemEditor {
            coordinator.save()
        } else if rows.indices.contains(selection) {
            coordinator.copy(rows[selection])
        }
    }
    func secondary(at selection: Int) -> Bool {
        if coordinator.isShowingSettings { coordinator.isShowingSettings = false; return true }
        guard !coordinator.isUnlocked, !coordinator.isBusy else { return false }
        coordinator.unlock()
        return true
    }
    func tab(at selection: Int, backwards: Bool) -> Bool {
        if coordinator.isShowingSettings {
            coordinator.settingsField = (coordinator.settingsField + (backwards ? 2 : 1)) % 3
            return true
        }
        guard vm.mode == .secureItemEditor else { return false }
        coordinator.editorField = (coordinator.editorField + (backwards ? 2 : 1)) % 3
        return true
    }
    func perform(_ shortcut: PaletteShortcut, at selection: Int) -> Bool {
        guard coordinator.isUnlocked, !coordinator.isShowingSettings, vm.mode != .secureItemEditor else { return false }
        if shortcut == .newItem { coordinator.edit(nil); return true }
        guard rows.indices.contains(selection) else { return false }
        switch shortcut {
        case .edit: coordinator.edit(rows[selection])
        case .delete: coordinator.delete(rows[selection])
        default: return false
        }
        return true
    }
    func actions(at selection: Int) -> PopoverMenuContent? {
        var actions: [PopoverMenuItem] = []
        if coordinator.isUnlocked, rows.indices.contains(selection) {
            let item = rows[selection]
            actions = [
                PopoverMenuItem(title: String(localized: "Copy"), systemImage: "doc.on.doc", shortcut: "↵") {
                    coordinator.copy(item)
                },
                PopoverMenuItem(title: String(localized: "Edit"), systemImage: "pencil", shortcut: "⌘E") {
                    coordinator.edit(item)
                },
                PopoverMenuItem(title: String(localized: "Reveal / Hide"), systemImage: "eye") {
                    coordinator.reveal(item)
                },
                PopoverMenuItem(title: String(localized: "Delete"), systemImage: "trash", isDestructive: true) {
                    coordinator.delete(item)
                }
            ]
        }
        if coordinator.isUnlocked {
            actions.append(PopoverMenuItem(title: String(localized: "Add Secure Item"), systemImage: "plus", shortcut: "⌘N") {
                coordinator.edit(nil)
            })
            actions.append(PopoverMenuItem(title: String(localized: "Lock"), systemImage: "lock") { coordinator.lock() })
        } else {
            actions.append(PopoverMenuItem(title: String(localized: "Unlock"), systemImage: "lock.open",
                                           isEnabled: !coordinator.isBusy, shortcut: "⌘↵") { coordinator.unlock() })
        }
        actions.append(PopoverMenuItem(title: String(localized: "Secure Items Settings"), systemImage: "gearshape") {
            coordinator.settingsField = 0
            coordinator.isShowingSettings = true
            coordinator.touch()
        })
        return PopoverMenuContent(header: String(localized: "Secure Items"), items: actions)
    }
    func body(selection: Int, scroll: ScrollIntent) -> AnyView {
        AnyView(SecureItemsContent(coordinator: coordinator, vm: vm, rows: rows, selection: selection, scroll: scroll))
    }
}

private struct SecureItemsContent: View {
    let coordinator: SecureItemsCoordinator
    let vm: PaletteState
    let rows: [SecureItem]
    let selection: Int
    let scroll: ScrollIntent
    @Environment(\.metrics) private var metrics

    var body: some View {
        Group {
            if coordinator.isShowingSettings {
                SecureItemsSettingsView(coordinator: coordinator)
            } else if !coordinator.isUnlocked {
                VStack(spacing: metrics.spacing.lg) {
                    SymbolImage(name: "lock.shield", size: metrics.size.resultRowIcon)
                    Text("Secure Items").font(metrics.typography.panelTitle)
                    Text("Stored only on this Mac, outside ZLaunch backups.")
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Button("Unlock") { coordinator.unlock() }
                        .buttonStyle(.borderedProminent).controlSize(.large).disabled(coordinator.isBusy)
                    if coordinator.isBusy { ProgressView().controlSize(.small) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.mode == .secureItemEditor {
                SecureItemEditor().environment(coordinator)
            } else {
                list
            }
        }
        .onChange(of: vm.query) { coordinator.touch() }
        .onChange(of: vm.selection) { coordinator.revealedID = nil; coordinator.touch() }
    }

    private var list: some View {
        VStack(spacing: metrics.spacing.md) {
            HStack {
                Button("Add Secure Item") { coordinator.edit(nil) }
                Spacer()
                Button("Lock") { coordinator.lock() }
            }
            .padding(.horizontal, metrics.spacing.xl)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: metrics.spacing.xs) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { index, item in
                            VStack(alignment: .leading, spacing: metrics.spacing.sm) {
                                HStack {
                                    SymbolImage(name: item.value.hasPrefix("https://") || item.value.hasPrefix("http://") ? "link"
                                                : item.value.contains("\n") ? "note.text" : "key",
                                                size: metrics.size.resultRowIcon)
                                    Text(item.name).lineLimit(1)
                                    Spacer()
                                }
                                if !item.tags.isEmpty {
                                    HStack(spacing: metrics.spacing.xs) {
                                        ForEach(item.tags.prefix(3), id: \.self) { tag in
                                            Text(verbatim: tag).font(metrics.typography.rowTrailing).lineLimit(1)
                                                .padding(.horizontal, metrics.spacing.sm)
                                                .padding(.vertical, metrics.spacing.xxs)
                                                .background(Theme.Colors.controlSurface, in: Capsule())
                                        }
                                        if item.tags.count > 3 {
                                            Text(verbatim: "+\(item.tags.count - 3)")
                                                .font(metrics.typography.rowTrailing)
                                        }
                                    }.foregroundStyle(Theme.Colors.textSecondary)
                                }
                                if coordinator.revealedID == item.id {
                                    Text(verbatim: item.value).font(.system(.body, design: .monospaced))
                                        .lineLimit(8)
                                }
                            }
                            .padding(metrics.spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(index == selection ? Theme.Colors.selection : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.row))
                            .contentShape(Rectangle())
                            .onTapGesture { vm.selection = index; coordinator.touch() }
                            .simultaneousGesture(TapGesture(count: 2).onEnded { coordinator.copy(item) })
                            .id(item.id.uuidString)
                        }
                        if rows.isEmpty {
                            VStack(spacing: metrics.spacing.md) {
                                SymbolImage(name: "lock.rectangle.stack", size: metrics.size.resultRowIcon)
                                if vm.query.isEmpty {
                                    Text("Your secure items, close at hand").font(metrics.typography.rowTitle)
                                } else {
                                    Text("No secure items found").font(metrics.typography.rowTitle)
                                }
                                if vm.query.isEmpty {
                                    Text("Save an API key, link, or private note to get started.")
                                        .foregroundStyle(Theme.Colors.textSecondary)
                                    Button("Add Secure Item") { coordinator.edit(nil) }.buttonStyle(.borderedProminent)
                                }
                            }.padding(metrics.spacing.xl)
                        }
                    }
                    .padding(.horizontal, metrics.spacing.md)
                }
                .scrollFollowsSelection(scroll, row: rows.indices.contains(selection) ? rows[selection].id.uuidString : nil,
                                        atOrigin: selection == 0, proxy: proxy)
            }
            .edgeDissolve()
            Text("Search names and tags. Values stay hidden until revealed.")
                .font(metrics.typography.rowTrailing).foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(.vertical, metrics.spacing.md)
        .disabled(coordinator.isBusy)
    }
}

private struct SecureItemsSettingsView: View {
    @FocusState private var focusedField: Int?
    let coordinator: SecureItemsCoordinator
    @Environment(AppSettings.self) private var settings
    @Environment(\.metrics) private var metrics

    var body: some View {
        @Bindable var settings = settings
        VStack(alignment: .leading, spacing: metrics.spacing.xl) {
            Text("Secure Items Settings").font(metrics.typography.panelTitle)
            VStack(alignment: .leading, spacing: metrics.spacing.sm) {
                Picker("Lock after inactivity", selection: $settings.secureItemsIdleSeconds) {
                    ForEach(SecureItemsTiming.idleOptions, id: \.self) { seconds in
                        Group {
                            if seconds < 60 {
                                Text("\(seconds) seconds")
                            } else if seconds == 60 {
                                Text("1 minute")
                            } else {
                                Text("\(seconds / 60) minutes")
                            }
                        }.tag(seconds)
                    }
                }
                .focused($focusedField, equals: 0)
                Text("Using Secure Items restarts this timer. Quitting ZLaunch always locks it.")
                    .font(metrics.typography.rowTrailing).foregroundStyle(Theme.Colors.textSecondary)
            }
            VStack(alignment: .leading, spacing: metrics.spacing.sm) {
                Picker("Clear clipboard after", selection: $settings.secureItemsClipboardSeconds) {
                    ForEach(SecureItemsTiming.clipboardOptions, id: \.self) { seconds in
                        Group {
                            if seconds < 60 {
                                Text("\(seconds) seconds")
                            } else if seconds == 60 {
                                Text("1 minute")
                            } else {
                                Text("\(seconds / 60) minutes")
                            }
                        }.tag(seconds)
                    }
                }
                .focused($focusedField, equals: 1)
                Text("Applies to the next copy. Anything you copy afterward is left alone.")
                    .font(metrics.typography.rowTrailing).foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
            HStack {
                Spacer()
                Button("Done") { coordinator.isShowingSettings = false }
                    .buttonStyle(.borderedProminent).focused($focusedField, equals: 2)
            }
        }
        .padding(metrics.spacing.xl)
        .onAppear {
            settings.secureItemsIdleSeconds = SecureItemsTiming.idleSeconds(settings.secureItemsIdleSeconds)
            settings.secureItemsClipboardSeconds = SecureItemsTiming.clipboardSeconds(settings.secureItemsClipboardSeconds)
            focusedField = coordinator.settingsField
        }
        .onChange(of: coordinator.settingsField) { focusedField = coordinator.settingsField }
        .onChange(of: focusedField) { if let focusedField { coordinator.settingsField = focusedField } }
    }
}
