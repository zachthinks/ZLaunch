import AppKit
@preconcurrency import ApplicationServices

// The lock owns pending input; the shared serial queue exclusively owns AX state.
final class MouseWindowSession: @unchecked Sendable {
    struct Options: Equatable, Sendable {
        var quadrants = true
        var focus = true
        var snap = true
        var voiceOver = false
        var excluded: Set<String> = ["com.apple.notificationcenterui"]
    }

    static let replayMarker: Int64 = 0x5A4C4D4F555345
    private let queue: DispatchQueue
    private let lock = NSLock()
    private let action: MouseWindowGeometry.Action
    private let start: CGPoint
    private let options: Options
    private let replayEvent: @Sendable (CGEvent) -> Void
    private var pending: CGPoint?
    private var buffered: [CGEvent] = []
    private var ready = false
    private var failed = false
    private var cancelled = false
    private var finished = false
    private var scheduled = false
    private var window: AXUIElement?
    private var app: AXUIElement?
    private var restoreEnhancedUI = false
    private var initial: CGRect = .zero
    private var last: CGRect = .zero
    private var zone: MouseWindowGeometry.Zone = .bottomRight
    private var neighbors: [CGRect] = []
    private var focused = false

    init(
        action: MouseWindowGeometry.Action, point: CGPoint, options: Options, queue: DispatchQueue,
        replay: @escaping @Sendable (CGEvent) -> Void = MouseWindowSession.replay
    ) {
        self.action = action
        start = point
        self.options = options
        self.queue = queue
        replayEvent = replay
    }

    func begin() { queue.async { self.prepare() } }

    func capture(_ event: CGEvent) {
        lock.lock(); defer { lock.unlock() }
        if failed { replayEvent(event); return }
        if !ready, let copy = event.copy() {
            if Self.isMotion(event), let last = buffered.last, Self.isMotion(last) {
                buffered[buffered.count - 1] = copy
            } else { buffered.append(copy) }
            if buffered.count >= 256 {
                cancelled = true
                failLocked()
            }
        }
    }

    func update(_ point: CGPoint) {
        lock.lock()
        guard !finished && !cancelled && !failed else { lock.unlock(); return }
        pending = point
        let enqueue = !scheduled
        scheduled = true
        lock.unlock()
        if enqueue { queue.async { self.drain() } }
    }

    func end(cancel: Bool) {
        lock.lock()
        cancelled = cancelled || cancel
        finished = true
        if cancelled { pending = nil }
        lock.unlock()
        queue.async {
            self.drain()
            self.restore()
        }
    }

    private var isCancelled: Bool {
        lock.lock(); defer { lock.unlock() }
        return cancelled
    }

    private func prepare() {
        guard !isCancelled,
            let target = MouseWindowAccess.target(at: start, excluded: options.excluded),
            let frame = MouseWindowAccess.frame(target),
            MouseWindowAccess.settable(target, kAXPositionAttribute),
            action == .move || MouseWindowAccess.settable(target, kAXSizeAttribute)
        else { fail(); return }
        guard !isCancelled else { fail(); return }
        window = target
        initial = frame
        last = frame
        zone = options.quadrants ? MouseWindowGeometry.zone(at: start, in: frame) : .bottomRight
        neighbors = options.snap ? MouseWindowAccess.neighbors(excluding: frame, apps: options.excluded) : []
        app = MouseWindowAccess.application(target)
        guard !isCancelled else { fail(); return }
        if !options.voiceOver, let app,
            MouseWindowAccess.value(app, "AXEnhancedUserInterface") as? Bool == true
        {
            restoreEnhancedUI = AXUIElementSetAttributeValue(app,
                "AXEnhancedUserInterface" as CFString, kCFBooleanFalse) == .success
        }
        lock.lock()
        if cancelled {
            failLocked()
        } else {
            ready = true
            buffered.removeAll()
        }
        lock.unlock()
    }

    private func fail() {
        lock.lock(); defer { lock.unlock() }
        failLocked()
    }

    private func failLocked() {
        failed = true
        for event in buffered { replayEvent(event) }
        buffered.removeAll()
    }

    private func drain() {
        while true {
            lock.lock()
            let point = cancelled ? nil : pending
            pending = nil
            if point == nil { scheduled = false }
            lock.unlock()
            guard let point else { return }
            guard let window, !isCancelled else { continue }
            if !focused, options.focus, let app {
                MouseWindowAccess.focus(window, app: app)
                focused = true
            }
            let frame = MouseWindowGeometry.frame(initial: initial, pointerStart: start,
                pointer: point, action: action, zone: zone, neighbors: neighbors)
            guard !isCancelled else { continue }
            let moved = abs(frame.minX - last.minX) >= 0.5 || abs(frame.minY - last.minY) >= 0.5
            let resized = abs(frame.width - last.width) >= 0.5 || abs(frame.height - last.height) >= 0.5
            if moved && !MouseWindowAccess.move(window, to: frame.origin) { continue }
            guard !isCancelled else { continue }
            if action == .resize && (moved || resized) {
                guard MouseWindowAccess.resize(window, to: frame.size) else {
                    if !isCancelled { _ = MouseWindowAccess.move(window, to: last.origin) }
                    continue
                }
                guard !isCancelled, let actual = MouseWindowAccess.frame(window) else { continue }
                let corrected = MouseWindowGeometry.corrected(requested: frame, actual: actual,
                    initial: initial, zone: zone)
                if corrected.origin != actual.origin, !isCancelled {
                    if MouseWindowAccess.move(window, to: corrected.origin) { last = corrected } else { last = actual }
                } else { last = actual }
            } else { last = frame }
        }
    }

    private func restore() {
        if restoreEnhancedUI, let app {
            AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
        }
        restoreEnhancedUI = false
        window = nil
        app = nil
    }

    static func replay(_ event: CGEvent) {
        guard let copy = event.copy() else { return }
        copy.setIntegerValueField(.eventSourceUserData, value: replayMarker)
        copy.post(tap: .cghidEventTap)
    }

    private static func isMotion(_ event: CGEvent) -> Bool {
        [.mouseMoved, .leftMouseDragged, .rightMouseDragged].contains(event.type)
    }
}
