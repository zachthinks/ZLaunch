import SwiftUI

struct ExtensionStoreListView: View {
    let rows: [ExtensionStoreScreen.Row]
    let selection: Int
    let scroll: ScrollIntent
    let session: ExtensionStoreSession
    let installed: Set<String>
    let onSelect: (Int) -> Void
    let onActivate: (Int) -> Void
    let onActions: (Int) -> Void
    @Environment(\.metrics) private var metrics

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        if index == 0 || rows[index - 1].section != row.section {
                            Text(row.section)
                                .font(metrics.typography.rowTrailing)
                                .foregroundStyle(Theme.Colors.textSecondary)
                                .padding(.horizontal, metrics.spacing.xl)
                                .padding(.top, metrics.spacing.xl)
                                .padding(.bottom, metrics.spacing.md)
                        }
                        ExtensionStoreRow(
                            listing: row.listing, selected: index == selection,
                            installed: installed.contains(row.listing.name), progress: session.installing[row.listing.name])
                            .contentShape(Rectangle())
                            .onTapGesture { onSelect(index); onActivate(index) }
                            .onRightClick { onActions(index) }
                            .selectionFrame(index == selection)
                            .id(row.id)
                    }
                    if session.loading {
                        ProgressView().frame(maxWidth: .infinity).padding(metrics.spacing.xxl)
                    } else if let failure = session.failure ?? session.discoveryFailure {
                        VStack(spacing: metrics.spacing.md) {
                            Text(failure).font(metrics.typography.rowTrailing).foregroundStyle(.secondary)
                            Button("Try Again") { session.retry() }
                        }
                        .frame(maxWidth: .infinity).padding(metrics.spacing.xxl)
                    } else if rows.isEmpty {
                        EmptyResults(text: "No extensions found")
                    } else if session.hasMore {
                        Button("Load More") { session.loadMore() }
                            .buttonStyle(.plain).font(metrics.typography.rowTrailing)
                            .frame(maxWidth: .infinity).padding(metrics.spacing.xl)
                    }
                }
                .padding(.horizontal, metrics.spacing.md)
                .padding(.bottom, metrics.spacing.md)
                .hideNativeScrollers()
                .scrollOriginAnchor()
            }
            .edgeDissolve()
            .thinScrollbar()
            .scrollFollowsSelection(
                scroll, row: rows.indices.contains(selection) ? rows[selection].id : nil,
                atOrigin: selection == 0, proxy: proxy)
            .onChange(of: selection) {
                if selection >= rows.count - 3 { session.loadMore() }
            }
        }
    }
}

private struct ExtensionStoreRow: View {
    let listing: ExtensionListing
    let selected: Bool
    let installed: Bool
    let progress: String?
    @Environment(\.metrics) private var metrics
    @Environment(\.isDarkAppearance) private var isDark
    @Environment(PaletteState.self) private var palette
    @State private var hovered = false
    private static let height: CGFloat = 58

    var body: some View {
        HStack(spacing: metrics.spacing.xl) {
            ExtensionIconView(resolved: listing.iconURL(isDark: isDark).map {
                .init(source: .remote($0))
            }, size: metrics.size.rowIcon)
            VStack(alignment: .leading, spacing: metrics.spacing.xs) {
                Text(listing.title).font(metrics.typography.rowTitle).lineLimit(1)
                Text(listing.summary).font(metrics.typography.rowTrailing)
                    .foregroundStyle(Theme.Colors.textSecondary).lineLimit(1)
            }
            Spacer(minLength: metrics.spacing.xl)
            if installed {
                Image(systemName: "checkmark.circle").foregroundStyle(Theme.Colors.textSecondary)
                    .help("Installed in ZLaunch")
            }
            if let progress {
                ProgressView().controlSize(.small).help(progress)
            }
            if let downloads = listing.downloadCount {
                Label(ExtensionListing.abbreviate(downloads), systemImage: "arrow.down.circle")
                    .font(metrics.typography.rowTrailing).foregroundStyle(Theme.Colors.textSecondary)
                    .help("\(downloads.formatted()) installs")
            }
            ExtensionIconView(resolved: listing.authorAvatarURL.map { .init(source: .remote($0)) },
                size: metrics.size.rowIcon)
                .clipShape(Circle()).help(listing.author)
        }
        .padding(.horizontal, metrics.spacing.xl)
        .frame(height: metrics.scaled(Self.height))
        .background(
            selected ? Theme.Colors.selection : (hovered ? Theme.Colors.rowHover : .clear),
            in: RoundedRectangle(cornerRadius: metrics.radius.row))
        .onHover { hovered = $0 && palette.hoverHighlightArmed }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
