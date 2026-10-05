import CoreGraphics
import Foundation

@main
struct ShortcutPaletteTests {
    static func main() throws {
        for count in [1, 4, 8, 12, 20, 26] {
            for mode in ShortcutPaletteConfiguration.DisplayMode.allCases {
                for size in ShortcutPaletteConfiguration.TileSize.allCases {
                    for screen in [CGSize(width: 1440, height: 900), CGSize(width: 640, height: 480)] {
                        let layout = ShortcutPaletteLayout(mode: mode, size: size, itemCount: count,
                            isRoot: false, availableSize: screen)
                        assert(layout.width <= screen.width - 32 && layout.height <= screen.height - 32)
                        assert(layout.columns >= 1 && layout.rows * layout.columns >= count)
                        if mode != .list {
                            assert(layout.tileEdge >= 128)
                            assert(CGFloat(layout.columns) * layout.tileEdge
                                + CGFloat(layout.columns - 1) * 16 <= layout.width - 48)
                        }
                    }
                }
            }
        }
        let floatingLayout = ShortcutPaletteLayout(mode: .floatingTiles, size: .medium,
            itemCount: 4, isRoot: true, availableSize: CGSize(width: 1440, height: 900))
        let screen = CGRect(x: -1440, y: 200, width: 1440, height: 900)
        let positioned = floatingLayout.floatingFrame(in: screen, topMarginFraction: 0.18)
        assert(positioned.midX == screen.midX)
        assert(abs(screen.maxY - positioned.maxY - screen.height * 0.18) < 0.001)
        let tall = ShortcutPaletteLayout(mode: .floatingTiles, size: .large,
            itemCount: 26, isRoot: false, availableSize: screen.size)
        assert(screen.contains(tall.floatingFrame(in: screen, topMarginFraction: 0.18)))
        let wrapped = ShortcutPaletteLayout(mode: .floatingTiles, size: .large,
            itemCount: 20, isRoot: true, availableSize: CGSize(width: 640, height: 480))
        assert(wrapped.needsScrolling && wrapped.columns == 2)
        assert(ShortcutPaletteConfiguration.websiteURL(for: "website:https://example.com/path?q=test")?.host == "example.com")
        for invalid in ["website:example.com", "website:javascript:alert(1)", "website:file:///tmp/a",
                        "website:https://user:secret@example.com", "website:https://"] {
            assert(ShortcutPaletteConfiguration.websiteURL(for: invalid) == nil)
            do {
                try ShortcutPaletteConfiguration(items: [.init(key: "w", label: "Web", action: invalid)]).validate()
                fatalError("Invalid website accepted")
            } catch {}
        }
        let config = ShortcutPaletteConfiguration.starter
        try config.validate()
        var nav = ShortcutPaletteNavigation(configuration: config)
        assert(nav.select("?") == .ignored)
        assert(nav.select("dd") == .ignored)
        assert(nav.select("D", isRepeat: true) == .ignored)
        assert(nav.isRoot)
        assert(nav.select("D") == .navigated)
        assert(nav.title == "LaunchDeck › Developer")
        assert(nav.select("l") == .navigated)
        assert(nav.select("c") == .action("command:ai-chat-window"))
        assert(nav.escape() == .navigated)
        assert(nav.title == "LaunchDeck › Developer")
        assert(nav.escape() == .navigated)
        assert(nav.isRoot)
        assert(nav.escape() == .close)
        assert(ShortcutPaletteNavigation(configuration: config).isRoot)
        let badJSON = [
            #"{"items":[]}"#,
            #"{"items":[{"key":"a","label":"A","action":"one"},{"key":"A","label":"B","action":"two"}]}"#,
            #"{"items":[{"key":"ab","label":"A","action":"one"}]}"#,
            #"{"items":[{"key":"é","label":"A","action":"one"}]}"#,
            #"{"items":[{"key":"a","label":" ","action":"one"}]}"#,
            #"{"items":[{"key":"a","label":"A"}]}"#,
            #"{"items":[{"key":"a","label":"A","children":[],"action":"one"}]}"#
        ]
        for json in badJSON {
            do {
                try JSONDecoder().decode(ShortcutPaletteConfiguration.self, from: Data(json.utf8)).validate()
                fatalError("Invalid configuration accepted")
            } catch {}
        }
        var editing = ShortcutPaletteEditing(configuration: config)
        editing.enter("d")
        assert(editing.title == "Root › Developer")
        try editing.update(.init(key: "t", label: "Tools", children: []), replacing: nil)
        editing.enter("t")
        try editing.update(.init(key: "s", label: "Settings", action: "command:settings"), replacing: nil)
        try editing.configuration.validate()
        assert(editing.items.first?.label == "Settings")
        do {
            try editing.update(.init(key: "S", label: "Duplicate", action: "command:settings"), replacing: nil)
            fatalError("Duplicate editor key accepted")
        } catch {}
        try editing.update(.init(key: "p", label: "Preferences", action: "command:settings"), replacing: "s")
        assert(editing.items.first?.key == "p")
        editing.back()
        editing.move("t", by: -1)
        assert(editing.items[1].id == "t")
        editing.enter("t")
        assert(editing.items.first?.key == "p")
        editing.remove("p")
        do { try editing.configuration.validate(); fatalError("Empty group saved") } catch {}
        editing.back()
        editing.remove("t")
        editing.back()
        assert(editing.configuration == config)
        let collapsedRows = editing.rows(expanded: [])
        assert(collapsedRows.count == config.items.count)
        let expandedRows = editing.rows(expanded: [["d"], ["d", "l"], ["c"]])
        assert(expandedRows.contains { $0.id == ["d", "l", "c"] && $0.depth == 2 })
        assert(expandedRows.contains { $0.id == ["c", "h"] && $0.parent == ["c"] })
        assert(Set(expandedRows.map(\.id)).count == expandedRows.count)
        editing.navigate(to: ["d", "l"])
        assert(editing.keys == ["d", "l"] && editing.items.first?.id == "c")
        editing.navigate(to: ["missing"])
        assert(editing.keys == ["d", "l"])
        editing.navigate(to: ["c", "c"])
        assert(editing.keys == ["d", "l"])
        editing.navigate(to: [])
        editing.move("d", by: 1)
        editing.navigate(to: ["d", "l"])
        assert(editing.keys == ["d", "l"])
        editing.navigate(to: [])
        editing.move("d", by: -1)
        assert(editing.configuration == config)
        var batch = ShortcutPaletteEditing(configuration: config)
        batch.navigate(to: ["c"])
        let batchKeys = try batch.appendActions([("Left Half", "window:left"), ("Maximize", "window:maximize")])
        assert(batchKeys == ["a", "b"])
        assert(batch.items.suffix(2).map(\.label) == ["Left Half", "Maximize"])
        assert(batch.configuration.items[0] == config.items[0])
        let beforeOverflow = batch.configuration
        do {
            _ = try batch.appendActions(Array(repeating: ("Extra", "command:extra"), count: 26))
            fatalError("Oversized batch accepted")
        } catch {}
        assert(batch.configuration == beforeOverflow)
        do {
            _ = try batch.appendActions([("Valid", "command:valid"), ("Invalid", "")])
            fatalError("Invalid batch accepted")
        } catch {}
        assert(batch.configuration == beforeOverflow)
        assert(config.displayMode == nil)
        var closeAll = config
        closeAll.displayMode = .grid
        closeAll.escapeClosesAll = true
        closeAll.repeatTriggerResets = true
        var closeNav = ShortcutPaletteNavigation(configuration: closeAll)
        assert(closeNav.select("d") == .navigated)
        assert(closeNav.escape() == .close)
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = ShortcutPaletteRepository(directory: directory)
        let initial = try repository.load()
        assert(initial == config)
        let custom = #"{"items":[{"key":"z","label":"My action","action":"custom:missing"}]}"#
        try Data(custom.utf8).write(to: repository.configurationURL)
        let loaded = try repository.load()
        var customNav = ShortcutPaletteNavigation(configuration: loaded)
        assert(customNav.select("z") == .action("custom:missing"))
        let preserved = try String(contentsOf: repository.configurationURL, encoding: .utf8)
        assert(preserved == custom)
        try Data("broken".utf8).write(to: repository.configurationURL)
        do { _ = try repository.load(); fatalError("Malformed JSON accepted") } catch {}
        let broken = try String(contentsOf: repository.configurationURL, encoding: .utf8)
        assert(broken == "broken")
        try repository.exportActions([.init(label: "Settings", action: "command:settings")])
        let actions = try JSONDecoder().decode([ShortcutPaletteRepository.Action].self,
            from: Data(contentsOf: repository.actionsURL))
        assert(actions.first?.action == "command:settings")
        try repository.save(closeAll)
        let reloaded = try repository.load()
        assert(reloaded.displayMode == .grid)
        assert(reloaded.escapeClosesAll == true && reloaded.repeatTriggerResets == true)
        do {
            try repository.save(.init(items: []))
            fatalError("Invalid configuration saved")
        } catch {}
        let preservedAfterRejection = try repository.load()
        assert(preservedAfterRejection == closeAll)
        var incomplete = closeAll
        incomplete.items.append(.init(key: "u", label: "Unfinished", children: []))
        do { try repository.save(incomplete); fatalError("Incomplete edit replaced saved menu") } catch {}
        let stillSaved = try repository.load()
        assert(stillSaved == closeAll)
        let blockedDirectory = directory.appending(path: "not-a-directory")
        try Data("sentinel".utf8).write(to: blockedDirectory)
        do {
            try ShortcutPaletteRepository(directory: blockedDirectory).save(config)
            fatalError("Write failure incorrectly reported success")
        } catch {}
        let sentinel = try String(contentsOf: blockedDirectory, encoding: .utf8)
        assert(sentinel == "sentinel")
        var floating = closeAll
        floating.displayMode = .floatingTiles
        floating.tileSize = .large
        try repository.save(floating)
        let floatingReloaded = try repository.load()
        assert(floatingReloaded.displayMode == .floatingTiles && floatingReloaded.tileSize == .large)
        try repository.save(closeAll)
        let afterInvalidSave = try repository.load()
        assert(afterInvalidSave == closeAll)
        print("Shortcut palette: navigation, validation, persistence, and action dispatch decisions passed")
    }
}
