import Foundation

struct MouseWindowInput: Sendable {
    enum Event: Sendable {
        case flags, keyDown(Int), keyUp(Int), buttonDown(Int), buttonUp(Int), motion, cancel
    }
    enum Pending: Sendable { case none, hold, replay, discard }
    struct Decision: Sendable {
        var began: MouseWindowGeometry.Action?
        var ended = false
        var consume = false
        var pending: Pending = .none
    }

    private(set) var active: MouseWindowGeometry.Action?
    private var keys: Set<Int> = []
    private var buttons = 0
    private var swallowedButtons = 0
    private var swallowedKeys: Set<Int> = []
    private var pendingButton = 0
    private var passingButtons = false

    var isDraining: Bool { swallowedButtons != 0 || !swallowedKeys.isEmpty }
    var trackedKeys: Set<Int> { keys.union(swallowedKeys) }

    mutating func reconcile(heldKeys: Set<Int>, heldButtons: Int) -> Bool {
        let released = !keys.isSubset(of: heldKeys) || buttons & heldButtons != buttons
        keys.formIntersection(heldKeys)
        swallowedKeys.formIntersection(heldKeys)
        buttons &= heldButtons
        swallowedButtons &= heldButtons
        if buttons == 0 { passingButtons = false }
        return released && active != nil
    }

    mutating func handle(
        _ event: Event, modifiers: Int, move: MouseWindowTrigger?, resize: MouseWindowTrigger?
    ) -> Decision {
        var result = Decision()
        let bindings: [(MouseWindowGeometry.Action, MouseWindowTrigger)] =
            [(MouseWindowGeometry.Action.move, move), (.resize, resize)]
            .compactMap { action, trigger in trigger.map { (action, $0) } }
        switch event {
        case .keyDown(let code): keys.insert(code)
        case .keyUp(let code):
            keys.remove(code)
            result.consume = swallowedKeys.remove(code) != nil
        case .buttonDown(let mask): buttons |= mask
        case .buttonUp(let mask):
            buttons &= ~mask
            result.consume = swallowedButtons & mask != 0
            swallowedButtons &= ~mask
        case .cancel:
            result.ended = active != nil
            result.pending = pendingButton == 0 ? .none : .replay
            active = nil
            pendingButton = 0
            keys.removeAll()
            passingButtons = buttons != 0
            return result
        case .flags, .motion: break
        }

        let match = bindings.first { _, trigger in
            trigger.matches(modifiers: modifiers, keys: keys, buttons: buttons)
                && keys.allSatisfy { $0 == trigger.keyCode }
        }
        if let active, match?.0 != active {
            self.active = nil
            result.ended = true
        }
        if active == nil && !result.ended && !passingButtons,
            swallowedButtons == 0 || pendingButton != 0, let (action, _) = match
        {
            active = action
            result.began = action
            if pendingButton != 0 {
                result.pending = .discard
                swallowedButtons |= pendingButton
                pendingButton = 0
            }
        }
        if active != nil {
            switch event {
            case .buttonDown(let mask): swallowedButtons |= mask; result.consume = true
            case .buttonUp, .motion: result.consume = true
            case .keyDown(let code): swallowedKeys.insert(code); result.consume = true
            default: break
            }
        } else if pendingButton != 0 {
            result.pending = .replay
            pendingButton = 0
            passingButtons = buttons != 0
        } else if case .buttonDown(let mask) = event, !passingButtons {
            let needsBoth = bindings.contains { _, trigger in
                trigger.buttons == 3
                    && trigger.matches(modifiers: modifiers, keys: keys, buttons: 3)
            }
            if needsBoth {
                pendingButton = mask
                result.pending = .hold
                result.consume = true
            } else {
                passingButtons = true
            }
        }
        if case .keyDown(let code) = event,
            bindings.contains(where: { $0.1.keyCode == code && $0.1.modifiers == modifiers })
        {
            swallowedKeys.insert(code)
            result.consume = true
        }
        if case .motion = event, swallowedButtons != 0 { result.consume = true }
        if buttons == 0 { passingButtons = false }
        return result
    }
}
