import CoreGraphics
import Foundation

/// Editor-only constraints; loading a layout never rearranges authored overlaps.
enum WindowLayoutInteraction {
    enum Handle: CaseIterable, Sendable {
        case move, left, right, top, bottom, topLeft, topRight, bottomLeft, bottomRight
        var left: Bool { self == .left || self == .topLeft || self == .bottomLeft }
        var right: Bool { self == .right || self == .topRight || self == .bottomRight }
        var top: Bool { self == .top || self == .topLeft || self == .topRight }
        var bottom: Bool { self == .bottom || self == .bottomLeft || self == .bottomRight }
    }

    static func handle(at point: CGPoint, size: CGSize) -> Handle {
        let margin = min(7, min(size.width, size.height) / 3)
        let left = point.x <= margin, right = point.x >= size.width - margin
        let top = point.y <= margin, bottom = point.y >= size.height - margin
        if top && left { return .topLeft }
        if top && right { return .topRight }
        if bottom && left { return .bottomLeft }
        if bottom && right { return .bottomRight }
        if left { return .left }
        if right { return .right }
        if top { return .top }
        if bottom { return .bottom }
        return .move
    }

    static func neighbors(of entry: WindowLayoutEntry, in entries: [WindowLayoutEntry], displayID: String)
        -> [WindowLayoutEntry] {
        entries.filter { $0.id != entry.id && $0.space == entry.space && $0.display.uuid == displayID }
    }

    static func proposed(_ start: CGRect, delta: CGSize, handle: Handle, bounds: CGRect) -> CGRect {
        if handle == .move {
            let size = CGSize(width: min(start.width, bounds.width), height: min(start.height, bounds.height))
            return CGRect(x: min(max(start.minX + delta.width, bounds.minX), bounds.maxX - size.width),
                          y: min(max(start.minY + delta.height, bounds.minY), bounds.maxY - size.height),
                          width: size.width, height: size.height)
        }
        let minimum = CGSize(width: bounds.width * 0.05, height: bounds.height * 0.05)
        let x = handle.left ? min(max(start.minX + delta.width, bounds.minX), start.maxX - minimum.width) : start.minX
        let y = handle.top ? min(max(start.minY + delta.height, bounds.minY), start.maxY - minimum.height) : start.minY
        let maxX = handle.right ? max(min(start.maxX + delta.width, bounds.maxX), x + minimum.width) : start.maxX
        let maxY = handle.bottom ? max(min(start.maxY + delta.height, bounds.maxY), y + minimum.height) : start.maxY
        return CGRect(x: x, y: y, width: maxX - x, height: maxY - y)
    }

    static func constrained(from start: CGRect, to end: CGRect, neighbors: [CGRect], handle: Handle = .move) -> CGRect {
        var limit = neighbors.reduce(CGFloat(1)) { min($0, firstCollision(from: start, to: end, obstacle: $1)) }
        let change = max(1, abs(end.minX - start.minX), abs(end.minY - start.minY),
                         abs(end.width - start.width), abs(end.height - start.height))
        for _ in 0..<4 {
            let candidate = aligned(interpolated(start, end, at: limit), handle: handle)
            if neighbors.allSatisfy({ area(candidate.intersection($0)) <= area(start.intersection($0)) + 0.01 }) {
                return candidate
            }
            limit = max(0, limit - 1 / change)
        }
        return start
    }

    private static func aligned(_ rect: CGRect, handle: Handle) -> CGRect {
        if handle == .move {
            return CGRect(x: rect.minX.rounded(), y: rect.minY.rounded(),
                          width: rect.width.rounded(), height: rect.height.rounded())
        }
        let x = handle.left ? ceil(rect.minX) : rect.minX
        let y = handle.top ? ceil(rect.minY) : rect.minY
        let maxX = handle.right ? floor(rect.maxX) : rect.maxX
        let maxY = handle.bottom ? floor(rect.maxY) : rect.maxY
        return CGRect(x: x, y: y, width: maxX - x, height: maxY - y)
    }

    static func overlaps(_ lhs: CGRect, _ rhs: CGRect) -> Bool { area(lhs.intersection(rhs)) > 0.01 }

    private static func interpolated(_ a: CGRect, _ b: CGRect, at t: CGFloat) -> CGRect {
        CGRect(x: a.minX + (b.minX - a.minX) * t, y: a.minY + (b.minY - a.minY) * t,
               width: a.width + (b.width - a.width) * t, height: a.height + (b.height - a.height) * t)
    }

    private static func area(_ rect: CGRect) -> CGFloat {
        rect.isNull || rect.isEmpty ? 0 : rect.width * rect.height
    }

    /// Intersection area is quadratic between edge crossings; test extrema to avoid tunneling.
    private static func firstCollision(from start: CGRect, to end: CGRect, obstacle: CGRect) -> CGFloat {
        let allowed = area(start.intersection(obstacle)) + 0.01
        var breaks: [CGFloat] = [0, 1]
        let edges = [(start.minX, end.minX, obstacle.minX), (start.minX, end.minX, obstacle.maxX),
                     (start.maxX, end.maxX, obstacle.minX), (start.maxX, end.maxX, obstacle.maxX),
                     (start.minY, end.minY, obstacle.minY), (start.minY, end.minY, obstacle.maxY),
                     (start.maxY, end.maxY, obstacle.minY), (start.maxY, end.maxY, obstacle.maxY)]
        for (a, b, edge) in edges where a != b {
            let t = (edge - a) / (b - a)
            if t > 0 && t < 1 { breaks.append(t) }
        }
        breaks = Array(Set(breaks)).sorted()
        func overlap(_ t: CGFloat) -> CGFloat { area(interpolated(start, end, at: t).intersection(obstacle)) }
        for index in 1..<breaks.count {
            let a = breaks[index - 1], b = breaks[index]
            let startArea = overlap(a), endArea = overlap(b), midArea = overlap((a + b) / 2)
            let quadratic = 2 * (startArea + endArea - 2 * midArea)
            let linear = endArea - startArea - quadratic
            var points: [CGFloat] = [a, b]
            if abs(quadratic) > 0.000001 {
                let extremum = -linear / (2 * quadratic)
                if extremum > 0 && extremum < 1 { points.insert(a + (b - a) * extremum, at: 1) }
            }
            var previous = a
            for point in points {
                if overlap(point) > allowed {
                    var low = previous, high = point
                    for _ in 0..<35 {
                        let middle = (low + high) / 2
                        if overlap(middle) > allowed { high = middle } else { low = middle }
                    }
                    return low
                }
                previous = point
            }
        }
        return 1
    }
}
