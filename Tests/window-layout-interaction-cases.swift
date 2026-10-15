import CoreGraphics
import Foundation

extension WindowLayoutTests {
    static func interactionConstraints() {
        typealias Interaction = WindowLayoutInteraction
        let box = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let start = CGRect(x: 100, y: 100, width: 200, height: 200)
        let size = CGSize(width: 200, height: 200)
        let hits: [(CGPoint, Interaction.Handle)] = [
            (.init(x: 1, y: 1), .topLeft), (.init(x: 199, y: 1), .topRight),
            (.init(x: 1, y: 199), .bottomLeft), (.init(x: 199, y: 199), .bottomRight),
            (.init(x: 1, y: 100), .left), (.init(x: 199, y: 100), .right),
            (.init(x: 100, y: 1), .top), (.init(x: 100, y: 199), .bottom),
            (.init(x: 100, y: 100), .move)]
        for (point, expected) in hits {
            expect(Interaction.handle(at: point, size: size) == expected, "every edge/corner and body has its own hit target")
        }
        for handle in Interaction.Handle.allCases where handle != .move {
            let result = Interaction.proposed(start, delta: .init(width: 30, height: 40), handle: handle, bounds: box)
            expect(!handle.left || result.maxX == start.maxX, "left resize holds right edge")
            expect(!handle.right || result.minX == start.minX, "right resize holds left edge")
            expect(!handle.top || result.maxY == start.maxY, "top resize holds bottom edge")
            expect(!handle.bottom || result.minY == start.minY, "bottom resize holds top edge")
            expect(result.width >= box.width * 0.05 && result.height >= box.height * 0.05, "resize respects minimum size")
        }
        let bounded = Interaction.proposed(start, delta: .init(width: -2000, height: -2000), handle: .topLeft, bounds: box)
        expect(bounded.minX == 0 && bounded.minY == 0 && bounded.maxX == 300 && bounded.maxY == 300,
               "top-left resize clamps to display without moving opposite corner")
        let neighbor = CGRect(x: 350, y: 100, width: 200, height: 200)
        let expanded = Interaction.proposed(start, delta: .init(width: 400, height: 0), handle: .right, bounds: box)
        let stopped = Interaction.constrained(from: start, to: expanded, neighbors: [neighbor], handle: .right)
        expect(stopped.maxX == neighbor.minX && stopped.minX == start.minX, "resize stops exactly at neighbor")
        let fastMove = Interaction.constrained(from: start, to: start.offsetBy(dx: 650, dy: 0), neighbors: [neighbor])
        expect(fastMove.maxX <= neighbor.minX && fastMove.minX >= start.minX, "fast move cannot tunnel through neighbor")
        let thin = CGRect(x: 350, y: 100, width: 1, height: 200)
        let thinStop = Interaction.constrained(from: start, to: start.offsetBy(dx: 650, dy: 0), neighbors: [thin])
        expect(thinStop.maxX <= thin.minX, "swept collision catches a one-point obstacle")
        let legacy = CGRect(x: 250, y: 100, width: 200, height: 200)
        expectRect(Interaction.constrained(from: start, to: start, neighbors: [legacy]), start,
                   "existing intentional overlap is unchanged without a gesture")
        let worse = Interaction.constrained(from: start, to: start.offsetBy(dx: 50, dy: 0), neighbors: [legacy])
        expect(worse == start, "gesture cannot increase an existing overlap")
        let apart = Interaction.constrained(from: start, to: start.offsetBy(dx: -100, dy: 0), neighbors: [legacy])
        expect(apart.minX == 0, "legacy overlap can move apart")
        let shrink = Interaction.proposed(start, delta: .init(width: -100, height: 0), handle: .right, bounds: box)
        expectRect(Interaction.constrained(from: start, to: shrink, neighbors: [legacy], handle: .right), shrink,
                   "legacy overlap can shrink clear")
        let current = entry(bundleID: "same", display: 1)
        var duplicate = entry(bundleID: "same", display: 1)
        duplicate.space = current.space
        var otherSpace = entry(display: 1)
        otherSpace.space = 2
        let otherDisplay = entry(display: 2)
        let neighbors = Interaction.neighbors(of: current, in: [current, duplicate, otherSpace, otherDisplay],
                                             displayID: display(1).uuid)
        expect(neighbors.map(\.id) == [duplicate.id], "collision excludes self and other displays/Spaces, not duplicate apps")
        for index in 0..<200 {
            let delta = CGSize(width: CGFloat(index * 13 % 700), height: CGFloat(index * 31 % 400))
            let proposed = Interaction.proposed(start, delta: delta, handle: .bottomRight, bounds: box)
            let result = Interaction.constrained(from: start, to: proposed, neighbors: [neighbor], handle: .bottomRight)
            expect(!Interaction.overlaps(result, neighbor), "diagonal resize never creates overlap")
        }
    }
}
