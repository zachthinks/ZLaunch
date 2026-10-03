import QuartzCore
import SwiftUI

struct ExtensionStoreScreen: PaletteScreen {
    struct Row: Identifiable {
        let listing: ExtensionListing
        let section: String
        var id: String { section + ":" + listing.name }
    }

    static let categories = [
        "AI Extensions", "Applications", "Communication", "Data", "Documentation", "Design Tools",
        "Developer Tools", "Finance", "Fun", "Media", "News", "Productivity", "Security", "System", "Web", "Other"
    ]
    private static let categoryWidth: CGFloat = 190
    let session: ExtensionStoreSession
    let coordinator: ExtensionCoordinator
    let vm: PaletteState
    let openCategories: () -> Void
    let openActions: () -> Void

    private var isDetail: Bool { vm.mode == .extensionStoreDetail }
    var hidesSearchField: Bool { isDetail }
    var footerLabel: AnyView? { AnyView(ExtensionStoreFooterLabel()) }
    var rows: [Row] {
        if isDetail { return session.detail.map { [Row(listing: $0, section: "Details")] } ?? [] }
        return session.featured.map { Row(listing: $0, section: "Featured") }
            + session.trending.map { Row(listing: $0, section: "Trending") }
            + session.listings.map { Row(listing: $0, section: vm.query.isEmpty ? "All Extensions" : "Results") }
    }

    var primaryActionTitle: String {
        guard isDetail, let listing = session.detail else { return "Show Details" }
        if let progress = session.installing[listing.name] { return progress }
        if coordinator.installedNames.contains(listing.name) { return "Installed" }
        if !coordinator.extensionsEnabled { return "Enable Extensions" }
        return session.installFailures[listing.name] == nil ? "Install Extension" : "Retry Install"
    }

    func hasPrimaryAction(at selection: Int) -> Bool {
        guard rows.indices.contains(selection) else { return false }
        guard isDetail else { return true }
        let name = rows[selection].listing.name
        return session.installing[name] == nil && !coordinator.installedNames.contains(name)
    }

    func activate(at selection: Int) {
        guard rows.indices.contains(selection) else { return }
        let listing = rows[selection].listing
        if isDetail {
            if !coordinator.extensionsEnabled { coordinator.setExtensionsEnabled(true); return }
            coordinator.installSelectedStoreExtension(listing)
        } else {
            coordinator.showStoreDetail(listing)
        }
    }

    func secondary(at selection: Int) -> Bool {
        guard rows.indices.contains(selection) else { return false }
        let listing = rows[selection].listing
        guard coordinator.extensionsEnabled, !coordinator.installedNames.contains(listing.name),
            session.installing[listing.name] == nil else { return false }
        coordinator.installSelectedStoreExtension(listing)
        return true
    }

    func headerAccessory(at selection: Int, focus: FocusState<String?>.Binding) -> PaletteHeaderAccessory? {
        guard !isDetail else { return nil }
        return PaletteHeaderAccessory(
            width: Self.categoryWidth, fieldNames: [], firstIncompleteField: nil,
            placement: .besideSearchField,
            view: AnyView(ExtensionStoreCategoryButton(title: session.category ?? "All Categories", action: openCategories)))
    }

    func body(selection: Int, scroll: ScrollIntent) -> AnyView {
        if isDetail, let listing = session.detail {
            return AnyView(ExtensionStoreDetail(
                listing: listing, loading: session.loadingDetail,
                failure: session.installFailures[listing.name] ?? session.detailFailure))
        }
        return AnyView(ExtensionStoreListView(
            rows: rows, selection: selection, scroll: scroll, session: session,
            installed: coordinator.installedNames,
            onSelect: { vm.selection = $0 }, onActivate: activate,
            onActions: { vm.selection = $0; openActions() }))
    }

    func actions(at selection: Int) -> PopoverMenuContent? {
        guard rows.indices.contains(selection) else { return nil }
        let listing = rows[selection].listing
        var items: [PopoverMenuItem] = []
        if !isDetail {
            items.append(PopoverMenuItem(title: "Show Details", systemImage: "info.circle", shortcut: "↵") {
                coordinator.showStoreDetail(listing)
            })
        }
        if coordinator.extensionsEnabled, !coordinator.installedNames.contains(listing.name),
            session.installing[listing.name] == nil {
            items.append(PopoverMenuItem(
                title: "Install Extension", systemImage: "arrow.down.circle", shortcut: isDetail ? "↵" : "⌘↵"
            ) {
                coordinator.installSelectedStoreExtension(listing)
            })
        }
        for (title, url) in [("View on Raycast", listing.storeURL), ("View Source Code", listing.sourceURL)] {
            if let url, url.scheme == "https" {
                items.append(PopoverMenuItem(title: title, systemImage: "arrow.up.right.square") {
                    AppLauncher.open(url)
                })
            }
        }
        return PopoverMenuContent(header: listing.title, items: items)
    }

    func menuContent(
        at selection: Int, searchQuery: ActionMenuSearchQuery, menuSelection: Binding<Int>,
        onActivate: @escaping (Int) -> Void
    ) -> PaletteMenuContent? {
        guard let content = actions(at: selection) else { return nil }
        let filtered = content.matching(searchQuery)
        let items = filtered.content.items.map { item in
            let symbol: String
            if case .symbol(let name) = item.icon { symbol = name } else { symbol = "arrow.up.right.square" }
            return ExtensionActionItem(title: item.title, icon: .init(source: .symbol(symbol)), shortcut: item.shortcut)
        }
        return PaletteMenuContent(
            rowCount: items.count, preferredSelection: filtered.bestMatch,
            view: { _ in AnyView(ExtensionActionsPanel(
                header: content.header, items: items, selection: menuSelection, onActivate: onActivate)) },
            activate: { filtered.content.items[$0].action() },
            clipPath: { bounds, metrics, _ in
                RoundedRectangle(cornerRadius: metrics.radius.menuPanel).path(in: bounds).cgPath
            }, motion: ExtensionMenuMotion.panel)
    }

    func categoryMenu(
        searchQuery: ActionMenuSearchQuery, selection: Binding<Int>, onActivate: @escaping (Int) -> Void
    ) -> PaletteMenuContent {
        let choices = (["All Categories"] + Self.categories).filter { searchQuery.score($0) != nil }
        let items = choices.map { ExtensionPickerItem(value: $0, title: $0) }
        return PaletteMenuContent(
            rowCount: choices.count,
            view: { _ in AnyView(ExtensionPickerList(
                items: items, selection: selection.wrappedValue,
                chosen: [session.category ?? "All Categories"], assetsPath: nil,
                width: ExtensionSearchAccessoryButton.listWidth, searchPlaceholder: "Search categories…",
                onSelect: onActivate, onHighlight: { selection.wrappedValue = $0 })) },
            activate: { index in
                session.category = choices[index] == "All Categories" ? nil : choices[index]
                vm.selection = 0
                session.search(vm.query, debounce: false)
            },
            clipPath: { bounds, metrics, _ in
                RoundedRectangle(cornerRadius: metrics.radius.menuPanel).path(in: bounds).cgPath
            }, motion: ExtensionMenuMotion.panel)
    }
}

private struct ExtensionStoreCategoryButton: View {
    let title: String
    let action: () -> Void
    @Environment(\.metrics) private var metrics

    var body: some View {
        BarButton(chrome: .rounded, action: action) {
            HStack(spacing: metrics.spacing.sm) {
                Text(title).font(metrics.typography.bar).lineLimit(1)
                Image(systemName: "chevron.down").font(metrics.typography.disclosure)
            }
            .foregroundStyle(Theme.Colors.textSecondary)
        }
        .help("Filter categories  ⌘P")
    }
}

private struct ExtensionStoreFooterLabel: View {
    @Environment(\.metrics) private var metrics

    var body: some View {
        HStack(spacing: metrics.spacing.sm) {
            SymbolImage(name: "ZLaunchStore", size: metrics.size.rowIcon)
            Text("Store")
        }
            .font(metrics.typography.rowTrailing)
            .foregroundStyle(Theme.Colors.textSecondary)
    }
}
