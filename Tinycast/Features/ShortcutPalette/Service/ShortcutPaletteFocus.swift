import AppKit

enum ShortcutPaletteFocus {
    @MainActor static func restore(app: NSRunningApplication?, window: NSWindow?) async -> Bool {
        if let window, window.isVisible {
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
            return window.isKeyWindow
        }
        guard let app, !app.isTerminated else { return true }
        app.activate()
        var settled = false
        for _ in 0..<50 {
            guard !Task.isCancelled else { return false }
            // Workspace changes before AppKit finishes resigning our key window.
            let restored = NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier
                && !NSApp.isActive
            if restored && settled { return true }
            settled = restored
            do { try await Task.sleep(for: .milliseconds(10)) } catch { return false }
        }
        return false
    }
}
