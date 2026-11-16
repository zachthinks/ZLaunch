import SwiftUI

struct SecureItemsScreen: PaletteScreen {
    let coordinator: SecureItemsCoordinator
    let vm: PaletteState

    var rows: [SecureItem] {
        coordinator.items.filter { vm.query.isEmpty || $0.name.localizedStandardContains(vm.query) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    var primaryActionTitle: String {
        if vm.mode == .secureItemEditor { return String(localized: "Save") }
        return coordinator.isUnlocked ? String(localized: "Copy") : String(localized: "Unlock")
    }
    var hidesSearchField: Bool { !coordinator.isUnlocked || vm.mode == .secureItemEditor }
    var actsWithoutRows: Bool { true }
    func hasActions(at selection: Int) -> Bool { coordinator.isUnlocked && vm.mode != .secureItemEditor }
    func ownsVerticalKeys(at selection: Int) -> Bool { vm.mode == .secureItemEditor }
    func isPrimaryActionEnabled(at selection: Int) -> Bool {
        guard !coordinator.isBusy else { return false }
        if vm.mode == .secureItemEditor { return coordinator.draft?.isValid == true }
        return !coordinator.isUnlocked || rows.indices.contains(selection)
    }
    func activate(at selection: Int) {
        if !coordinator.isUnlocked {
            coordinator.unlock()
        } else if vm.mode == .secureItemEditor {
            coordinator.save()
        } else if rows.indices.contains(selection) {
            coordinator.copy(rows[selection])
        }
    }
    func secondary(at selection: Int) -> Bool { false }
    func perform(_ shortcut: PaletteShortcut, at selection: Int) -> Bool {
        guard coordinator.isUnlocked, vm.mode != .secureItemEditor else { return false }
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
        guard coordinator.isUnlocked else { return nil }
        var actions: [PopoverMenuItem] = []
        if rows.indices.contains(selection) {
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
        actions.append(PopoverMenuItem(title: String(localized: "Add Secure Item"), systemImage: "plus", shortcut: "⌘N") {
            coordinator.edit(nil)
        })
        actions.append(PopoverMenuItem(title: String(localized: "Lock"), systemImage: "lock") { coordinator.lock() })
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
            if !coordinator.isUnlocked {
                VStack(spacing: metrics.spacing.lg) {
                    SymbolImage(name: "lock.shield", size: metrics.size.resultRowIcon)
                    Text("Secure Items").font(metrics.typography.rowTitle)
                    Text("Stored only on this Mac, outside ZLaunch backups.")
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Button("Unlock") { coordinator.unlock() }.disabled(coordinator.isBusy)
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
                                    SymbolImage(name: "lock", size: metrics.size.resultRowIcon)
                                    Text(item.name).lineLimit(1)
                                    Spacer()
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
                        if rows.isEmpty { Text("No secure items found").foregroundStyle(Theme.Colors.textSecondary) }
                    }
                    .padding(.horizontal, metrics.spacing.md)
                }
                .scrollFollowsSelection(scroll, row: rows.indices.contains(selection) ? rows[selection].id.uuidString : nil,
                                        atOrigin: selection == 0, proxy: proxy)
            }
            .edgeDissolve()
            Text("Copies clear after 30 seconds unless replaced.")
                .font(metrics.typography.rowTrailing).foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(.vertical, metrics.spacing.md)
        .disabled(coordinator.isBusy)
    }
}
