// Adapted from SwiftShift (MIT); attribution in Custom/SwiftShift-LICENSE.txt.
import CoreGraphics
import Foundation

enum MouseWindowGeometry {
    enum Action: String, Sendable { case move, resize }
    enum Zone: Sendable {
        case topLeft, top, topRight, left, center, right, bottomLeft, bottom, bottomRight

        var edges: (left: Bool, right: Bool, top: Bool, bottom: Bool) {
            switch self {
            case .topLeft: (true, false, true, false)
            case .top: (false, false, true, false)
            case .topRight: (false, true, true, false)
            case .left: (true, false, false, false)
            case .center: (true, true, true, true)
            case .right: (false, true, false, false)
            case .bottomLeft: (true, false, false, true)
            case .bottom: (false, false, false, true)
            case .bottomRight: (false, true, false, true)
            }
        }
    }

    static func zone(at point: CGPoint, in frame: CGRect) -> Zone {
        let left = frame.minX + frame.width * 0.375
        let right = frame.maxX - frame.width * 0.375
        let top = frame.minY + frame.height * 0.375
        let bottom = frame.maxY - frame.height * 0.375
        if point.y <= top {
            return point.x < left ? .topLeft : (point.x < right ? .top : .topRight)
        }
        if point.y <= bottom {
            return point.x < left ? .left : (point.x < right ? .center : .right)
        }
        return point.x < left ? .bottomLeft : (point.x < right ? .bottom : .bottomRight)
    }

    static func frame(
        initial: CGRect, pointerStart: CGPoint, pointer: CGPoint,
        action: Action, zone: Zone, neighbors: [CGRect]
    ) -> CGRect {
        let dx = pointer.x - pointerStart.x
        let dy = pointer.y - pointerStart.y
        if action == .move {
            let moved = initial.offsetBy(dx: dx, dy: dy)
            let x = snap([moved.minX, moved.maxX], to: horizontalEdges(moved, neighbors))
            let y = snap([moved.minY, moved.maxY], to: verticalEdges(moved, neighbors))
            return moved.offsetBy(dx: x, dy: y)
        }
        var frame = initial
        let edges = zone.edges
        if edges.left { frame.origin.x += zone == .center ? -dx : dx }
        if edges.top { frame.origin.y += dy }
        if zone == .center {
            frame.size.width += 2 * dx
            frame.size.height -= 2 * dy
        } else {
            frame.size.width += edges.left ? -dx : (edges.right ? dx : 0)
            frame.size.height += edges.top ? -dy : (edges.bottom ? dy : 0)
        }
        frame.size.width = max(1, frame.width)
        frame.size.height = max(1, frame.height)
        let horizontal = horizontalEdges(frame, neighbors)
        let vertical = verticalEdges(frame, neighbors)
        var left = frame.minX, right = frame.maxX, top = frame.minY, bottom = frame.maxY
        if edges.left { left += snap([left], to: horizontal) }
        if edges.right { right += snap([right], to: horizontal) }
        if edges.top { top += snap([top], to: vertical) }
        if edges.bottom { bottom += snap([bottom], to: vertical) }
        return CGRect(x: min(left, right - 1), y: min(top, bottom - 1),
            width: max(right - left, 1), height: max(bottom - top, 1))
    }

    private static func horizontalEdges(_ frame: CGRect, _ neighbors: [CGRect]) -> [CGFloat] {
        neighbors.filter { frame.minY <= $0.maxY && $0.minY <= frame.maxY }
            .flatMap { [$0.minX, $0.maxX] }
    }

    static func corrected(requested: CGRect, actual: CGRect, initial: CGRect, zone: Zone) -> CGRect {
        var result = actual
        if abs(actual.width - requested.width) > 0.5 {
            if zone == .center {
                result.origin.x = initial.midX - actual.width / 2
            } else if zone.edges.left { result.origin.x = initial.maxX - actual.width }
        }
        if abs(actual.height - requested.height) > 0.5 {
            if zone == .center {
                result.origin.y = initial.midY - actual.height / 2
            } else if zone.edges.top { result.origin.y = initial.maxY - actual.height }
        }
        return result
    }

    private static func verticalEdges(_ frame: CGRect, _ neighbors: [CGRect]) -> [CGFloat] {
        neighbors.filter { frame.minX <= $0.maxX && $0.minX <= frame.maxX }
            .flatMap { [$0.minY, $0.maxY] }
    }

    private static func snap(_ moving: [CGFloat], to targets: [CGFloat]) -> CGFloat {
        var nearest: CGFloat?
        for edge in moving {
            for target in targets {
                let delta = target - edge
                guard abs(delta) <= 10 else { continue }
                if nearest.map({ abs(delta) < abs($0) }) ?? true { nearest = delta }
            }
        }
        return nearest ?? 0
    }
}
