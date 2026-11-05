import Foundation

struct MouseWindowTrigger: Equatable, Sendable {
    static let modifierMask = (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20) | (1 << 23)
    static let functionKeys: Set<Int> = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111,
        105, 107, 113, 106, 64, 79, 80, 90]
    let modifiers: Int
    let keyCode: Int?
    let buttons: Int

    init?(encoded: [Int]) {
        guard encoded.count == 3, encoded[0] >= 0,
            encoded[0] & ~Self.modifierMask == 0, (-1...127).contains(encoded[1]),
            (0...3).contains(encoded[2]) else { return nil }
        let key = encoded[1] == -1 ? nil : encoded[1]
        guard encoded[0] != 0 || key.map(Self.functionKeys.contains) == true
            || (key == nil && encoded[2] == 3) else { return nil }
        modifiers = encoded[0]
        keyCode = key
        buttons = encoded[2]
    }

    var encoded: [Int] { [modifiers, keyCode ?? -1, buttons] }

    static func accepts(_ encoded: [Int], alongside other: [Int]) -> Bool {
        if encoded.isEmpty { return true }
        guard let trigger = Self(encoded: encoded) else { return false }
        return Self(encoded: other).map { !trigger.conflicts(with: $0) } ?? true
    }

    static func acceptsPair(_ pair: [[Int]]) -> Bool {
        pair.count == 2 && accepts(pair[0], alongside: pair[1]) && accepts(pair[1], alongside: pair[0])
    }

    func matches(modifiers flags: Int, keys: Set<Int>, buttons held: Int) -> Bool {
        flags & Self.modifierMask == modifiers
            && (keyCode.map(keys.contains) ?? true)
            && (buttons == 0 || held & buttons == buttons)
    }

    func conflicts(with other: Self) -> Bool {
        modifiers == other.modifiers && keyCode == other.keyCode
            && (buttons == 0 || other.buttons == 0 || buttons == other.buttons
                || buttons == 3 || other.buttons == 3)
    }
}
