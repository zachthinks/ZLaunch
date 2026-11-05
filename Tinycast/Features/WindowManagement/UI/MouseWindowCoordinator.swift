import AppKit
import Observation

@MainActor
@Observable
final class MouseWindowCoordinator: HealthCheckable {
    private let settings: AppSettings
    private let hotKeys: HotKeyManager
    private let monitor = MouseWindowMonitor()
    private var recording = false
    private var sessionActive = true
    private var started = false
    @ObservationIgnored private var observers: [NotificationToken] = []
    @ObservationIgnored weak var healthTicker: HealthTicker?
    private var inputMessage: String?
    private var runtimeMessage: String?
    var message: String? { inputMessage ?? runtimeMessage }

    init(settings: AppSettings, hotKeys: HotKeyManager) {
        self.settings = settings
        self.hotKeys = hotKeys
    }

    func start() {
        guard !started else { return }
        started = true
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.willSleepNotification,
            NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.sessionDidBecomeActiveNotification,
            NSWorkspace.didWakeNotification]
        {
            let token = workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let active = note.name != NSWorkspace.willSleepNotification
                    && note.name != NSWorkspace.sessionDidResignActiveNotification
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    monitor.cancel()
                    sessionActive = active
                    apply()
                }
            }
            observers.append(NotificationToken(token, center: workspace))
        }
        let center = NotificationCenter.default
        let token = center.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.monitor.cancel() }
            }
        observers.append(NotificationToken(token, center: center))
        observe()
    }

    func stop() {
        started = false
        observers.removeAll()
        healthTicker?.unsubscribe(self)
        monitor.shutdown()
    }

    func prepareForTermination() async {
        stop()
        await monitor.finishWrites()
    }

    func setEnabled(_ enabled: Bool) {
        if enabled { Permissions.ensureAccessibility() }
        settings.mouseWindowEnabled = enabled
        apply()
    }

    func setRecording(_ value: Bool) {
        recording = value
        hotKeys.externalShortcutRecording = value
        apply()
    }

    func setTrigger(_ encoded: [Int], for action: MouseWindowGeometry.Action) {
        if !encoded.isEmpty {
            guard let trigger = MouseWindowTrigger(encoded: encoded) else {
                inputMessage = String(localized: "Choose a keyboard shortcut or both mouse buttons.")
                return
            }
            if let conflict = conflict(trigger, action: action) { inputMessage = conflict; return }
        }
        if action == .move { settings.mouseWindowMoveTrigger = encoded } else { settings.mouseWindowResizeTrigger = encoded }
        inputMessage = nil
        apply()
    }

    func healthCheck() {
        guard started else { return }
        apply()
        if !monitor.healthCheck() {
            runtimeMessage = String(localized: "Mouse controls need Accessibility permission.")
        }
    }

    private func observe() {
        guard started else { return }
        withObservationTracking {
            _ = hotKeys.revision
            apply()
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.observe() }
        }
    }

    private func apply() {
        let wantsEnabled = settings.windowManagementEnabled && settings.mouseWindowEnabled
        let active = wantsEnabled && !recording && hotKeys.recordingAction == nil
            && sessionActive && Permissions.isAccessibilityTrusted()
        let move = MouseWindowTrigger(encoded: settings.mouseWindowMoveTrigger)
        let resize = MouseWindowTrigger(encoded: settings.mouseWindowResizeTrigger)
        let moveConflict = move.flatMap { conflict($0, action: .move) }
        let resizeConflict = resize.flatMap { conflict($0, action: .resize) }
        var options = MouseWindowSession.Options()
        options.quadrants = settings.mouseWindowQuadrants
        options.focus = settings.mouseWindowFocus
        options.snap = settings.mouseWindowSnap
        options.voiceOver = NSWorkspace.shared.isVoiceOverEnabled
        options.excluded.formUnion(settings.mouseWindowExcludedApps)
        monitor.configure(move: active && moveConflict == nil ? move : nil,
            resize: active && resizeConflict == nil ? resize : nil, options: options)
        if wantsEnabled { healthTicker?.subscribe(self) } else if !monitor.isListening { healthTicker?.unsubscribe(self) }
        if wantsEnabled && !Permissions.isAccessibilityTrusted() {
            runtimeMessage = String(localized: "Mouse controls need Accessibility permission.")
        } else { runtimeMessage = moveConflict ?? resizeConflict }
    }

    private func conflict(_ trigger: MouseWindowTrigger, action: MouseWindowGeometry.Action) -> String? {
        let other = action == .move ? settings.mouseWindowResizeTrigger : settings.mouseWindowMoveTrigger
        if let other = MouseWindowTrigger(encoded: other), trigger.conflicts(with: other) {
            return String(localized: "Move and resize need different triggers.")
        }
        if let key = trigger.keyCode {
            let shortcut = KeyShortcut(carbonKeyCode: key,
                carbonModifiers: KeyShortcut.carbonModifiers(from: NSEvent.ModifierFlags(rawValue: UInt(trigger.modifiers))))
            if let owner = hotKeys.conflictOwner(of: .combo(shortcut)) {
                return String(localized: "This shortcut is already used by \(owner).")
            }
        } else {
            let candidates: [(Int, [HotKeyBinding])] = [
                (1 << 18, [.modifier(.leftControl), .modifier(.rightControl)]),
                (1 << 19, [.modifier(.leftOption), .modifier(.rightOption)]),
                (1 << 17, [.modifier(.leftShift), .modifier(.rightShift)]),
                (1 << 20, [.modifier(.leftCommand), .modifier(.rightCommand)]),
                (1 << 23, [.globe])
            ]
            for (flags, bindings) in candidates where trigger.modifiers == flags {
                for binding in bindings {
                    if let owner = hotKeys.conflictOwner(of: binding) {
                        return String(localized: "This shortcut is already used by \(owner).")
                    }
                }
            }
        }
        return nil
    }
}
