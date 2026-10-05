import Foundation

struct ShortcutPaletteMenuDraft: Equatable {
    struct Node: Identifiable, Equatable {
        let id: UUID
        var key: String
        var label: String
        var action: String?
        var children: [Node]?

        init(_ item: ShortcutPaletteConfiguration.Item) {
            id = UUID()
            key = item.key
            label = item.label
            action = item.action
            children = item.children?.map(Node.init)
        }

        var item: ShortcutPaletteConfiguration.Item {
            .init(key: key.lowercased(), label: label, action: action, children: children?.map(\.item))
        }
    }

    struct Row: Identifiable {
        let node: Node
        let depth: Int
        let position: Int
        let count: Int
        var id: UUID { node.id }
    }

    var appearance: ShortcutPaletteConfiguration
    var nodes: [Node]

    init(configuration: ShortcutPaletteConfiguration) {
        appearance = configuration
        nodes = configuration.items.map(Node.init)
    }

    var configuration: ShortcutPaletteConfiguration {
        var result = appearance
        result.items = nodes.map(\.item)
        return result
    }

    func rows(expanded: Set<UUID>) -> [Row] {
        func flatten(_ nodes: [Node], depth: Int) -> [Row] {
            nodes.enumerated().flatMap { index, node in
                let row = Row(node: node, depth: depth, position: index, count: nodes.count)
                guard let children = node.children, expanded.contains(node.id) else { return [row] }
                return [row] + flatten(children, depth: depth + 1)
            }
        }
        return flatten(nodes, depth: 0)
    }

    func node(_ id: UUID) -> Node? {
        func find(_ nodes: [Node]) -> Node? {
            for node in nodes {
                if node.id == id { return node }
                if let children = node.children, let found = find(children) { return found }
            }
            return nil
        }
        return find(nodes)
    }

    mutating func edit(_ id: UUID, _ change: (inout Node) -> Void) {
        Self.mutate(&nodes, id: id) { siblings, index in change(&siblings[index]) }
    }

    mutating func move(_ id: UUID, by offset: Int) {
        Self.mutate(&nodes, id: id) { siblings, index in
            guard siblings.indices.contains(index + offset) else { return }
            siblings.swapAt(index, index + offset)
        }
    }

    mutating func remove(_ id: UUID) {
        Self.mutate(&nodes, id: id) { siblings, index in siblings.remove(at: index) }
    }

    mutating func append(_ items: [(label: String, action: String?)], to parent: UUID?) throws -> [UUID] {
        var siblings = parent.flatMap { node($0)?.children } ?? nodes
        if let parent, node(parent)?.children == nil {
            throw ShortcutPaletteConfiguration.Issue(message: "This submenu is no longer available.")
        }
        var added: [UUID] = []
        for item in items {
            guard siblings.count < ShortcutPaletteConfiguration.maximumItems,
                let key = ShortcutPaletteConfiguration.nextKey(among: siblings.map(\.key)) else {
                throw ShortcutPaletteConfiguration.Issue(message: "This menu has no available shortcut keys.")
            }
            let node = Node(.init(key: key, label: item.label, action: item.action,
                                  children: item.action == nil ? [] : nil))
            siblings.append(node)
            added.append(node.id)
        }
        if let parent { edit(parent) { $0.children = siblings } } else { nodes = siblings }
        return added
    }

    func issue(for id: UUID) -> String? {
        func find(_ nodes: [Node]) -> String? {
            for node in nodes {
                if node.id == id {
                    if let issue = ShortcutPaletteConfiguration.keyIssue(
                        node.key, among: nodes.filter { $0.id != id }.map(\.key)) { return issue }
                    if node.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || node.label.count > 80 {
                        return "Enter a name of 1–80 characters."
                    }
                    if let children = node.children { return children.isEmpty ? "Add an action to this submenu." : nil }
                    guard let action = node.action, !action.isEmpty else { return "Choose an action." }
                    if action.hasPrefix("website:"), ShortcutPaletteConfiguration.websiteURL(for: action) == nil {
                        return "Enter a complete HTTP or HTTPS website address."
                    }
                    return nil
                }
                if let children = node.children, let issue = find(children) { return issue }
            }
            return nil
        }
        return find(nodes)
    }

    private static func mutate(_ nodes: inout [Node], id: UUID, change: (inout [Node], Int) -> Void) {
        if let index = nodes.firstIndex(where: { $0.id == id }) { change(&nodes, index); return }
        for index in nodes.indices {
            if var children = nodes[index].children {
                mutate(&children, id: id, change: change)
                nodes[index].children = children
            }
        }
    }
}
