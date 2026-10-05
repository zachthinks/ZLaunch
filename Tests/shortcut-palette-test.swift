import CoreGraphics
import Foundation

@main
struct ShortcutPaletteTests {
    static func main() throws {
        for count in [1, 4, 8, 12, 20, 26, 68] {
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
        assert(ShortcutPaletteConfiguration.maximumItems == 68)
        for byte in 33...126 {
            let key = String(UnicodeScalar(byte)!)
            let printable = ShortcutPaletteConfiguration(items: [.init(key: key, label: "Key", action: "test")])
            try printable.validate()
            var input = ShortcutPaletteNavigation(configuration: printable)
            assert(input.select(key) == .action("test"))
        }
        for reserved in [" ", "\t", "\n", "\u{1B}", "\u{7F}", "\u{F700}", "é", "😀"] {
            assert(ShortcutPaletteConfiguration.keyIssue(reserved, among: []) != nil)
        }
        assert(ShortcutPaletteConfiguration.keyIssue("+", among: ["="]) == nil)
        assert(ShortcutPaletteConfiguration.keyIssue("A", among: ["a"]) != nil)
        let allKeys = ShortcutPaletteConfiguration.availableKeys.map(String.init)
        var fullMenu = ShortcutPaletteMenuDraft(configuration: .init(items: []))
        _ = try fullMenu.append(allKeys.map { ($0, Optional("test")) }, to: nil)
        try fullMenu.configuration.validate()
        assert(fullMenu.nodes.map(\.key) == allKeys)
        let sequences = ShortcutPaletteConfiguration(items: [
            .init(key: "tl", label: "Top Left", action: "left"),
            .init(key: "tr", label: "Top Right", action: "right"),
            .init(key: "+", label: "Plus", action: "plus"),
            .init(key: "++", label: "Conflict", action: "conflict")
        ])
        do { try sequences.validate(); fatalError("Prefix conflict accepted") } catch {}
        assert(ShortcutPaletteConfiguration.keyIssue("T", among: ["tl"]) != nil)
        assert(ShortcutPaletteConfiguration.keyIssue("tl", among: ["T"]) != nil)
        assert(ShortcutPaletteConfiguration.keyIssue("tl", among: ["tr"]) == nil)
        var sequenceConfig = sequences
        sequenceConfig.items.removeLast()
        try sequenceConfig.validate()
        var sequenceNav = ShortcutPaletteNavigation(configuration: sequenceConfig)
        assert(sequenceNav.select("T") == .navigated && sequenceNav.pendingKey == "t")
        assert(sequenceNav.items.map(\.key) == ["tl", "tr"])
        assert(sequenceNav.select("l", isRepeat: true) == .ignored && sequenceNav.pendingKey == "t")
        assert(sequenceNav.select("L") == .action("left") && sequenceNav.pendingKey.isEmpty)
        assert(sequenceNav.select("t") == .navigated)
        assert(sequenceNav.select("+") == .unmatched && sequenceNav.pendingKey.isEmpty)
        assert(sequenceNav.select("+") == .action("plus"))
        assert(sequenceNav.select("t") == .navigated)
        assert(sequenceNav.escape() == .navigated && sequenceNav.isRoot)
        assert(sequenceNav.select("t") == .navigated)
        assert(sequenceNav.clearPending() == .navigated)
        assert(sequenceNav.choose("tr") == .action("right"))
        assert(sequenceNav.select("t") == .navigated)
        assert(sequenceNav.choose("tl") == .action("left"))
        var sequenceDraft = ShortcutPaletteMenuDraft(configuration: sequenceConfig)
        let sequenceID = sequenceDraft.nodes[0].id
        sequenceDraft.edit(sequenceID) { $0.key = "t" }
        assert(sequenceDraft.issue(for: sequenceID)?.contains("starts with the other") == true)
        sequenceDraft.edit(sequenceID) { $0.key = "tl" }
        assert(sequenceDraft.issue(for: sequenceID) == nil)
        sequenceConfig.escapeClosesAll = true
        var clearFirst = ShortcutPaletteNavigation(configuration: sequenceConfig)
        assert(clearFirst.select("t") == .navigated)
        assert(clearFirst.escape() == .navigated)
        assert(clearFirst.escape() == .close)
        let symbolSequence = ShortcutPaletteConfiguration(items: [.init(key: "+=", label: "Symbols", action: "symbols")])
        try symbolSequence.validate()
        var symbolNav = ShortcutPaletteNavigation(configuration: symbolSequence)
        assert(symbolNav.select("+") == .navigated)
        assert(symbolNav.select("=") == .action("symbols"))
        let nestedSequences = ShortcutPaletteConfiguration(items: [
            .init(key: "t", label: "Top", children: sequenceConfig.items)
        ])
        try nestedSequences.validate()
        var nestedNav = ShortcutPaletteNavigation(configuration: nestedSequences)
        assert(nestedNav.select("t") == .navigated)
        assert(nestedNav.select("t") == .navigated)
        assert(nestedNav.select("r") == .action("right"))
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
            #"{"items":[{"key":"abc","label":"A","action":"one"}]}"#,
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
            _ = try batch.appendActions(Array(repeating: ("Extra", "command:extra"),
                                              count: ShortcutPaletteConfiguration.maximumItems))
            fatalError("Oversized batch accepted")
        } catch {}
        assert(batch.configuration == beforeOverflow)
        do {
            _ = try batch.appendActions([("Valid", "command:valid"), ("Invalid", "")])
            fatalError("Invalid batch accepted")
        } catch {}
        assert(batch.configuration == beforeOverflow)
        var inline = ShortcutPaletteMenuDraft(configuration: config)
        assert(inline.configuration == config)
        let developer = inline.nodes[0].id
        let child = inline.nodes[0].children![0].id
        inline.edit(child) { $0.key = "l" }
        assert(inline.issue(for: child) != nil)
        do { try inline.configuration.validate(); fatalError("Duplicate inline key saved") } catch {}
        inline.edit(child) { $0.key = "x"; $0.label = "Renamed" }
        assert(inline.node(child)?.label == "Renamed" && inline.issue(for: child) == nil)
        inline.move(child, by: 1)
        assert(inline.node(developer)?.children?.last?.id == child)
        inline.edit(developer) { $0.key = "z" }
        assert(inline.node(child)?.key == "x")
        let addedInline = try inline.append([("One", "command:one"), ("Two", "command:two")], to: developer)
        assert(addedInline.count == 2 && inline.node(developer)?.children?.count == 4)
        inline.remove(addedInline[0])
        assert(inline.node(addedInline[0]) == nil)
        let beforeInlineOverflow = inline
        do {
            _ = try inline.append(Array(repeating: ("Overflow", Optional("command:test")),
                                        count: ShortcutPaletteConfiguration.maximumItems), to: developer)
            fatalError("Oversized inline batch accepted")
        } catch {}
        assert(inline == beforeInlineOverflow)
        try inline.configuration.validate()
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
        floating.displayMode = .liquidGlass
        let glassDraft = ShortcutPaletteMenuDraft(configuration: floating)
        try repository.save(glassDraft.configuration)
        let glassReloaded = try repository.load()
        assert(glassReloaded == floating)
        assert(glassReloaded.displayMode?.isFloating == true)
        try repository.save(closeAll)
        let afterInvalidSave = try repository.load()
        assert(afterInvalidSave == closeAll)
        print("Shortcut palette: navigation, validation, persistence, and action dispatch decisions passed")
    }
}
