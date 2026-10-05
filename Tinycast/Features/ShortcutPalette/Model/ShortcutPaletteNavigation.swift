import Foundation

struct ShortcutPaletteNavigation: Equatable {
    enum Result: Equatable {
        case ignored, navigated, unmatched, close, action(String)
    }

    let configuration: ShortcutPaletteConfiguration
    private(set) var path: [ShortcutPaletteConfiguration.Item] = []
    private(set) var pendingKey = ""

    private var menuItems: [ShortcutPaletteConfiguration.Item] {
        path.last?.children ?? configuration.items
    }

    var items: [ShortcutPaletteConfiguration.Item] {
        pendingKey.isEmpty ? menuItems : menuItems.filter { $0.id.hasPrefix(pendingKey) }
    }

    var title: String { (["LaunchDeck"] + path.map(\.label)).joined(separator: " › ") }
    var isRoot: Bool { path.isEmpty }

    mutating func select(_ key: String, isRepeat: Bool = false) -> Result {
        guard !isRepeat, key.utf8.count == 1,
            ShortcutPaletteConfiguration.keyIssue(key, among: []) == nil else { return .ignored }
        let candidate = pendingKey + key.lowercased()
        if let item = menuItems.first(where: { $0.id == candidate }) { return activate(item) }
        if menuItems.contains(where: { $0.id.hasPrefix(candidate) }) {
            pendingKey = candidate
            return .navigated
        }
        guard !pendingKey.isEmpty else { return .ignored }
        pendingKey = ""
        return .unmatched
    }

    mutating func choose(_ key: String) -> Result {
        guard let item = items.first(where: { $0.id == key.lowercased() }) else { return .ignored }
        return activate(item)
    }

    private mutating func activate(_ item: ShortcutPaletteConfiguration.Item) -> Result {
        pendingKey = ""
        if item.children != nil {
            path.append(item)
            return .navigated
        }
        return item.action.map(Result.action) ?? .ignored
    }

    mutating func clearPending() -> Result {
        guard !pendingKey.isEmpty else { return .ignored }
        pendingKey = ""
        return .navigated
    }

    mutating func escape() -> Result {
        if !pendingKey.isEmpty { return clearPending() }
        guard configuration.escapeClosesAll != true, !path.isEmpty else { return .close }
        path.removeLast()
        return .navigated
    }
}
