import Foundation
import CoreGraphics

@main
struct MouseWindowTests {
    static func main() {
        let rect = CGRect(x: -400, y: 100, width: 800, height: 400)
        let xs: [CGFloat] = [-399, 0, 399]
        let ys: [CGFloat] = [101, 300, 499]
        let zones: [MouseWindowGeometry.Zone] = [
            .topLeft, .top, .topRight, .left, .center, .right,
            .bottomLeft, .bottom, .bottomRight
        ]
        for (row, y) in ys.enumerated() {
            for (column, x) in xs.enumerated() {
                precondition(MouseWindowGeometry.zone(at: CGPoint(x: x, y: y), in: rect)
                    == zones[row * 3 + column])
            }
        }
        precondition(MouseWindowGeometry.zone(at: CGPoint(x: -100, y: 200), in: rect) == .top)
        precondition(MouseWindowGeometry.zone(at: CGPoint(x: 100, y: 200), in: rect) == .topRight)
        let start = CGPoint(x: 0, y: 300)
        let pointer = CGPoint(x: 20, y: 310)
        let expected: [CGRect] = [
            CGRect(x: -380, y: 110, width: 780, height: 390),
            CGRect(x: -400, y: 110, width: 800, height: 390),
            CGRect(x: -400, y: 110, width: 820, height: 390),
            CGRect(x: -380, y: 100, width: 780, height: 400),
            CGRect(x: -420, y: 110, width: 840, height: 380),
            CGRect(x: -400, y: 100, width: 820, height: 400),
            CGRect(x: -380, y: 100, width: 780, height: 410),
            CGRect(x: -400, y: 100, width: 800, height: 410),
            CGRect(x: -400, y: 100, width: 820, height: 410)
        ]
        for (zone, frame) in zip(zones, expected) {
            precondition(MouseWindowGeometry.frame(initial: rect, pointerStart: start,
                pointer: pointer, action: .resize, zone: zone, neighbors: []) == frame)
        }
        precondition(MouseWindowGeometry.frame(initial: rect, pointerStart: start,
            pointer: pointer, action: .move, zone: .center, neighbors: [])
            == rect.offsetBy(dx: 20, dy: 10))
        let neighbor = CGRect(x: 425, y: 100, width: 200, height: 400)
        let snapped = MouseWindowGeometry.frame(initial: rect, pointerStart: start,
            pointer: pointer, action: .resize, zone: .right, neighbors: [neighbor])
        precondition(snapped.maxX == 425)
        let far = CGRect(x: 431, y: 100, width: 200, height: 400)
        precondition(MouseWindowGeometry.frame(initial: rect, pointerStart: start,
            pointer: pointer, action: .resize, zone: .right, neighbors: [far]).maxX == 420)
        let nonoverlapping = CGRect(x: 425, y: 600, width: 200, height: 400)
        precondition(MouseWindowGeometry.frame(initial: rect, pointerStart: start,
            pointer: pointer, action: .resize, zone: .right, neighbors: [nonoverlapping]).maxX == 420)
        precondition(MouseWindowTrigger(encoded: []) == nil)
        precondition(MouseWindowTrigger(encoded: [0, -1, 1]) == nil)
        precondition(MouseWindowTrigger(encoded: [0, -1, 3]) != nil)
        let trigger = MouseWindowTrigger(encoded: [1 << 19, -1, 1])!
        precondition(trigger.matches(modifiers: 1 << 19, keys: [], buttons: 1))
        precondition(!trigger.matches(modifiers: 1 << 19, keys: [], buttons: 0))
        precondition(!trigger.matches(modifiers: (1 << 19) | (1 << 20), keys: [], buttons: 1))
        precondition(MouseWindowTrigger(encoded: [1 << 19, 999, 1]) == nil)
        testInput()
        precondition(!MouseWindowTrigger.accepts(trigger.encoded, alongside: trigger.encoded))
        precondition(MouseWindowTrigger.accepts([], alongside: trigger.encoded))
        let other = [1 << 20, -1, 2]
        precondition(MouseWindowTrigger.acceptsPair([trigger.encoded, other]))
        precondition(MouseWindowTrigger.acceptsPair([other, trigger.encoded]))
        precondition(MouseWindowTrigger.acceptsPair([other, []]))
        precondition(!MouseWindowTrigger.acceptsPair([other, other]))
        precondition(!MouseWindowTrigger.acceptsPair([other]))
        let requested = CGRect(x: 350, y: 400, width: 50, height: 100)
        let actual = CGRect(x: 350, y: 400, width: 300, height: 200)
        let corrected = MouseWindowGeometry.corrected(requested: requested, actual: actual,
            initial: rect, zone: .topLeft)
        precondition(corrected.maxX == rect.maxX && corrected.maxY == rect.maxY)
        precondition(corrected.size == actual.size)
        let centered = MouseWindowGeometry.corrected(requested: requested, actual: actual,
            initial: rect, zone: .center)
        precondition(centered.midX == rect.midX && centered.midY == rect.midY)
        print("Mouse window geometry, trigger and input fixtures passed")
    }

    static func testInput() {
        let option = 1 << 19
        let drag = MouseWindowTrigger(encoded: [option, -1, 1])!
        var input = MouseWindowInput()
        precondition(input.handle(.flags, modifiers: option, move: drag, resize: nil).began == nil)
        let start = input.handle(.buttonDown(1), modifiers: option, move: drag, resize: nil)
        precondition(start.began == .move && start.consume)
        precondition(input.handle(.motion, modifiers: option, move: drag, resize: nil).consume)
        precondition(input.handle(.flags, modifiers: 0, move: drag, resize: nil).ended)
        precondition(input.handle(.buttonUp(1), modifiers: 0, move: drag, resize: nil).consume)
        precondition(!input.isDraining)
        precondition(!input.handle(.buttonDown(1), modifiers: 0, move: drag, resize: nil).consume)
        precondition(!input.handle(.buttonUp(1), modifiers: 0, move: drag, resize: nil).consume)

        let both = MouseWindowTrigger(encoded: [0, -1, 3])!
        var chord = MouseWindowInput()
        precondition(chord.handle(.buttonDown(1), modifiers: 0, move: both, resize: nil).pending == .hold)
        precondition(chord.handle(.buttonUp(1), modifiers: 0, move: both, resize: nil).pending == .replay)
        precondition(chord.handle(.buttonDown(2), modifiers: 0, move: both, resize: nil).pending == .hold)
        let second = chord.handle(.buttonDown(1), modifiers: 0, move: both, resize: nil)
        precondition(second.began == .move && second.pending == .discard)
        precondition(chord.handle(.buttonUp(1), modifiers: 0, move: both, resize: nil).ended)
        precondition(chord.handle(.buttonUp(2), modifiers: 0, move: both, resize: nil).consume)
        precondition(!chord.isDraining)

        let key = MouseWindowTrigger(encoded: [option, 0, 0])!
        var keyboard = MouseWindowInput()
        precondition(keyboard.handle(.keyDown(0), modifiers: option, move: nil, resize: key).began == .resize)
        precondition(keyboard.handle(.cancel, modifiers: 0, move: nil, resize: nil).ended)
        precondition(keyboard.handle(.keyUp(0), modifiers: 0, move: nil, resize: nil).consume)
        precondition(!keyboard.isDraining)
        _ = keyboard.handle(.keyDown(0), modifiers: option, move: nil, resize: key)
        precondition(keyboard.reconcile(heldKeys: [], heldButtons: 0))
        _ = keyboard.handle(.cancel, modifiers: 0, move: nil, resize: nil)
        precondition(!keyboard.isDraining)
    }
}
