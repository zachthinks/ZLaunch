import SwiftUI

/// A narrow composition point for arrangements, Spaces and the spatial display map.
struct WindowLayoutPreview: View {
    let draft: WindowLayoutDraft
    let screens: [WindowLayoutScreen]
    let gap: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            WindowLayoutArrangementControls(draft: draft, screens: screens)
            spaceTabs
            WindowLayoutDisplayMap(draft: draft, screens: screens, gap: gap)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if let entry = draft.selectedEntry {
                Text(entry.fallbackSpace.map { "Fallback: \(entry.fallbackDisplay?.name ?? "Built-in screen, or first available") · Space \($0)" }
                     ?? "Fallback: none")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(unknownDisplays, id: \.uuid) { display in
                Button("\(display.name) · offline, no saved geometry") { draft.select(displayUUID: display.uuid) }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("Drag a window to place it; drag its corner to resize.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var unknownDisplays: [WindowLayoutDisplay] {
        draft.tabs(connected: screens.map(\.display)).filter { display in
            !screens.contains { $0.display.uuid == display.uuid }
                && !draft.displaySnapshots.contains { $0.id == display.uuid.lowercased() }
        }
    }

    private var spaceTabs: some View {
        let screen = screens.first { $0.display.uuid == draft.selectedDisplayUUID }
        let saved = draft.displaySnapshots.first { $0.display.uuid == draft.selectedDisplayUUID }
        let stored = draft.entries(onDisplay: draft.selectedDisplayUUID ?? "").compactMap(\.space)
        let count = max(1, min(32, screen?.desktopIDs.count ?? saved?.desktopCount ?? 0))
        let numbers = Set(stored + Array(1...count)).sorted()
        return ScrollView(.horizontal) {
            HStack(spacing: Theme.Spacing.sm) {
                spaceTab(nil, title: "Current")
                ForEach(numbers, id: \.self) { number in
                    spaceTab(number, title: "Space \(number)\(number > count ? " · unavailable" : "")")
                }
            }
        }
        .scrollIndicators(.hidden)
        .accessibilityLabel("Preview Space")
    }

    private func spaceTab(_ number: Int?, title: String) -> some View {
        Button { draft.selectPreviewSpace(number) } label: {
            Text(title)
                .font(.caption.weight(draft.previewSpace == number ? .semibold : .regular))
                .padding(Theme.Spacing.sm)
                .background(draft.previewSpace == number ? Theme.Colors.selection : Color.clear,
                            in: RoundedRectangle(cornerRadius: Theme.Radius.menu))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(draft.previewSpace == number ? .isSelected : [])
    }
}
