import SwiftUI

struct MouseWindowShortcutRecorder: NSViewRepresentable {
    let encoded: [Int]
    let onChange: ([Int]) -> Void
    let onRecording: (Bool) -> Void

    func makeNSView(context: Context) -> Control {
        let control = Control()
        control.bezelStyle = .rounded
        control.setButtonType(.momentaryPushIn)
        control.controlSize = .small
        return control
    }

    func updateNSView(_ view: Control, context: Context) {
        view.encoded = encoded
        view.onChange = onChange
        view.onRecording = onRecording
        view.refresh()
    }

    static func dismantleNSView(_ view: Control, coordinator: ()) { view.finish(nil) }

    final class Control: NSButton {
        var encoded: [Int] = []
        var onChange: (([Int]) -> Void)?
        var onRecording: ((Bool) -> Void)?
        private var recording = false
        private var held = 0

        override var acceptsFirstResponder: Bool { true }

        override func mouseDown(with event: NSEvent) { begin() }
        override func performClick(_ sender: Any?) { begin() }

        private func begin() {
            if recording { finish(nil); return }
            recording = true
            held = 0
            onRecording?(true)
            window?.makeFirstResponder(self)
            title = String(localized: "Press shortcut")
        }

        override func flagsChanged(with event: NSEvent) {
            guard recording else { return }
            let flags = Int(event.modifierFlags.rawValue) & MouseWindowTrigger.modifierMask
            if flags == 0, held != 0 { finish([held, -1, buttons]); return }
            held |= flags
            title = symbols(held)
        }

        override func keyDown(with event: NSEvent) {
            guard recording else { super.keyDown(with: event); return }
            let flags = Int(event.modifierFlags.rawValue) & MouseWindowTrigger.modifierMask
            if flags == 0 && event.keyCode == 53 { finish(nil); return }
            if flags == 0 && (event.keyCode == 51 || event.keyCode == 117) { finish([]); return }
            let value = [flags, Int(event.keyCode), buttons]
            guard MouseWindowTrigger(encoded: value) != nil else { NSSound.beep(); return }
            finish(value)
        }

        override func resignFirstResponder() -> Bool {
            finish(nil)
            return super.resignFirstResponder()
        }

        func finish(_ value: [Int]?) {
            guard recording else { return }
            recording = false
            if let value { onChange?(value) }
            onRecording?(false)
            refresh()
        }

        func refresh() {
            guard !recording else { return }
            guard let trigger = MouseWindowTrigger(encoded: encoded),
                trigger.modifiers != 0 || trigger.keyCode != nil
            else { title = String(localized: "Record Shortcut"); return }
            if let code = trigger.keyCode {
                title = KeyShortcut(carbonKeyCode: code,
                    carbonModifiers: KeyShortcut.carbonModifiers(from:
                        NSEvent.ModifierFlags(rawValue: UInt(trigger.modifiers)))).keycaps.joined()
            } else { title = symbols(trigger.modifiers) }
        }

        private var buttons: Int { encoded.count == 3 ? encoded[2] : 0 }

        private func symbols(_ flags: Int) -> String {
            let symbols: [(Int, String)] = [
                (1 << 23, "🌐"), (1 << 18, "⌃"), (1 << 19, "⌥"), (1 << 17, "⇧"), (1 << 20, "⌘")
            ]
            return symbols.filter { flags & $0.0 != 0 }.map(\.1).joined()
        }
    }
}
