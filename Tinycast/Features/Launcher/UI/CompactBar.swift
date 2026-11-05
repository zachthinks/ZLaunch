import SwiftUI

private typealias BarMotion = Theme.CompactBarMotion

/// Where the capsule ends and each button rests, in a compact window exactly as wide as the panel.
struct CompactBarGeometry {
    let width: CGFloat
    let height: CGFloat
    let diameter: CGFloat
    let gap: CGFloat
    let count: Int

    init(metrics: InterfaceMetrics, count: Int) {
        width = metrics.size.panelWidth
        height = metrics.size.compactHeight
        // A point inside the bar's height, so the last button clears the window's rounded end.
        diameter = height - metrics.scaled(1) * 2
        gap = metrics.spacing.lg
        self.count = count
    }

    func capsuleWidth(revealed: Bool) -> CGFloat {
        revealed ? width - CGFloat(count) * (diameter + gap) : width
    }

    func center(of index: Int) -> CGPoint {
        CGPoint(
            x: capsuleWidth(revealed: true) + gap + diameter / 2 + CGFloat(index) * (diameter + gap),
            y: height / 2)
    }

    /// Just inside the shortened capsule's end, so the capsule pulling back uncovers each button.
    var parked: CGPoint {
        CGPoint(x: capsuleWidth(revealed: true) - diameter / 2, y: height / 2)
    }
}

struct CompactBar: View {
    let style: PaletteStyle
    let commands: [CommandID]
    let selection: CommandID?
    let onRun: (CommandID) -> Void
    @Environment(PaletteState.self) private var palette
    @Environment(\.metrics) private var metrics
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRevealed = false

    var body: some View {
        let geometry = CompactBarGeometry(metrics: metrics, count: commands.count)
        let revealed = isRevealed
        Group {
            if style == .classic {
                surfaces(geometry: geometry, revealed: revealed)
            } else {
                GlassEffectContainer(spacing: metrics.scaled(BarMotion.blend)) {
                    surfaces(geometry: geometry, revealed: revealed)
                }
            }
        }
        // Above the glass rather than inside it, where a morph would smear them.
        .overlay(alignment: .topLeading) {
            ForEach(Array(commands.enumerated()), id: \.element) { index, command in
                glyph(command, at: index, geometry: geometry, revealed: revealed)
            }
        }
        .task(id: palette.isVisible) { await followVisibility() }
    }

    private func surfaces(geometry: CompactBarGeometry, revealed: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            searchSurface
                .frame(width: geometry.capsuleWidth(revealed: revealed))
                .frame(maxHeight: .infinity)
                .animation(
                    reduceMotion ? nil : BarMotion.capsule.delay(BarMotion.revealDelay),
                    value: revealed)
            ForEach(Array(commands.enumerated()), id: \.element) { index, command in
                button(command, at: index, geometry: geometry, revealed: revealed)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var searchSurface: some View {
        if style == .classic {
            RoundedRectangle(cornerRadius: metrics.scaled(Theme.Radius.classicPanel), style: .continuous)
                .fill(Theme.Colors.classicBarSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: metrics.scaled(Theme.Radius.classicPanel), style: .continuous)
                        .strokeBorder(Theme.Colors.border, lineWidth: Theme.Size.hairline)
                }
        } else {
            Capsule(style: .continuous).fill(.clear)
                .glassEffect(.regular, in: Capsule(style: .continuous))
        }
    }

    @ViewBuilder
    private func shortcutSurface(_ content: some View, selected: Bool) -> some View {
        if style == .classic {
            content.background {
                let shape = RoundedRectangle(cornerRadius: metrics.radius.barControl, style: .continuous)
                shape.fill(Theme.Colors.classicBarSurface)
                    .overlay { shape.fill(selected ? Theme.Colors.selection : .clear) }
                    .overlay { shape.strokeBorder(Theme.Colors.border, lineWidth: Theme.Size.hairline) }
            }
        } else {
            content.glassEffect(
                .regular.tint(selected ? Theme.Colors.compactShortcutSelectionTint : nil)
                    .interactive(), in: .circle)
        }
    }

    private func button(
        _ command: CommandID, at index: Int, geometry: CompactBarGeometry, revealed: Bool
    ) -> some View {
        let content = Button {
            onRun(command)
        } label: {
            Color.clear
                .frame(width: geometry.diameter, height: geometry.diameter)
                .contentShape(RoundedRectangle(
                    cornerRadius: style == .classic ? metrics.radius.barControl : geometry.diameter / 2,
                    style: .continuous))
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(command.name)
        .accessibilityLabel(command.name)
        .accessibilityAddTraits(selection == command ? [.isSelected] : [])
        .accessibilityHidden(!revealed)
        return shortcutSurface(content, selected: selection == command)
        .scaleEffect(revealed ? 1 : BarMotion.parkedScale)
        .position(revealed ? geometry.center(of: index) : geometry.parked)
        .allowsHitTesting(revealed)
        .animation(travel(index), value: revealed)
    }

    private func glyph(
        _ command: CommandID, at index: Int, geometry: CompactBarGeometry, revealed: Bool
    ) -> some View {
        SymbolImage(
            name: command.sfSymbol, size: metrics.scaled(Theme.Typography.headerIconSize),
            monochrome: selection == command
        )
        .environment(\.symbolVariants, .none)
        .foregroundStyle(
            selection == command
                ? (style == .classic ? Theme.Colors.textPrimary : Theme.Colors.compactShortcutSelectedInk)
                : Theme.Colors.textSecondary
        )
        .animation(fade(index)) {
            $0.opacity(revealed ? 1 : 0).blur(radius: revealed ? 0 : BarMotion.glyphBlur)
        }
        // Shrinks with its circle but never travels: glyphs sent home would pile into one blot.
        .animation(travel(index)) {
            $0.scaleEffect(revealed ? 1 : BarMotion.parkedScale)
        }
        .position(geometry.center(of: index))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func travel(_ index: Int) -> Animation? {
        guard !reduceMotion else { return nil }
        return BarMotion.button.delay(BarMotion.revealDelay + BarMotion.stagger * Double(index))
    }

    private func fade(_ index: Int) -> Animation? {
        guard !reduceMotion else { return nil }
        return .easeOut(duration: BarMotion.glyphFade)
            .delay(BarMotion.revealDelay + BarMotion.glyphDelay + BarMotion.stagger * Double(index))
    }

    /// Out on every summon, and parked only once the window has faded, so leaving fades it whole.
    private func followVisibility() async {
        guard !palette.isVisible else {
            isRevealed = true
            return
        }
        try? await Task.sleep(for: .seconds(Motion.duration(BarMotion.parkAfterHide)))
        guard !Task.isCancelled else { return }
        withTransaction(\.disablesAnimations, true) { isRevealed = false }
    }
}
