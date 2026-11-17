import AppKit
import LocalAuthentication
import Observation

@MainActor
@Observable
final class SecureItemsCoordinator {
    private(set) var items: [SecureItem] = []
    private(set) var isUnlocked = false
    private(set) var isBusy = false
    private(set) var draft: SecureItem?
    var settingsField = 0
    var editorField = 0
    var isShowingSettings = false
    var revealedID: UUID?
    private let keychain: any SecureItemsRepository
    private let waitForIdle: @MainActor (Int) async throws -> Void
    private let authenticate: @MainActor (SecureItemsAuthentication) async throws -> Bool
    let clipboard: SecureItemsClipboard
    private var context: SecureItemsAuthentication?
    private var generation = UUID()
    private var operation: Task<Void, Never>?
    private var idle: Task<Void, Never>?
    private var observers: [NotificationToken] = []
    private unowned let core: AppCore

    init(
        core: AppCore, keychain: any SecureItemsRepository = SecureItemsKeychain(),
        clipboard: SecureItemsClipboard = SecureItemsClipboard(),
        waitForIdle: @escaping @MainActor (Int) async throws -> Void = { seconds in
            try await Task.sleep(for: .seconds(seconds))
        },
        authenticate: @escaping @MainActor (SecureItemsAuthentication) async throws -> Bool = { context in
            try await context.context.evaluatePolicy(
                .deviceOwnerAuthentication, localizedReason: String(localized: "Unlock Secure Items"))
        }
    ) {
        self.core = core
        self.keychain = keychain
        self.clipboard = clipboard
        self.waitForIdle = waitForIdle
        self.authenticate = authenticate
    }

    func start() {
        guard observers.isEmpty else { return }
        observeIdleTimeout()
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.lock(clearClipboard: true) }
            }
            observers.append(NotificationToken(token, center: center))
        }
        let distributed = DistributedNotificationCenter.default()
        let token = distributed.addObserver(
            forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.lock(clearClipboard: true) }
        }
        observers.append(NotificationToken(token, center: distributed))
    }

    isolated deinit { operation?.cancel(); idle?.cancel(); context?.invalidate() }

    func show() { core.paletteCoordinator.showPalette(mode: .secureItems) }

    func unlock() {
        guard !isBusy, !isUnlocked else { return }
        let authentication = SecureItemsAuthentication()
        context = authentication
        let ticket = generation
        isBusy = true
        operation = Task { [weak self] in
            guard let self else { return }
            defer {
                self.isBusy = false
                self.operation = nil
                if self.generation == ticket, self.core.palette.mode == .secureItems {
                    self.core.paletteCoordinator.restoreAfterAuthentication()
                }
            }
            do {
                let accepted = try await self.authenticate(authentication)
                guard accepted, self.generation == ticket, !Task.isCancelled else { return }
                let loaded = try await self.keychain.read(context: authentication)
                guard self.generation == ticket, !Task.isCancelled else { return }
                self.items = loaded
                self.isUnlocked = true
                self.touch()
            } catch {
                guard self.generation == ticket, !Task.isCancelled else { return }
                self.context?.invalidate()
                self.context = nil
                self.core.showMessage(String(localized: "Could not unlock Secure Items"), tone: .danger)
            }
        }
    }

    func lock(clearClipboard: Bool = false) {
        generation = UUID()
        isShowingSettings = false
        operation?.cancel()
        context?.invalidate()
        context = nil
        idle?.cancel()
        idle = nil
        items = []
        draft = nil
        revealedID = nil
        isUnlocked = false
        if clearClipboard { clipboard.clearIfOwned() }
        if core.palette.mode == .secureItemEditor { core.palette.replace(mode: .secureItems) }
        if core.palette.mode == .secureItems { core.palette.query = "" }
    }

    private func observeIdleTimeout() {
        withObservationTracking {
            _ = core.settings.secureItemsIdleSeconds
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.touch()
                self.observeIdleTimeout()
            }
        }
    }

    func touch() {
        guard isUnlocked else { return }
        idle?.cancel()
        let seconds = SecureItemsTiming.idleSeconds(core.settings.secureItemsIdleSeconds)
        let waitForIdle = waitForIdle
        idle = Task { [weak self] in
            do { try await waitForIdle(seconds) } catch { return }
            self?.lock()
        }
    }

    func edit(_ item: SecureItem?) {
        guard isUnlocked, !isBusy else { return }
        touch()
        revealedID = nil
        editorField = 0
        draft = item ?? SecureItem(name: "", value: "")
        core.palette.replace(mode: .secureItemEditor)
    }

    func cancelEditing() {
        draft = nil
        core.palette.replace(mode: .secureItems)
        touch()
    }

    func updateDraft(name: String? = nil, value: String? = nil) {
        guard isUnlocked, !isBusy else { return }
        if let name { draft?.name = name }
        if let value { draft?.value = value }
        touch()
    }

    func save() {
        guard let draft, draft.isValid else { return }
        var next = items.filter { $0.id != draft.id }
        next.append(draft)
        commit(next)
    }

    func delete(_ item: SecureItem) {
        guard isUnlocked, !isBusy else { return }
        let ticket = generation
        Task { [weak self] in
            guard let self else { return }
            let approved = await self.core.confirm(
                title: String(localized: "Delete secure item?"),
                message: String(localized: "This cannot be undone."), symbol: "lock",
                confirmTitle: String(localized: "Delete"), tone: .danger, confirmRole: .destructive)
            guard approved, self.generation == ticket, self.isUnlocked else { return }
            self.commit(self.items.filter { $0.id != item.id })
        }
    }

    func copyText(_ text: String) {
        clipboard.copy(text, clearAfter: core.settings.secureItemsClipboardSeconds)
        touch()
    }

    func updateTags(_ text: String) {
        guard !isBusy, draft != nil else { return }
        draft?.tags = SecureItem.normalizedTags(text)
        touch()
    }

    func copy(_ item: SecureItem) {
        guard isUnlocked, !isBusy, items.contains(where: { $0.id == item.id }) else { return }
        touch()
        copyText(item.value)
        core.showMessage(String(localized: "Copied"))
        core.paletteCoordinator.hidePalette()
    }

    func reveal(_ item: SecureItem) {
        guard isUnlocked, !isBusy else { return }
        touch()
        revealedID = revealedID == item.id ? nil : item.id
    }

    private func commit(_ next: [SecureItem]) {
        guard isUnlocked, !isBusy, let context else { return }
        let ticket = generation
        isBusy = true
        touch()
        operation = Task { [weak self] in
            guard let self else { return }
            defer { self.isBusy = false; self.operation = nil }
            do {
                try await self.keychain.write(next, context: context)
                guard self.generation == ticket, !Task.isCancelled else { return }
                self.items = next
                self.revealedID = nil
                self.cancelEditing()
                self.core.showMessage(String(localized: "Saved"))
            } catch {
                guard self.generation == ticket, !Task.isCancelled else { return }
                self.core.showMessage(String(localized: "Could not save Secure Items"), tone: .danger)
            }
        }
    }
}
