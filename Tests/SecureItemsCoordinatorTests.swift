import AppKit
import LocalAuthentication

struct TestSecureRepository: SecureItemsRepository {
    var initial: [SecureItem] = []
    var fails = false
    func read(context: SecureItemsAuthentication) async throws -> [SecureItem] { initial }
    func write(_ items: [SecureItem], context: SecureItemsAuthentication) async throws {
        if fails { throw SecureItemsKeychain.Failure.invalidData }
    }
}

@main struct SecureItemsCoordinatorTests {
    @MainActor static func settle(_ coordinator: SecureItemsCoordinator) async {
        for _ in 0..<100 {
            if !coordinator.isBusy { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        preconditionFailure("Operation did not settle")
    }
    @MainActor static func main() async {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let core = AppCore()
        let original = SecureItem(name: "original", value: "synthetic-secret")
        let coordinator = SecureItemsCoordinator(
            core: core, keychain: TestSecureRepository(initial: [original], fails: true),
            clipboard: SecureItemsClipboard(pasteboard: board), authenticate: { _ in true })
        coordinator.unlock()
        await settle(coordinator)
        precondition(coordinator.isUnlocked && coordinator.items == [original])
        precondition(core.paletteCoordinator.restoredFocusCount == 1, "Authentication must restore palette focus")
        coordinator.edit(original)
        coordinator.updateDraft(value: "replacement")
        coordinator.save()
        coordinator.updateDraft(value: "lost edit")
        precondition(coordinator.draft?.value == "replacement")
        await settle(coordinator)
        precondition(coordinator.items == [original])
        precondition(coordinator.draft?.value == "replacement")
        coordinator.reveal(original)
        coordinator.lock()
        precondition(coordinator.items.isEmpty && coordinator.draft == nil && coordinator.revealedID == nil)
        precondition(!coordinator.isUnlocked)
        let late = SecureItemsCoordinator(
            core: core, keychain: TestSecureRepository(initial: [original]),
            clipboard: SecureItemsClipboard(pasteboard: board), authenticate: { _ in
                try? await Task.sleep(for: .milliseconds(50))
                return true
            })
        late.unlock()
        await Task.yield()
        late.lock()
        await settle(late)
        precondition(!late.isUnlocked && late.items.isEmpty)
        let denied = SecureItemsCoordinator(
            core: core, keychain: TestSecureRepository(initial: [original]),
            clipboard: SecureItemsClipboard(pasteboard: board), authenticate: { _ in false })
        denied.unlock()
        await settle(denied)
        precondition(!denied.isUnlocked && denied.items.isEmpty)
        var requestedIdleDurations: [Int] = []
        let timed = SecureItemsCoordinator(
            core: core, keychain: TestSecureRepository(), clipboard: SecureItemsClipboard(pasteboard: board),
            waitForIdle: { seconds in
                requestedIdleDurations.append(seconds)
                try await Task.sleep(for: .seconds(3_600))
            }, authenticate: { _ in true })
        timed.start()
        timed.unlock()
        await settle(timed)
        try? await Task.sleep(for: .milliseconds(20))
        precondition(requestedIdleDurations == [120])
        core.settings.secureItemsIdleSeconds = 30
        try? await Task.sleep(for: .milliseconds(20))
        precondition(requestedIdleDurations == [120, 30], "Preference changes must replace the active idle timer")
        timed.lock()
        print("SecureItemsCoordinatorTests passed")
    }
}
