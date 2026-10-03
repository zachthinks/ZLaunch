import SwiftUI

struct ExtensionStoreDetail: View {
    let listing: ExtensionListing
    let loading: Bool
    let failure: String?
    @Environment(\.isDarkAppearance) private var isDark
    @Environment(\.metrics) private var metrics
    private static let iconSide: CGFloat = 64
    private static let sidebarWidth: CGFloat = 210

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: metrics.spacing.xxl) {
                HStack(spacing: metrics.spacing.xxl) {
                    ExtensionIconView(resolved: listing.iconURL(isDark: isDark).map {
                        .init(source: .remote($0))
                    }, size: metrics.scaled(Self.iconSide))
                    VStack(alignment: .leading, spacing: metrics.spacing.xl) {
                        Text(listing.title).font(.title2.weight(.semibold)).textSelection(.enabled)
                        HStack(spacing: metrics.spacing.xl) {
                            ExtensionIconView(resolved: listing.authorAvatarURL.map { .init(source: .remote($0)) },
                                size: metrics.size.rowIcon)
                                .clipShape(Circle())
                            Text(listing.author)
                            if let downloads = listing.downloadCount {
                                Text("·").foregroundStyle(.tertiary)
                                Label("\(downloads.formatted()) Installs", systemImage: "arrow.down.circle")
                            }
                        }
                        .font(metrics.typography.rowTrailing).foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
                if loading { ProgressView().controlSize(.small) }
                if let failure {
                    Text(failure).font(metrics.typography.rowTrailing).foregroundStyle(.orange)
                }
                if !listing.screenshots.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: metrics.spacing.xl) {
                            ForEach(listing.screenshots, id: \.self) { url in
                                ExtensionStoreScreenshot(url: url)
                            }
                        }
                    }
                    .scrollIndicators(.never)
                }
                HStack(alignment: .top, spacing: metrics.spacing.xxl) {
                    VStack(alignment: .leading, spacing: metrics.spacing.xl) {
                        heading("Description")
                        Text(listing.summary).font(metrics.typography.rowTitle).textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        heading("Commands")
                        ForEach(Array(listing.commands.enumerated()), id: \.offset) { _, command in
                            VStack(alignment: .leading, spacing: metrics.spacing.sm) {
                                Text(command.title).font(metrics.typography.rowTitle)
                                if !command.summary.isEmpty {
                                    Text(command.summary).font(metrics.typography.rowTrailing)
                                        .foregroundStyle(Theme.Colors.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.bottom, metrics.spacing.xl)
                        }
                        heading("ZLaunch compatibility")
                        Text("Raycast AI, browser and window services, and its OAuth proxy, are not supported.")
                            .font(metrics.typography.rowTrailing).foregroundStyle(Theme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: metrics.spacing.xl) {
                        if let url = listing.readmeURL, url.scheme == "https" {
                            heading("README")
                            Link("Open README ↗", destination: url)
                        }
                        if let date = listing.updatedAt {
                            heading("Last update")
                            Text(date, style: .relative).foregroundStyle(Theme.Colors.textSecondary)
                        }
                        if !listing.contributors.isEmpty {
                            heading("Contributors")
                            ForEach(listing.contributors, id: \.self) { Text($0).lineLimit(1) }
                        }
                        if let url = listing.sourceURL, url.scheme == "https" {
                            heading("Source Code")
                            Link("View Code ↗", destination: url)
                        }
                    }
                    .font(metrics.typography.rowTrailing)
                    .frame(width: metrics.scaled(Self.sidebarWidth), alignment: .leading)
                }
            }
            .padding(metrics.spacing.xxl)
            .hideNativeScrollers()
            .scrollOriginAnchor()
        }
        .edgeDissolve()
        .thinScrollbar()
    }

    private func heading(_ text: String) -> some View {
        Text(text).font(metrics.typography.rowTrailing).foregroundStyle(Theme.Colors.textSecondary)
            .padding(.top, metrics.spacing.md)
    }
}

private struct ExtensionStoreScreenshot: View {
    let url: URL
    @Environment(\.metrics) private var metrics
    @State private var loaded: NSImage?
    @State private var loading = true
    private static let width: CGFloat = 224
    private static let height: CGFloat = 140

    var body: some View {
        Group {
            if let loaded {
                Image(nsImage: loaded).resizable().scaledToFit()
            } else if loading {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: "photo").foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .frame(width: metrics.scaled(Self.width), height: metrics.scaled(Self.height))
        .background(Theme.Colors.controlSurface, in: RoundedRectangle(cornerRadius: metrics.radius.row))
        .clipShape(RoundedRectangle(cornerRadius: metrics.radius.row))
        .task(id: url) {
            loading = true
            loaded = await ExtensionIconCache.loadRemoteAsync(url, asIcon: false)
            loading = false
        }
        .accessibilityLabel("Extension screenshot")
    }
}
