import Foundation

struct ShortcutPaletteConfiguration: Codable, Equatable, Sendable {
    struct Item: Codable, Equatable, Identifiable, Sendable {
        let key: String
        let label: String
        var action: String?
        var children: [Item]?

        var id: String { key.lowercased() }
    }

    enum DisplayMode: String, Codable, CaseIterable, Sendable { case list, grid, floatingTiles }

    enum TileSize: String, Codable, CaseIterable, Sendable { case small, medium, large }

    var tileSize: TileSize?
    var displayMode: DisplayMode?
    var items: [Item]
    var escapeClosesAll: Bool?
    var repeatTriggerResets: Bool?

    static func websiteURL(for action: String) -> URL? {
        guard action.hasPrefix("website:"),
            let parts = URLComponents(string: String(action.dropFirst("website:".count))),
            let scheme = parts.scheme?.lowercased(), ["https", "http"].contains(scheme),
            let host = parts.host, !host.isEmpty, parts.user == nil, parts.password == nil
        else { return nil }
        return parts.url
    }

    func validate() throws {
        try Self.validate(items, depth: 0)
    }

    private static func validate(_ items: [Item], depth: Int) throws {
        guard depth < 6, !items.isEmpty, items.count <= 26 else {
            throw Issue(message: "Use 1–26 choices per submenu and at most six levels.")
        }
        var keys: Set<String> = []
        for item in items {
            guard item.key.utf8.count == 1,
                let byte = item.key.lowercased().utf8.first, (97...122).contains(byte),
                keys.insert(item.id).inserted
            else { throw Issue(message: "Each choice needs a unique letter A–Z within its submenu.") }
            guard !item.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                item.label.count <= 80
            else { throw Issue(message: "Choice labels must contain 1–80 characters.") }
            if let children = item.children {
                guard item.action == nil else {
                    throw Issue(message: "\(item.label): use children or an action, never both.")
                }
                guard !children.isEmpty else {
                    throw Issue(message: "\(item.label) is empty. Add an action to this submenu, or remove it.")
                }
                try validate(children, depth: depth + 1)
            } else {
                guard let action = item.action, !action.isEmpty else {
                    throw Issue(message: "\(item.label): choose an action or add children.")
                }
                if action.hasPrefix("website:"), websiteURL(for: action) == nil {
                    throw Issue(message: "Enter a complete http:// or https:// website address without embedded credentials.")
                }
            }
        }
    }

    struct Issue: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static let starter = Self(items: [
        Item(key: "d", label: "Developer", children: [
            Item(key: "f", label: "Search Files", action: "command:search-files"),
            Item(key: "l", label: "AI", children: [
                Item(key: "c", label: "AI Chat", action: "command:ai-chat-window"),
                Item(key: "q", label: "Quick AI", action: "command:ai-chat")
            ])
        ]),
        Item(key: "c", label: "Clipboard", children: [
            Item(key: "h", label: "History", action: "command:clipboard-history"),
            Item(key: "e", label: "Emoji & Symbols", action: "command:search-emoji")
        ]),
        Item(key: "n", label: "Notes", children: [
            Item(key: "o", label: "Open Notes", action: "command:show-notes"),
            Item(key: "n", label: "New Note", action: "command:create-note")
        ]),
        Item(key: "s", label: "ZLaunch Settings", action: "command:settings")
    ])
}
