import AppKit
import LocalAuthentication

struct TestSecureRepository: SecureItemsRepository {
    var initial: [SecureItem] = []
    var fails = false
    var writeDelay: Duration = .zero
    func read(context: SecureItemsAuthentication) async throws -> [SecureItem] { initial }
    func write(_ items: [SecureItem], context: SecureItemsAuthentication) async throws {
        try await Task.sleep(for: writeDelay)
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
        coordinator.reveal(original)
        coordinator.isShowingSettings = true
        coordinator.leaveScreen()
        precondition(coordinator.isUnlocked && coordinator.items == [original], "Leaving must preserve the unlocked session")
        precondition(coordinator.draft == nil && coordinator.revealedID == nil && !coordinator.isShowingSettings)
        coordinator.unlock()
        precondition(!coordinator.isBusy, "Reopening an unlocked session must not authenticate again")
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
        late.leaveScreen()
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
        core.settings.secureItemsIdleSeconds = 21_600
        var expire: CheckedContinuation<Void, any Error>?
        let expiring = SecureItemsCoordinator(
            core: core, keychain: TestSecureRepository(initial: [original]),
            clipboard: SecureItemsClipboard(pasteboard: board), waitForIdle: { seconds in
                precondition(seconds == 21_600)
                try await withCheckedThrowingContinuation { expire = $0 }
            }, authenticate: { _ in true })
        expiring.unlock()
        await settle(expiring)
        expiring.leaveScreen()
        precondition(expiring.isUnlocked)
        for _ in 0..<100 where expire == nil { try? await Task.sleep(for: .milliseconds(10)) }
        precondition(expire != nil, "The idle timer must remain armed after closing")
        expire?.resume()
        for _ in 0..<100 where expiring.isUnlocked { try? await Task.sleep(for: .milliseconds(10)) }
        precondition(!expiring.isUnlocked && expiring.items.isEmpty, "Idle expiry must still lock a closed screen")
        let saving = SecureItemsCoordinator(
            core: core, keychain: TestSecureRepository(writeDelay: .milliseconds(50)),
            clipboard: SecureItemsClipboard(pasteboard: board), authenticate: { _ in true })
        saving.unlock()
        await settle(saving)
        saving.edit(original)
        saving.save()
        core.palette.mode = .launcher
        saving.leaveScreen()
        await settle(saving)
        precondition(saving.isUnlocked && saving.items == [original])
        precondition(core.palette.mode == .launcher && saving.draft == nil, "A late save must not reopen Secure Items")
        saving.lock()
        print("SecureItemsCoordinatorTests passed")
    }
}
