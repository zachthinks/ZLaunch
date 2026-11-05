import AppKit
@preconcurrency import ApplicationServices

enum MouseWindowAccess {
    static let timeout: Float = 0.1

    static func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &result) == .success
        else { return nil }
        return result
    }

    static func frame(_ window: AXUIElement) -> CGRect? {
        guard let position = value(window, kAXPositionAttribute),
            let size = value(window, kAXSizeAttribute),
            CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID()
        else { return nil }
        var point = CGPoint.zero, dimensions = CGSize.zero
        guard AXValueGetValue(position as! AXValue, .cgPoint, &point),
            AXValueGetValue(size as! AXValue, .cgSize, &dimensions),
            point.x.isFinite, point.y.isFinite, dimensions.width.isFinite,
            dimensions.height.isFinite, dimensions.width > 0, dimensions.height > 0
        else { return nil }
        return CGRect(origin: point, size: dimensions)
    }

    static func target(at point: CGPoint, excluded: Set<String>) -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, timeout)
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(system, Float(point.x), Float(point.y), &element)
            == .success else { return nil }
        for _ in 0..<20 {
            guard let current = element else { return nil }
            AXUIElementSetMessagingTimeout(current, timeout)
            if value(current, kAXRoleAttribute) as? String == kAXWindowRole {
                var pid: pid_t = 0
                guard AXUIElementGetPid(current, &pid) == .success,
                    pid != ProcessInfo.processInfo.processIdentifier,
                    let app = NSRunningApplication(processIdentifier: pid),
                    let id = app.bundleIdentifier, !excluded.contains(id),
                    value(current, kAXMinimizedAttribute) as? Bool != true,
                    value(current, "AXFullScreen") as? Bool != true else { return nil }
                return current
            }
            guard let parent = value(current, kAXParentAttribute),
                CFGetTypeID(parent) == AXUIElementGetTypeID() else { return nil }
            element = (parent as! AXUIElement)
        }
        return nil
    }

    static func settable(_ window: AXUIElement, _ attribute: String) -> Bool {
        var result = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(window, attribute as CFString, &result) == .success
            && result.boolValue
    }

    static func move(_ window: AXUIElement, to origin: CGPoint) -> Bool {
        var point = origin
        guard let value = AXValueCreate(.cgPoint, &point) else { return false }
        return AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value) == .success
    }

    static func resize(_ window: AXUIElement, to size: CGSize) -> Bool {
        var dimensions = size
        guard let value = AXValueCreate(.cgSize, &dimensions) else { return false }
        return AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value) == .success
    }

    static func application(_ window: AXUIElement) -> AXUIElement? {
        var pid: pid_t = 0
        guard AXUIElementGetPid(window, &pid) == .success else { return nil }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, timeout)
        return app
    }

    static func focus(_ window: AXUIElement, app: AXUIElement) {
        AXUIElementSetAttributeValue(app, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(app, kAXFocusedWindowAttribute as CFString, window)
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
    }

    static func neighbors(excluding frame: CGRect, apps: Set<String>) -> [CGRect] {
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID) as? [[String: Any]] ?? []
        return list.compactMap { info in
            guard info[kCGWindowLayer as String] as? Int == 0,
                let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                pid != ProcessInfo.processInfo.processIdentifier,
                let id = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier,
                !apps.contains(id), let bounds = info[kCGWindowBounds as String] as? [String: CGFloat],
                let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary), rect != frame,
                rect.width > 1, rect.height > 1 else { return nil }
            return rect
        }
    }
}
