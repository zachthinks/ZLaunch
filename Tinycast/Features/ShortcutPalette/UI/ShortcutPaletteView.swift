import SwiftUI

struct ShortcutPaletteView: View {
    @Environment(ShortcutPaletteCoordinator.self) private var coordinator

    @State private var hoveredKey: String?
    private var isFloating: Bool { coordinator.navigation.configuration.displayMode == .floatingTiles }

    var body: some View {
        Group {
            if isFloating { floatingBody } else { panelBody }
        }
    }

    private var panelBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                if !coordinator.navigation.isRoot {
                    Text(coordinator.navigation.title.components(separatedBy: " › ").dropLast().joined(separator: "  /  "))
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Text(coordinator.navigation.title.components(separatedBy: " › ").last ?? "LaunchDeck")
                    .font(.title2.weight(.semibold)).lineLimit(2)
                    .accessibilityAddTraits(.isHeader)
            }
            Divider()
            if coordinator.navigation.configuration.displayMode == .grid {
                ScrollView { tiles(coordinator.presentationLayout) }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(coordinator.navigation.items) { item in
                            choice(item, tiled: false)
                        }
                    }
                }
            }
            if let message = coordinator.message {
                Text(message).font(.callout).foregroundStyle(Theme.Colors.warning)
            }
            Divider()
            HStack {
                Button(coordinator.navigation.isRoot || coordinator.navigation.configuration.escapeClosesAll == true
                       ? "Esc  Close" : "Esc  Back") { coordinator.escape() }
                Spacer()
                Button("Configure…") { coordinator.editConfiguration() }
            }
            .font(.callout)
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.windowSurface)
    }

    private var floatingBody: some View {
        VStack(spacing: 8) {
            ScrollView { tiles(coordinator.presentationLayout).padding(24) }
            if let message = coordinator.message {
                Text(message).font(.callout)
                    .padding(10).modifier(FloatingShortcutSurface(radius: 8))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func tiles(_ layout: ShortcutPaletteLayout) -> some View {
        VStack(spacing: 16) {
            ForEach(0..<layout.rows, id: \.self) { row in
                HStack(spacing: 16) {
                    ForEach(Array(coordinator.navigation.items.dropFirst(row * layout.columns).prefix(layout.columns))) { item in
                        choice(item, tiled: true).frame(width: layout.tileEdge, height: layout.tileEdge)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func choice(_ item: ShortcutPaletteConfiguration.Item, tiled: Bool) -> some View {
        Button { coordinator.select(item.key) } label: {
            Group {
                if tiled {
                    VStack(spacing: 6) {
                        Text(item.key.uppercased())
                            .font(.system(size: coordinator.presentationLayout.tileEdge * 0.42,
                                          weight: .medium, design: .monospaced))
                            .lineLimit(1)
                        HStack(alignment: .top, spacing: 5) {
                            if let app = coordinator.application(for: item) {
                                AppIconView(app: app, pointSize: 16)
                                    .frame(width: 16, height: 16).accessibilityHidden(true)
                            }
                            Text(item.label)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center).lineLimit(2)
                        }
                        .frame(height: 34, alignment: .top)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .background {
                        if !isFloating { Theme.Colors.cardFill }
                    }
                    .modifier(FloatingShortcutSurface(radius: 10, enabled: isFloating))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(hoveredKey == item.id ? Color.primary.opacity(0.45)
                                : (isFloating ? Color.primary.opacity(0.22) : Theme.Colors.cardStroke),
                                          lineWidth: 1)
                    }
                    .clipShape(.rect(cornerRadius: 10))
                    .overlay(alignment: .topTrailing) {
                        if item.children != nil {
                            Image(systemName: "square.on.square")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary).padding(12)
                        }
                    }
                    .shadow(color: .black.opacity(isFloating ? 0.40 : 0.12),
                            radius: isFloating ? 12 : 1, x: 0, y: isFloating ? 8 : 1)
                    .shadow(color: .black.opacity(isFloating ? 0.22 : 0), radius: 2, x: 0, y: 2)
                } else {
                    HStack(spacing: 16) {
                        Text(item.key.uppercased())
                            .font(.system(.body, design: .monospaced).bold())
                            .frame(width: 30, height: 30)
                            .background(Theme.Colors.cardFill)
                            .clipShape(.rect(cornerRadius: 4))
                        Text(item.label).font(.body.weight(.medium)).lineLimit(2)
                        Spacer()
                        if item.children != nil { Text("›").foregroundStyle(.secondary) }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(hoveredKey == item.id ? Theme.Colors.cardFill : .clear)
                    .clipShape(.rect(cornerRadius: 6))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hoveredKey = $0 ? item.id : nil }
        .help(item.children == nil ? item.label : "Open \(item.label) group")
        .accessibilityLabel("\(item.key.uppercased()), \(item.label)")
        .accessibilityHint(item.children == nil ? "Run action" : "Open group")
    }

}

private struct FloatingShortcutSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var radius: CGFloat
    var enabled = true

    func body(content: Content) -> some View {
        if enabled {
            content
                .background {
                    if reduceTransparency {
                        Theme.Colors.windowSurface
                    } else {
                        Rectangle().fill(.regularMaterial)
                            .overlay(Theme.Colors.windowSurface.opacity(0.6))
                    }
                }
                .clipShape(.rect(cornerRadius: radius))
        } else { content }
    }
}
