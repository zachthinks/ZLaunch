import SwiftUI

struct ShortcutPaletteMenuEditor: View {
    @Binding var draft: ShortcutPaletteMenuDraft
    @Binding var expanded: Set<UUID>
    @Binding var selectedMenu: UUID?
    @Binding var choosingAction: UUID?
    let actions: [AppEntry]
    let validationMessage: String?
    let onAddActions: (UUID?) -> Void
    let onAddSubmenu: (UUID?) -> Void
    let onRemove: (UUID) -> Void

    private var title: String { selectedMenu.flatMap { draft.node($0)?.label } ?? "Main menu" }
    private var children: [ShortcutPaletteMenuDraft.Node] {
        selectedMenu.flatMap { draft.node($0)?.children } ?? draft.nodes
    }
    private var menuPath: [ShortcutPaletteMenuDraft.Node] {
        func find(_ nodes: [ShortcutPaletteMenuDraft.Node]) -> [ShortcutPaletteMenuDraft.Node]? {
            for node in nodes {
                if node.id == selectedMenu { return [node] }
                if let children = node.children, let path = find(children) { return [node] + path }
            }
            return nil
        }
        return find(draft.nodes) ?? []
    }
    private var depth: Int { menuPath.count - 1 }

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            sidebar.frame(width: 220)
            contents.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onChange(of: selectedMenu) { choosingAction = nil }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Menus").font(.headline).padding(.horizontal, 8)
            ScrollView {
                VStack(spacing: 2) {
                    navigationRow(id: nil, label: "Main menu", depth: 0, expandable: false)
                    ForEach(draft.rows(expanded: expanded).filter { $0.node.children != nil }) { row in
                        navigationRow(id: row.id, label: row.node.label, depth: row.depth,
                                      expandable: row.node.children?.contains { $0.children != nil } == true)
                    }
                }
            }
            Text("Select a menu to edit its items.").font(.caption).foregroundStyle(.secondary)
                .padding(.horizontal, 8)
        }
        .padding(12)
        .background(Theme.Colors.controlSurface, in: .rect(cornerRadius: 12))
    }

    private func navigationRow(id: UUID?, label: String, depth: Int, expandable: Bool) -> some View {
        HStack(spacing: 4) {
            if let id, expandable {
                Button {
                    if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) }
                } label: {
                    Image(systemName: expanded.contains(id) ? "chevron.down" : "chevron.right")
                        .font(.caption).frame(width: 16, height: 28)
                }
                .buttonStyle(.plain).accessibilityLabel("Expand or collapse \(label)")
            } else { Color.clear.frame(width: 16, height: 1) }
            Button {
                selectedMenu = id
                if let id { expanded.insert(id) }
            } label: {
                Label(label, systemImage: id == nil ? "list.bullet" : "folder")
                    .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 9)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, CGFloat(depth) * 14).padding(.trailing, 8)
        .background(selectedMenu == id ? Theme.Colors.selection : Color.clear, in: .rect(cornerRadius: 6))
    }

    private var contents: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.title3.bold())
                    if !menuPath.isEmpty {
                        Text((["Main menu"] + menuPath.map(\.label)).joined(separator: " › "))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text("\(children.count) items · Edit keys and names below.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Add Submenu", systemImage: "folder.badge.plus") { onAddSubmenu(selectedMenu) }
                    .disabled(children.count >= 26 || depth >= 4)
                Button("Add Actions…", systemImage: "plus") { onAddActions(selectedMenu) }
                    .disabled(children.count >= 26)
            }
            HStack(spacing: 12) {
                Text("Key").frame(width: 48, alignment: .leading)
                Text("Name").frame(maxWidth: .infinity, alignment: .leading)
                Text("Action").frame(maxWidth: .infinity, alignment: .leading)
                Color.clear.frame(width: 28, height: 1)
            }
            .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 8)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(children.enumerated()), id: \.element.id) { index, node in
                        VStack(alignment: .leading, spacing: 8) {
                            itemRow(node, index: index)
                            if let issue = draft.issue(for: node.id) {
                                Text(issue).font(.callout).foregroundStyle(Theme.Colors.warning)
                            }
                            if choosingAction == node.id { destinationPicker(node) }
                        }
                        .padding(.horizontal, 8).padding(.vertical, 10)
                        Divider()
                    }
                    if children.isEmpty {
                        ContentUnavailableView("This menu is empty", systemImage: "folder",
                            description: Text("Use Add Actions to choose several actions at once."))
                    }
                }
            }
            if let validationMessage {
                Label(validationMessage, systemImage: "exclamationmark.circle")
                    .font(.callout).foregroundStyle(Theme.Colors.warning)
            }
        }
        .padding(16)
        .background(Theme.Colors.cardFill, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.Colors.border))
    }

    private func itemRow(_ node: ShortcutPaletteMenuDraft.Node, index: Int) -> some View {
        HStack(spacing: 12) {
            TextField("A–Z", text: Binding(
                get: { draft.node(node.id)?.key ?? "" }, set: { value in draft.edit(node.id) { $0.key = value } }))
                .frame(width: 48).accessibilityLabel("Key for \(node.label)")
            TextField("Name", text: Binding(
                get: { draft.node(node.id)?.label ?? "" }, set: { value in draft.edit(node.id) { $0.label = value } }))
                .frame(minWidth: 100, maxWidth: .infinity).accessibilityLabel("Name for \(node.label)")
            Button {
                if node.children != nil {
                    selectedMenu = node.id
                    expanded.insert(node.id)
                } else { choosingAction = choosingAction == node.id ? nil : node.id }
            } label: {
                HStack {
                    if let children = node.children {
                        Label("Submenu · \(children.count) items", systemImage: "folder")
                    } else { Text(actionName(node.action)).lineLimit(1) }
                    Spacer(minLength: 4)
                    Image(systemName: node.children == nil ? "chevron.down" : "chevron.right").font(.caption)
                }
            }
            .frame(minWidth: 130, maxWidth: .infinity)
            .accessibilityLabel(node.children == nil ? "Change action for \(node.label)" : "Open submenu \(node.label)")
            Menu {
                Button("Move Up", systemImage: "arrow.up") { draft.move(node.id, by: -1) }.disabled(index == 0)
                Button("Move Down", systemImage: "arrow.down") { draft.move(node.id, by: 1) }
                    .disabled(index == children.count - 1)
                Divider()
                Button("Remove", systemImage: "trash", role: .destructive) { onRemove(node.id) }
            } label: { Image(systemName: "ellipsis") }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width: 28)
            .accessibilityLabel("Options for \(node.label)")
        }
        .textFieldStyle(.roundedBorder)
    }

    private func destinationPicker(_ node: ShortcutPaletteMenuDraft.Node) -> some View {
        ShortcutPaletteDestinationPicker(actions: actions, current: node.action ?? "") { action in
            draft.edit(node.id) {
                $0.action = action
                if $0.label == "New Website", let host = ShortcutPaletteConfiguration.websiteURL(for: action)?.host {
                    $0.label = host
                }
            }
            choosingAction = nil
        } onCancel: { choosingAction = nil }
        .id(node.id)
    }

    private func actionName(_ action: String?) -> String {
        guard let action, !action.isEmpty else { return "Choose action…" }
        if action.hasPrefix("website:") {
            let address = String(action.dropFirst(8))
            return address.isEmpty ? "Enter website…" : address
        }
        return actions.first { $0.id == action }?.name ?? "Unavailable: \(action)"
    }
}
