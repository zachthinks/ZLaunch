import AppKit
import SwiftUI

/// The display map is an editor only; every gesture ends in a pure draft update.
struct WindowLayoutDisplayMap: View {
    let draft: WindowLayoutDraft
    let screens: [WindowLayoutScreen]
    let gap: CGFloat
    @FocusState private var mapFocused: Bool

    private var displays: [WindowLayoutDisplaySnapshot] {
        var result = screens.map(\.snapshot)
        for saved in draft.displaySnapshots where !result.contains(where: { $0.id == saved.id }) {
            if saved.isValid { result.append(saved) }
        }
        return result
    }

    var body: some View {
        GeometryReader { proxy in
            let geometry = WindowLayoutMapGeometry(frames: displays.map(\.frame), canvas: proxy.size)
            ZStack(alignment: .topLeading) {
                ForEach(displays) { display in
                    displayPlate(display, rect: geometry.map(display.frame))
                    let screen = WindowPlacementEngine.Screen(id: 0, frame: display.frame, visibleFrame: display.visibleFrame)
                    ForEach(draft.previewEntries(onDisplay: display.display.uuid)) { entry in
                        if let frame = WindowLayoutGeometry.resolve(entry, on: screen, gap: gap) {
                            WindowLayoutMapTile(entry: entry, selected: entry.id == draft.selectedEntryID,
                                rect: geometry.map(frame), isOffline: !isConnected(display)) {
                                    draft.select(entryID: entry.id)
                                    mapFocused = true
                                } commit: { translation, resizing in
                                    commit(entry, frame: frame, translation: translation,
                                           resizing: resizing, geometry: geometry)
                                }
                        }
                    }
                    displayCaption(display, rect: geometry.map(display.frame))
                }
            }
        }
        .focusable()
        .focused($mapFocused)
        .onKeyPress(keys: [.delete, .deleteForward], phases: .down) { press in
            guard press.modifiers.isEmpty, draft.selectedEntryID != nil else { return .ignored }
            draft.removeSelectedEntry()
            return .handled
        }
        .onDeleteCommand { draft.removeSelectedEntry() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Display map, \(draft.previewSpace.map { "Space \($0)" } ?? "Current Space")")
    }

    private func isConnected(_ display: WindowLayoutDisplaySnapshot) -> Bool {
        screens.contains { $0.display.uuid.lowercased() == display.id }
    }

    private func displayPlate(_ display: WindowLayoutDisplaySnapshot, rect: CGRect) -> some View {
        Button { draft.select(displayUUID: display.display.uuid) } label: {
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Theme.Colors.layoutPreviewGround)
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .stroke(draft.selectedDisplayUUID == display.display.uuid ? Color.accentColor : Theme.Colors.border))
                .opacity(isConnected(display) ? 1 : 0.45)
                .frame(width: rect.width, height: rect.height)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Display \(display.display.name)\(isConnected(display) ? "" : ", offline, last saved geometry")")
        .offset(x: rect.minX, y: rect.minY)
    }

    private func displayCaption(_ display: WindowLayoutDisplaySnapshot, rect: CGRect) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(display.display.name).font(.caption.weight(.semibold))
            Text("\(Int(display.frame.width)) × \(Int(display.frame.height))\(isConnected(display) ? "" : " · offline, last saved")")
                .font(.caption2)
        }
        .lineLimit(1)
        .padding(Theme.Spacing.sm)
        .background(Theme.Colors.controlSurface.opacity(0.8))
        .frame(width: rect.width, alignment: .leading)
        .offset(x: rect.minX, y: rect.minY)
        .zIndex(3)
        .allowsHitTesting(false)
    }

    private func commit(_ entry: WindowLayoutEntry, frame: CGRect, translation: CGSize,
                        resizing: Bool, geometry: WindowLayoutMapGeometry) {
        let delta = CGSize(width: translation.width / geometry.scale, height: translation.height / geometry.scale)
        var changed = resizing
            ? CGRect(origin: frame.origin, size: CGSize(width: max(40, frame.width + delta.width),
                                                       height: max(40, frame.height + delta.height)))
            : frame.offsetBy(dx: delta.width, dy: delta.height)
        let center = CGPoint(x: changed.midX, y: changed.midY)
        guard let target = displays.first(where: { $0.frame.contains(center) }) else { return }
        let screen = WindowPlacementEngine.Screen(id: 0, frame: target.frame, visibleFrame: target.visibleFrame)
        let box = WindowLayoutGeometry.box(screen, gap: gap)
        changed.size.width = min(max(changed.width, box.width * 0.05), box.width)
        changed.size.height = min(max(changed.height, box.height * 0.05), box.height)
        changed.origin.x = min(max(changed.minX, box.minX), box.maxX - changed.width)
        changed.origin.y = min(max(changed.minY, box.minY), box.maxY - changed.height)
        draft.select(entryID: entry.id)
        draft.placeSelected(frame: changed, display: target.display,
                            capture: WindowLayoutGeometry.describe(changed, on: screen, gap: gap))
        mapFocused = true
    }
}

/// Selection stays keyed by entry UUID, so repeated instances of one app remain independent.
private struct WindowLayoutMapTile: View {
    let entry: WindowLayoutEntry
    let selected: Bool
    let rect: CGRect
    let isOffline: Bool
    let select: () -> Void
    let commit: (CGSize, Bool) -> Void
    @Environment(AppIndex.self) private var appIndex
    @State private var translation: CGSize = .zero
    @State private var resizing = false

    var body: some View {
        let app = AppPresentation.resolve(bundleID: entry.bundleID, in: appIndex)
        Button(action: select) {
            RoundedRectangle(cornerRadius: Theme.Radius.thumbnail)
                .fill(selected ? Theme.Colors.layoutPreviewWindowSelected : Theme.Colors.layoutPreviewWindow)
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.thumbnail)
                    .stroke(selected ? Color.accentColor : Theme.Colors.border))
                .overlay { Image(nsImage: app.icon).resizable().frame(width: Theme.Size.layoutPreviewIcon, height: Theme.Size.layoutPreviewIcon) }
                .frame(width: max(20, rect.width + (resizing ? translation.width : 0)),
                       height: max(20, rect.height + (resizing ? translation.height : 0)))
        }
        .buttonStyle(.plain)
        .highPriorityGesture(drag(resize: false))
        .overlay(alignment: .bottomTrailing) {
            if selected {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption2)
                    .padding(Theme.Spacing.sm)
                    .background(Theme.Colors.controlSurface)
                    .contentShape(Rectangle())
                    .highPriorityGesture(drag(resize: true))
                    .accessibilityLabel("Resize selected window")
            }
        }
        .opacity(isOffline ? 0.6 : 1)
        .offset(x: rect.minX + (resizing ? 0 : translation.width),
                y: rect.minY + (resizing ? 0 : translation.height))
        .zIndex(selected ? 2 : 1)
        .accessibilityLabel("\(app.name) window")
        .accessibilityHint("Drag to place, drag the bottom-right handle to resize, or press Delete to remove")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func drag(resize: Bool) -> some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .global)
            .onChanged { value in resizing = resize; translation = value.translation }
            .onEnded { value in
                commit(value.translation, resize)
                translation = .zero
                resizing = false
            }
    }
}
