import Foundation

@main
@MainActor
struct WindowSpaceTests {
    static var failures = 0

    static func main() async {
        await check([3], succeeds: true)
        await check([1], succeeds: false)
        await check([], succeeds: false)
        await check([1, 3], succeeds: false)
        var reads = 0
        do {
            try await WindowSpaceAccess.verify(windowID: 42, on: 3) { _ in
                reads += 1
                return reads < 3 ? [3] : [1]
            }
            failures += 1
            print("FAIL: transient membership was accepted")
        } catch { }
        let cancelled = Task {
            try await WindowSpaceAccess.verify(windowID: 42, on: 3) { _ in [3] }
        }
        cancelled.cancel()
        do {
            try await cancelled.value
            failures += 1
            print("FAIL: cancellation was accepted")
        } catch is CancellationError { } catch {
            failures += 1
        }
        print("Space verification failures: \(failures)")
        if failures > 0 { exit(1) }
    }

    static func check(_ membership: [UInt64], succeeds: Bool) async {
        do {
            try await WindowSpaceAccess.verify(windowID: 42, on: 3) { id in
                if id != 42 { failures += 1 }
                return membership
            }
            if !succeeds { failures += 1 }
        } catch {
            if succeeds { failures += 1 }
        }
    }
}
