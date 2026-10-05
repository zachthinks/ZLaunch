import Foundation

struct ShortcutPaletteNavigation: Equatable {
    enum Result: Equatable {
        case ignored, navigated, close, action(String)
    }

    let configuration: ShortcutPaletteConfiguration
    private(set) var path: [ShortcutPaletteConfiguration.Item] = []

    var items: [ShortcutPaletteConfiguration.Item] {
        path.last?.children ?? configuration.items
    }

    var title: String { (["LaunchDeck"] + path.map(\.label)).joined(separator: " › ") }
    var isRoot: Bool { path.isEmpty }

    mutating func select(_ key: String, isRepeat: Bool = false) -> Result {
        guard !isRepeat, let item = items.first(where: { $0.id == key.lowercased() }) else {
            return .ignored
        }
        if item.children != nil {
            path.append(item)
            return .navigated
        }
        return item.action.map(Result.action) ?? .ignored
    }

    mutating func escape() -> Result {
        guard configuration.escapeClosesAll != true, !path.isEmpty else { return .close }
        path.removeLast()
        return .navigated
    }
}
