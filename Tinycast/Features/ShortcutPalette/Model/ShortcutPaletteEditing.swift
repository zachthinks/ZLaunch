import Foundation

struct ShortcutPaletteEditing {
    var configuration: ShortcutPaletteConfiguration
    private(set) var path: [Int] = []

    var items: [ShortcutPaletteConfiguration.Item] {
        var items = configuration.items
        for index in path {
            guard items.indices.contains(index), let children = items[index].children else { return [] }
            items = children
        }
        return items
    }

    var title: String {
        var titles = ["Root"]
        var items = configuration.items
        for index in path {
            guard items.indices.contains(index) else { break }
            titles.append(items[index].label)
            items = items[index].children ?? []
        }
        return titles.joined(separator: " › ")
    }

    struct Row: Identifiable {
        let id: [String]
        let item: ShortcutPaletteConfiguration.Item
        var parent: [String] { Array(id.dropLast()) }
        var depth: Int { id.count - 1 }
    }

    var keys: [String] {
        var result: [String] = []
        var items = configuration.items
        for index in path {
            guard items.indices.contains(index) else { return result }
            result.append(items[index].id)
            items = items[index].children ?? []
        }
        return result
    }

    func rows(expanded: Set<[String]>) -> [Row] {
        func flatten(_ items: [ShortcutPaletteConfiguration.Item], parent: [String]) -> [Row] {
            items.flatMap { item in
                let id = parent + [item.id]
                let row = Row(id: id, item: item)
                guard let children = item.children, expanded.contains(id) else { return [row] }
                return [row] + flatten(children, parent: id)
            }
        }
        return flatten(configuration.items, parent: [])
    }

    mutating func navigate(to keys: [String]) {
        var nextPath: [Int] = []
        var items = configuration.items
        for key in keys {
            guard let index = items.firstIndex(where: { $0.id == key }),
                let children = items[index].children else { return }
            nextPath.append(index)
            items = children
        }
        path = nextPath
    }

    var nextKey: String? {
        "abcdefghijklmnopqrstuvwxyz".map(String.init).first { key in !items.contains { $0.id == key } }
    }

    mutating func appendActions(_ actions: [(label: String, action: String)]) throws -> [String] {
        var updated = self
        var added: [String] = []
        for action in actions {
            guard let key = updated.nextKey else {
                throw ShortcutPaletteConfiguration.Issue(message: "A menu can contain at most 26 items.")
            }
            guard !action.action.isEmpty else {
                throw ShortcutPaletteConfiguration.Issue(message: "Choose a destination for every action.")
            }
            try updated.update(.init(key: key, label: action.label, action: action.action), replacing: nil)
            added.append(key)
        }
        self = updated
        return added
    }

    mutating func enter(_ id: String) {
        guard let index = items.firstIndex(where: { $0.id == id }), items[index].children != nil else { return }
        path.append(index)
    }

    mutating func back() { if !path.isEmpty { path.removeLast() } }

    mutating func update(_ item: ShortcutPaletteConfiguration.Item, replacing id: String?) throws {
        guard item.key.utf8.count == 1, let byte = item.key.lowercased().utf8.first,
            (97...122).contains(byte), !items.contains(where: { $0.id == item.id && $0.id != id })
        else { throw ShortcutPaletteConfiguration.Issue(message: "Choose an unused letter A–Z in this group.") }
        guard !item.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            item.label.count <= 80
        else { throw ShortcutPaletteConfiguration.Issue(message: "Enter a label of 1–80 characters.") }
        mutate { items in
            if let id, let index = items.firstIndex(where: { $0.id == id }) {
                items[index] = item
            } else { items.append(item) }
        }
    }

    mutating func remove(_ id: String) { mutate { $0.removeAll { $0.id == id } } }

    mutating func move(_ id: String, by offset: Int) {
        mutate { items in
            guard let index = items.firstIndex(where: { $0.id == id }),
                items.indices.contains(index + offset) else { return }
            items.swapAt(index, index + offset)
        }
    }

    private mutating func mutate(_ change: (inout [ShortcutPaletteConfiguration.Item]) -> Void) {
        Self.updateGroup(&configuration.items, path: path[...], change: change)
    }

    private static func updateGroup(
        _ items: inout [ShortcutPaletteConfiguration.Item], path: ArraySlice<Int>,
        change: (inout [ShortcutPaletteConfiguration.Item]) -> Void
    ) {
        guard let index = path.first else { change(&items); return }
        guard items.indices.contains(index), var children = items[index].children else { return }
        updateGroup(&children, path: path.dropFirst(), change: change)
        items[index].children = children
    }
}
