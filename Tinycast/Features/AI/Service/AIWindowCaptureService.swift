import AppKit
import ScreenCaptureKit

@MainActor
enum AIWindowCaptureService {
    struct Target: Sendable {
        let windowID: CGWindowID
        let processID: pid_t
    }

    enum Failure: LocalizedError {
        case permission, missingWindow, unreadable

        var errorDescription: String? {
            switch self {
            case .permission:
                "Allow ZLaunch in System Settings → Privacy & Security → Screen & System Audio Recording, "
                    + "then try again. If macOS asks, quit and reopen ZLaunch."
            case .missingWindow:
                "That window is no longer available. Bring it to the front and try again."
            case .unreadable:
                "That window could not be captured as an image."
            }
        }
    }

    static func target(app: NSRunningApplication?, ownWindow: NSWindow?) -> Target? {
        if let window = ownWindow, window.isVisible, window.canBecomeMain, window.windowNumber > 0 {
            return Target(windowID: CGWindowID(window.windowNumber), processID: ProcessInfo.processInfo.processIdentifier)
        }
        guard let app,
            let windows = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        else { return nil }
        return target(processID: app.processIdentifier, windows: windows)
    }

    static func target(processID: pid_t, windows: [[String: Any]]) -> Target? {
        for window in windows {
            guard window[kCGWindowOwnerPID as String] as? pid_t == processID,
                window[kCGWindowLayer as String] as? Int == 0,
                (window[kCGWindowAlpha as String] as? Double ?? 0) > 0,
                let id = window[kCGWindowNumber as String] as? CGWindowID
            else { continue }
            return Target(windowID: id, processID: processID)
        }
        return nil
    }

    static func capture(_ target: Target) async throws -> ChatAttachmentReader.Staged {
        try Task.checkCancellation()
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            throw Failure.permission
        }
        guard isVisible(target) else { throw Failure.missingWindow }
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        try Task.checkCancellation()
        guard let window = content.windows.first(where: {
            $0.windowID == target.windowID && $0.owningApplication?.processID == target.processID
        }) else { throw Failure.missingWindow }
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let configuration = SCScreenshotConfiguration()
        let scale = min(CGFloat(filter.pointPixelScale), 1_568 / max(window.frame.width, window.frame.height, 1))
        configuration.width = max(1, Int((window.frame.width * scale).rounded()))
        configuration.height = max(1, Int((window.frame.height * scale).rounded()))
        configuration.showsCursor = false
        configuration.ignoreShadows = true
        configuration.includeChildWindows = false
        configuration.dynamicRange = .sdr
        let output = try await SCScreenshotManager.captureScreenshot(contentFilter: filter, configuration: configuration)
        try Task.checkCancellation()
        guard isVisible(target) else { throw Failure.missingWindow }
        guard let image = output.sdrImage else { throw Failure.unreadable }
        let name = [window.owningApplication?.applicationName, window.title]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " — ")
        return try await Task.detached(priority: .userInitiated) {
            guard let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]),
                case .staged(let item) = ChatAttachmentReader.image(data)
            else { throw Failure.unreadable }
            return ChatAttachmentReader.Staged(
                payload: item.payload, name: name.isEmpty ? "Window Screenshot" : name, preview: item.preview)
        }.value
    }

    private static func isVisible(_ target: Target) -> Bool {
        guard let windows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        else { return false }
        return windows.contains {
            $0[kCGWindowNumber as String] as? CGWindowID == target.windowID
                && $0[kCGWindowOwnerPID as String] as? pid_t == target.processID
                && ($0[kCGWindowAlpha as String] as? Double ?? 0) > 0
        }
    }

    static func isPermissionFailure(_ error: Error) -> Bool {
        if (error as? Failure) == .permission { return true }
        let failure = error as NSError
        return failure.domain == SCStreamErrorDomain && failure.code == SCStreamError.Code.userDeclined.rawValue
    }

    static func openPermissionSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
        else { return }
        NSWorkspace.shared.open(url)
    }
}
