import AppKit

private func mouseWindowCallback(
    proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let monitor = Unmanaged<MouseWindowMonitor>.fromOpaque(userInfo).takeUnretainedValue()
    return monitor.receive(type, event) ? nil : Unmanaged.passUnretained(event)
}

// Callback state is lock-protected; installation and disposal run on the main actor.
final class MouseWindowMonitor: @unchecked Sendable {
    private let lock = NSRecursiveLock()
    private let worker = DispatchQueue(label: "zlaunch.mouse-window", qos: .userInteractive)
    private var input = MouseWindowInput()
    private var move: MouseWindowTrigger?
    private var resize: MouseWindowTrigger?
    private var options = MouseWindowSession.Options()
    private var session: MouseWindowSession?
    private var pendingDown: CGEvent?
    private var enabled = false
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    var isListening: Bool {
        lock.lock(); defer { lock.unlock() }
        return tap != nil
    }

    @MainActor
    func configure(move: MouseWindowTrigger?, resize: MouseWindowTrigger?, options: MouseWindowSession.Options) {
        lock.lock(); defer { lock.unlock() }
        if self.move != move || self.resize != resize || self.options != options {
            cancel()
        }
        self.move = move
        self.resize = resize
        self.options = options
        enabled = move != nil || resize != nil
        if enabled { install() } else if !input.isDraining { uninstall() }
    }

    @MainActor
    func healthCheck() -> Bool {
        lock.lock(); defer { lock.unlock() }
        let heldKeys = Set(input.trackedKeys.filter {
            CGEventSource.keyState(.hidSystemState, key: CGKeyCode($0))
        })
        let heldButtons = (CGEventSource.buttonState(.hidSystemState, button: .left) ? 1 : 0)
            | (CGEventSource.buttonState(.hidSystemState, button: .right) ? 2 : 0)
        if input.reconcile(heldKeys: heldKeys, heldButtons: heldButtons) { cancel() }
        if let active = input.active {
            let trigger = active == .move ? move : resize
            let flags = Int(CGEventSource.flagsState(.combinedSessionState).rawValue)
            if trigger?.matches(modifiers: flags, keys: heldKeys, buttons: heldButtons) != true { cancel() }
        }
        if !enabled && !input.isDraining { uninstall() }
        if enabled { install() }
        return tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? !enabled
    }

    func cancel() {
        lock.lock(); defer { lock.unlock() }
        _ = input.handle(.cancel, modifiers: 0, move: nil, resize: nil)
        if let pendingDown { MouseWindowSession.replay(pendingDown) }
        pendingDown = nil
        session?.end(cancel: true)
    }

    @MainActor
    func shutdown() {
        lock.lock(); defer { lock.unlock() }
        cancel()
        enabled = false
        uninstall()
    }

    func finishWrites() async {
        await withCheckedContinuation { continuation in
            worker.async { continuation.resume() }
        }
    }

    fileprivate func receive(_ type: CGEventType, _ event: CGEvent) -> Bool {
        if event.getIntegerValueField(.eventSourceUserData) == MouseWindowSession.replayMarker { return false }
        lock.lock(); defer { lock.unlock() }
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            cancel()
            return false
        }
        guard let kind = Self.kind(type, event) else { return false }
        let flags = Int(event.flags.rawValue) & MouseWindowTrigger.modifierMask
        let result = input.handle(kind, modifiers: flags,
            move: enabled ? move : nil, resize: enabled ? resize : nil)
        let previousDown = pendingDown
        switch result.pending {
        case .hold: pendingDown = event.copy()
        case .discard: pendingDown = nil
        case .replay:
            if let pendingDown { MouseWindowSession.replay(pendingDown) }
            pendingDown = nil
        case .none: break
        }
        if let action = result.began {
            session?.end(cancel: false)
            let next = MouseWindowSession(action: action,
                point: previousDown?.location ?? event.location, options: options, queue: worker)
            session = next
            if let previousDown { next.capture(previousDown) }
            if result.consume { next.capture(event) }
            next.begin()
        } else if result.consume && result.pending != .hold {
            session?.capture(event)
        }
        if case .motion = kind, input.active != nil { session?.update(event.location) }
        if result.ended { session?.end(cancel: false) }
        if result.pending == .replay {
            MouseWindowSession.replay(event)
            return true
        }
        return result.consume
    }

    private static func kind(_ type: CGEventType, _ event: CGEvent) -> MouseWindowInput.Event? {
        switch type {
        case .flagsChanged: .flags
        case .keyDown: .keyDown(Int(event.getIntegerValueField(.keyboardEventKeycode)))
        case .keyUp: .keyUp(Int(event.getIntegerValueField(.keyboardEventKeycode)))
        case .leftMouseDown: .buttonDown(1)
        case .rightMouseDown: .buttonDown(2)
        case .leftMouseUp: .buttonUp(1)
        case .rightMouseUp: .buttonUp(2)
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged: .motion
        default: nil
        }
    }

    @MainActor
    private func install() {
        if let tap {
            if !CGEvent.tapIsEnabled(tap: tap) { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        let types: [CGEventType] = [.flagsChanged, .keyDown, .keyUp, .leftMouseDown,
            .leftMouseUp, .rightMouseDown, .rightMouseUp, .mouseMoved, .leftMouseDragged, .rightMouseDragged]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: mask, callback: mouseWindowCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()),
            let source = CFMachPortCreateRunLoopSource(nil, tap, 0) else { return }
        self.tap = tap
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    @MainActor
    private func uninstall() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CFMachPortInvalidate(tap) }
        source = nil
        tap = nil
    }
}
