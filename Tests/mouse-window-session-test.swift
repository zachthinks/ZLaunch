import AppKit
@preconcurrency import ApplicationServices

final class MouseAXFixture: @unchecked Sendable {
    let lock = NSLock()
    let targetEntered = DispatchSemaphore(value: 0)
    let targetRelease = DispatchSemaphore(value: 0)
    let neighborEntered = DispatchSemaphore(value: 0)
    let neighborRelease = DispatchSemaphore(value: 0)
    var blockTarget = true
    var blockNeighbors = false
    var succeeds = true
    var writes = 0

    func read<T>(_ body: (MouseAXFixture) -> T) -> T {
        lock.lock(); defer { lock.unlock() }
        return body(self)
    }
}

enum MouseWindowAccess {
    static let fixture = MouseAXFixture()
    static func target(at point: CGPoint, excluded: Set<String>) -> AXUIElement? {
        fixture.targetEntered.signal()
        if fixture.read({ $0.blockTarget }) {
            precondition(fixture.targetRelease.wait(timeout: .now() + 5) == .success)
        }
        return fixture.read { $0.succeeds } ? AXUIElementCreateSystemWide() : nil
    }
    static func frame(_ window: AXUIElement) -> CGRect? { CGRect(x: 0, y: 0, width: 800, height: 600) }
    static func settable(_ window: AXUIElement, _ attribute: String) -> Bool { true }
    static func neighbors(excluding frame: CGRect, apps: Set<String>) -> [CGRect] {
        if fixture.read({ $0.blockNeighbors }) {
            fixture.neighborEntered.signal()
            precondition(fixture.neighborRelease.wait(timeout: .now() + 5) == .success)
        }
        return []
    }
    static func application(_ window: AXUIElement) -> AXUIElement? { nil }
    static func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? { nil }
    static func focus(_ window: AXUIElement, app: AXUIElement) {}
    static func move(_ window: AXUIElement, to origin: CGPoint) -> Bool {
        fixture.read { $0.writes += 1 }; return true
    }
    static func resize(_ window: AXUIElement, to size: CGSize) -> Bool {
        fixture.read { $0.writes += 1 }; return true
    }
}

final class MouseReplayFixture: @unchecked Sendable {
    private let lock = NSLock()
    private var types: [CGEventType] = []
    func record(_ event: CGEvent) {
        lock.lock(); defer { lock.unlock() }
        types.append(event.type)
    }
    var recorded: [CGEventType] {
        lock.lock(); defer { lock.unlock() }
        return types
    }
}

@main
struct MouseWindowSessionTests {
    static func event(_ type: CGEventType) -> CGEvent {
        let event = CGEvent(source: nil)!
        event.type = type
        return event
    }

    static func main() {
        let queue = DispatchQueue(label: "test.mouse-worker")
        let fixture = MouseWindowAccess.fixture
        let replay = MouseReplayFixture()
        let session = MouseWindowSession(action: .resize, point: .zero, options: .init(), queue: queue,
            replay: { replay.record($0) })
        session.capture(event(.leftMouseDown))
        session.begin()
        precondition(fixture.targetEntered.wait(timeout: .now() + 5) == .success)
        session.update(CGPoint(x: 20, y: 30))
        session.end(cancel: true)
        session.end(cancel: false)
        session.capture(event(.leftMouseUp))
        fixture.targetRelease.signal()
        queue.sync {}
        precondition(fixture.read { $0.writes } == 0)
        precondition(replay.recorded == [.leftMouseDown, .leftMouseUp])

        fixture.read { $0.blockTarget = false; $0.blockNeighbors = true }
        let secondReplay = MouseReplayFixture()
        let second = MouseWindowSession(action: .move, point: .zero, options: .init(), queue: queue,
            replay: { secondReplay.record($0) })
        second.capture(event(.rightMouseDown))
        second.begin()
        precondition(fixture.neighborEntered.wait(timeout: .now() + 5) == .success)
        second.end(cancel: true)
        second.capture(event(.rightMouseUp))
        fixture.neighborRelease.signal()
        queue.sync {}
        precondition(secondReplay.recorded == [.rightMouseDown, .rightMouseUp])
        precondition(fixture.read { $0.writes } == 0)

        fixture.read { $0.blockNeighbors = false; $0.succeeds = false }
        let replayStarted = DispatchSemaphore(value: 0)
        let replayRelease = DispatchSemaphore(value: 0)
        let captureFinished = DispatchSemaphore(value: 0)
        let thirdReplay = MouseReplayFixture()
        let third = MouseWindowSession(action: .move, point: .zero, options: .init(), queue: queue,
            replay: { value in
                if value.type == .leftMouseDown {
                    replayStarted.signal()
                    precondition(replayRelease.wait(timeout: .now() + 5) == .success)
                }
                thirdReplay.record(value)
            })
        third.capture(event(.leftMouseDown))
        third.begin()
        precondition(replayStarted.wait(timeout: .now() + 5) == .success)
        DispatchQueue.global().async {
            third.capture(event(.leftMouseUp))
            captureFinished.signal()
        }
        replayRelease.signal()
        precondition(captureFinished.wait(timeout: .now() + 5) == .success)
        third.end(cancel: false)
        queue.sync {}
        precondition(thirdReplay.recorded == [.leftMouseDown, .leftMouseUp])
        print("Mouse window cancellation and replay ordering fixtures passed")
    }
}
