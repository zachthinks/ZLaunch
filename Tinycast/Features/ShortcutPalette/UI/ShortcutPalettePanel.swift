import AppKit

final class ShortcutPalettePanel: NSPanel {
    var onKey: ((NSEvent) -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        onKey?(event)
        return true
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            onKey?(event)
            return
        }
        super.sendEvent(event)
    }
}
