import AppKit
import SwiftUI

@MainActor
@Observable
final class ShortcutPaletteCoordinator: NSObject, NSWindowDelegate {
    private(set) var navigation = ShortcutPaletteNavigation(configuration: .starter)
    private(set) var message: String?
    private(set) var isVisible = false
    private var isReady = false
    @ObservationIgnored private var panel: ShortcutPalettePanel?
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var executionTask: Task<Void, Never>?
    @ObservationIgnored private var activationTask: Task<Void, Never>?
    private let editorWindow: AppWindowController
    private let hotKeys: HotKeyManager
    private let repository: ShortcutPaletteRepository
    private let entries: () -> [AppEntry]
    private let launch: (AppEntry) -> Void
    private let beforeShow: () -> Void
    private let restoreFocus: () -> Void
    private let prepareExecution: @MainActor (AppEntry) async -> Bool
    private let reportFailure: (String) -> Void
    private let confirmDiscard: (String) async -> Bool
    private let confirmRemoval: (String) async -> Bool

    init(
        repository: ShortcutPaletteRepository, hotKeys: HotKeyManager, activation: ActivationPolicy,
        entries: @escaping () -> [AppEntry],
        launch: @escaping (AppEntry) -> Void, beforeShow: @escaping () -> Void,
        restoreFocus: @escaping () -> Void, prepareExecution: @escaping @MainActor (AppEntry) async -> Bool,
        confirmDiscard: @escaping (String) async -> Bool,
        confirmRemoval: @escaping (String) async -> Bool,
        reportFailure: @escaping (String) -> Void
    ) {
        self.repository = repository
        self.hotKeys = hotKeys
        editorWindow = AppWindowController(
            title: "LaunchDeck Setup", contentSize: CGSize(width: 940, height: 640),
            minimumSize: CGSize(width: 820, height: 560), resizable: true,
            activation: activation)
        self.entries = entries
        self.launch = launch
        self.beforeShow = beforeShow
        self.restoreFocus = restoreFocus
        self.prepareExecution = prepareExecution
        self.reportFailure = reportFailure
        self.confirmDiscard = confirmDiscard
        self.confirmRemoval = confirmRemoval
    }

    func toggle() {
        executionTask?.cancel()
        executionTask = nil
        if isVisible {
            if navigation.configuration.repeatTriggerResets == true {
                navigation = ShortcutPaletteNavigation(configuration: navigation.configuration)
                message = nil
                resizePanel()
            } else {
                close(restoringFocus: true)
            }
            return
        }
        beforeShow()
        navigation = ShortcutPaletteNavigation(configuration: navigation.configuration)
        message = "Loading shortcuts…"
        isReady = false
        isVisible = true
        let panel = ensurePanel()
        updatePanelSurface()
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        let frame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1000, height: 800)
        let layout = layout(for: frame.size)
        let size = NSSize(width: layout.width, height: layout.height)
        let panelFrame = navigation.configuration.displayMode?.isFloating == true
            ? layout.floatingFrame(in: frame, topMarginFraction: Theme.Size.paletteTopMarginFraction)
            : NSRect(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2,
                     width: size.width, height: size.height)
        panel.setFrame(panelFrame, display: false)
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(panel)
        activationTask = Task { [weak self, weak panel] in
            await Task.yield()
            guard !Task.isCancelled, let self, isVisible, let panel else { return }
            NSApp.activate()
            panel.makeKeyAndOrderFront(nil)
            panel.makeFirstResponder(panel)
            activationTask = nil
        }
        loadTask = Task { [weak self, repository] in
            let result = await Task.detached { Result { try repository.load() } }.value
            guard !Task.isCancelled, let self, isVisible else { return }
            switch result {
            case .success(let configuration):
                navigation = ShortcutPaletteNavigation(configuration: configuration)
                message = nil
                isReady = true
                resizePanel()
            case .failure(let error):
                message = "Couldn’t load shortcuts: \(error.localizedDescription) Open Configure to repair the menu."
            }
            loadTask = nil
        }
    }

    func select(_ key: String) {
        guard isReady else { return }
        handle(navigation.select(key))
    }

    func choose(_ key: String) {
        guard isReady else { return }
        handle(navigation.choose(key))
    }

    func escape() { handle(navigation.escape()) }

    private func handle(_ result: ShortcutPaletteNavigation.Result) {
        switch result {
        case .ignored: break
        case .navigated:
            message = navigation.pendingKey.isEmpty ? nil
                : "\(navigation.pendingKey.uppercased()) … Type the next key. Escape or Delete clears it."
            resizePanel()
        case .unmatched:
            message = "No matching sequence. Try again."
            resizePanel()
        case .close: close(restoringFocus: true)
        case .action(let id):
            let destination: AppEntry?
            if let url = ShortcutPaletteConfiguration.websiteURL(for: id) {
                destination = CommandCatalog.makeEntry(.openInBrowser, url: url)
            } else { destination = availableEntries.first(where: { $0.id == id }) }
            guard let entry = destination else {
                message = "This action is unavailable or disabled. Choose another, or edit the group."
                return
            }
            close(restoringFocus: false)
            executionTask = Task { [weak self] in
                guard let self else { return }
                let restored = await prepareExecution(entry)
                guard !Task.isCancelled else { return }
                if restored { launch(entry) } else {
                    reportFailure("Couldn’t restore the previous app. No action was run.")
                }
                executionTask = nil
            }
        }
    }

    private var availableEntries: [AppEntry] {
        entries().filter {
            $0.id != CommandID.shortcutPalette.rawValue
                && $0.id != CommandID.editShortcutPalette.rawValue
                && $0.id != CommandID.quit.rawValue
        }
    }

    func close(restoringFocus: Bool) {
        guard isVisible else { return }
        isVisible = false
        isReady = false
        loadTask?.cancel()
        loadTask = nil
        activationTask?.cancel()
        activationTask = nil
        panel?.orderOut(nil)
        if restoringFocus { restoreFocus() }
    }

    func editConfiguration() {
        close(restoringFocus: true)
        editorWindow.show {
            ShortcutPaletteEditorView(
                repository: repository, actions: availableEntries, confirmDiscard: confirmDiscard,
                confirmRemoval: confirmRemoval,
                registerCloseHandler: { [weak editorWindow] in editorWindow?.onCloseRequested = $0 },
                closeEditor: { [weak editorWindow] in editorWindow?.close() },
                preview: { [weak self] in self?.toggle() })
                .shortcutRecorderPopoverHost()
                .environment(hotKeys)
        }
    }

    func application(for item: ShortcutPaletteConfiguration.Item) -> AppEntry? {
        guard item.children == nil, let action = item.action else { return nil }
        return entries().first { $0.id == action && $0.kind == .application }
    }

    var presentationLayout: ShortcutPaletteLayout { layout() }

    private func layout(for size: CGSize? = nil) -> ShortcutPaletteLayout {
        ShortcutPaletteLayout(
            mode: navigation.configuration.displayMode, size: navigation.configuration.tileSize,
            itemCount: navigation.items.count, isRoot: navigation.isRoot,
            availableSize: size ?? panel?.screen?.visibleFrame.size ?? NSScreen.main?.visibleFrame.size
                ?? CGSize(width: 1000, height: 800), showsMessage: message != nil)
    }

    private func resizePanel() {
        guard let panel else { return }
        updatePanelSurface()
        let layout = layout()
        let height = layout.height
        var frame = panel.frame
        let width = layout.width
        frame.origin.x += (frame.width - width) / 2
        if navigation.configuration.displayMode?.isFloating == true {
            if let screen = panel.screen?.visibleFrame {
                frame.origin.y = layout.floatingFrame(
                    in: screen, topMarginFraction: Theme.Size.paletteTopMarginFraction).minY
            } else { frame.origin.y += (frame.height - height) / 2 }
        } else {
            frame.origin.y += frame.height - height
        }
        frame.size = NSSize(width: width, height: height)
        if let screen = panel.screen?.visibleFrame {
            frame.origin.x = max(screen.minX, min(frame.origin.x, screen.maxX - frame.width))
            frame.origin.y = max(screen.minY, min(frame.origin.y, screen.maxY - frame.height))
        }
        panel.setFrame(frame, display: true)
    }

    private func updatePanelSurface() {
        let floating = navigation.configuration.displayMode?.isFloating == true
        panel?.isOpaque = !floating
        panel?.backgroundColor = floating ? .clear : .windowBackgroundColor
        panel?.hasShadow = !floating
    }

    private func ensurePanel() -> ShortcutPalettePanel {
        if let panel { return panel }
        let panel = ShortcutPalettePanel(
            contentRect: .zero, styleMask: [.borderless],
            backing: .buffered, defer: false)
        panel.title = "LaunchDeck"
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.isFloatingPanel = true
        panel.animationBehavior = .none
        panel.isOpaque = true
        panel.backgroundColor = .windowBackgroundColor
        panel.hasShadow = true
        panel.delegate = self
        panel.onKey = { [weak self] event in
            guard let self, !event.isARepeat else { return }
            let modifiers = event.modifierFlags.intersection([.command, .control, .option])
            guard modifiers.isEmpty else { return }
            if event.keyCode == 53 { escape(); return }
            if event.keyCode == 51 || event.keyCode == 117 { handle(navigation.clearPending()); return }
            if let key = event.charactersIgnoringModifiers { select(key) }
        }
        let hosting = NSHostingView(rootView: ShortcutPaletteView().environment(self))
        hosting.sizingOptions = []
        panel.contentView = hosting
        self.panel = panel
        return panel
    }

    func windowDidResignKey(_ notification: Notification) { close(restoringFocus: false) }

    isolated deinit {
        executionTask?.cancel()
        loadTask?.cancel()
        activationTask?.cancel()
    }
}
