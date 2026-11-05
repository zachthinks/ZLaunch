import AppKit
@preconcurrency import ApplicationServices

@main
@MainActor
struct MouseWindowLiveTest {
    static var targetWindow: NSWindow?

    static func main() throws {
        if CommandLine.arguments.contains("--target") {
            let app = NSApplication.shared
            app.setActivationPolicy(.regular)
            let window = NSWindow(contentRect: CGRect(x: 150, y: 150, width: 600, height: 450),
                styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            window.title = "Disposable Mouse QA"
            window.minSize = CGSize(width: 300, height: 220)
            let label = NSTextField(labelWithString: "Synthetic window for mouse-control validation")
            label.frame = CGRect(x: 30, y: 100, width: 500, height: 30)
            window.contentView?.addSubview(label)
            targetWindow = window
            window.makeKeyAndOrderFront(nil)
            app.activate()
            app.run()
            return
        }
        guard AXIsProcessTrusted(),
            let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.zachthinks.mouse-qa").first
        else { print("FAIL: launch the disposable target with Accessibility available"); exit(2) }
        let application = AXUIElementCreateApplication(app.processIdentifier)
        guard let windows = MouseWindowAccess.value(application, kAXWindowsAttribute) as? [AXUIElement],
            let window = windows.first else { print("FAIL: target has no AX window"); exit(2) }
        let monitor = MouseWindowMonitor()
        let flags = Int(CGEventFlags.maskAlternate.rawValue)
        var options = MouseWindowSession.Options()
        options.snap = false
        var failures = 0
        for (name, action, fraction, delta) in [
            ("move", MouseWindowGeometry.Action.move, CGPoint(x: 0.5, y: 0.5), CGPoint(x: 150, y: 80)),
            ("resize-bottom-right", .resize, CGPoint(x: 0.8, y: 0.8), CGPoint(x: 120, y: 80)),
            ("resize-top-left", .resize, CGPoint(x: 0.2, y: 0.2), CGPoint(x: -100, y: -70)),
            ("minimum-size", .resize, CGPoint(x: 0.2, y: 0.2), CGPoint(x: 420, y: 340)),
            ("move-keyboard", .move, CGPoint(x: 0.5, y: 0.5), CGPoint(x: 150, y: 80)),
            ("move-both", .move, CGPoint(x: 0.5, y: 0.5), CGPoint(x: 150, y: 80)),
            ("resize-top-right", .resize, CGPoint(x: 0.8, y: 0.2), CGPoint(x: 100, y: -70)),
            ("resize-bottom-left", .resize, CGPoint(x: 0.2, y: 0.8), CGPoint(x: -100, y: 70))
        ] {
            let keyboard = name == "move-keyboard"
            let both = name == "move-both"
            monitor.configure(move: MouseWindowTrigger(encoded: [flags, keyboard ? 2 : -1,
                    keyboard ? 0 : both ? 3 : 1]),
                resize: MouseWindowTrigger(encoded: [flags, -1, 2]), options: options)
            guard monitor.isListening else { print("FAIL: no event tap"); exit(2) }
            _ = MouseWindowAccess.move(window, to: CGPoint(x: 150, y: 150))
            _ = MouseWindowAccess.resize(window, to: CGSize(width: 600, height: 450))
            pump(0.15)
            guard let initial = MouseWindowAccess.frame(window),
                initial == CGRect(x: 150, y: 150, width: 600, height: 450)
            else { print("FAIL: target reset did not settle"); exit(2) }
            let start = CGPoint(x: initial.minX + initial.width * fraction.x,
                y: initial.minY + initial.height * fraction.y)
            let zone = MouseWindowGeometry.zone(at: start, in: initial)
            post(.mouseMoved, at: start)
            let button: CGMouseButton = action == .move ? .left : .right
            key(58, down: true)
            pump(0.02)
            if keyboard { key(2, down: true) } else {
                post(action == .move ? .leftMouseDown : .rightMouseDown, at: start, button: button)
                if both { post(.rightMouseDown, at: start, button: .right) }
            }
            var samples: [[String: Double]] = []
            let began = ProcessInfo.processInfo.systemUptime
            var previous = initial
            var changes = 0
            for index in 1...120 {
                let progress = Double(index) / 120
                let point = CGPoint(x: start.x + delta.x * progress, y: start.y + delta.y * progress)
                post(keyboard ? .mouseMoved : action == .move ? .leftMouseDragged : .rightMouseDragged,
                    at: point, button: button)
                pump(1.0 / 120)
                if index % 30 == 0 { _ = monitor.healthCheck() }
                if let actual = MouseWindowAccess.frame(window) {
                    if actual != previous { changes += 1 }
                    previous = actual
                    let requested = MouseWindowGeometry.frame(initial: initial, pointerStart: start,
                        pointer: point, action: action, zone: zone, neighbors: [])
                    samples.append(["time": ProcessInfo.processInfo.systemUptime - began,
                        "error": abs(actual.minX - requested.minX) + abs(actual.minY - requested.minY)
                            + abs(actual.width - requested.width) + abs(actual.height - requested.height)])
                }
            }
            let end = CGPoint(x: start.x + delta.x, y: start.y + delta.y)
            if keyboard { key(2, down: false) } else {
                post(action == .move ? .leftMouseUp : .rightMouseUp, at: end, button: button)
                if both { post(.rightMouseUp, at: end, button: .right) }
            }
            key(58, down: false)
            pump(0.4)
            let final = MouseWindowAccess.frame(window) ?? .zero
            let requested = MouseWindowGeometry.frame(initial: initial, pointerStart: start,
                pointer: CGPoint(x: start.x + delta.x, y: start.y + delta.y),
                action: action, zone: zone, neighbors: [])
            let expected = name == "minimum-size"
                ? CGRect(x: initial.maxX - 300, y: initial.maxY - 220, width: 300, height: 220)
                : requested
            let error = abs(final.minX - expected.minX) + abs(final.minY - expected.minY)
                + abs(final.width - expected.width) + abs(final.height - expected.height)
            if error > 2 || changes == 0 { failures += 1 }
            let result: [String: Any] = ["case": name, "changes": changes, "finalError": error,
                "elapsed": ProcessInfo.processInfo.systemUptime - began,
                "meanTrackingError": samples.map { $0["error"]! }.reduce(0, +) / Double(samples.count),
                "frame": [final.minX, final.minY, final.width, final.height]]
            post(.mouseMoved, at: CGPoint(x: end.x + 50, y: end.y + 50))
            pump(0.1)
            if MouseWindowAccess.frame(window) != final { failures += 1 }
            let data = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
            guard let line = String(bytes: data, encoding: .utf8) else { exit(2) }
            print(line)
        }
        monitor.shutdown()
        pump(0.3)
        print("LIVE_FAILURES=\(failures)")
        exit(failures == 0 ? 0 : 1)
    }

    static func key(_ code: CGKeyCode, down: Bool) {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)!
        event.flags = code == 58 && !down ? [] : .maskAlternate
        event.post(tap: .cghidEventTap)
    }

    static func post(_ type: CGEventType, at point: CGPoint, button: CGMouseButton = .left) {
        let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: button)!
        event.flags = .maskAlternate
        event.post(tap: .cghidEventTap)
    }

    static func pump(_ seconds: TimeInterval) {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: seconds))
    }
}
