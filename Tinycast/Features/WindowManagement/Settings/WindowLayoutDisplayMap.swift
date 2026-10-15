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
                                } preview: { translation, handle in
                                    geometry.map(placement(entry, on: display, frame: frame, translation: translation,
                                                           handle: handle, geometry: geometry).frame)
                                } commit: { translation, handle in
                                    commit(entry, on: display, frame: frame, translation: translation,
                                           handle: handle, geometry: geometry)
                                }
                        }
                    }
                    displayCaption(display, rect: geometry.map(display.frame))
                }
            }
        }
        .focusable()
        .focused($mapFocused)
        .focusEffectDisabled()
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
            Text("\(Int(display.frame.width)) × \(Int(display.frame.height))"
                 + (isConnected(display) ? "" : " · offline, last saved"))
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

    private func placement(_ entry: WindowLayoutEntry, on source: WindowLayoutDisplaySnapshot, frame: CGRect, translation: CGSize,
                           handle: WindowLayoutInteraction.Handle, geometry: WindowLayoutMapGeometry)
        -> (display: WindowLayoutDisplay, screen: WindowPlacementEngine.Screen, frame: CGRect) {
        let delta = CGSize(width: translation.width / geometry.scale, height: translation.height / geometry.scale)
        let center = CGPoint(x: frame.midX + delta.width, y: frame.midY + delta.height)
        let target = handle == .move ? displays.first { $0.frame.contains(center) } ?? source : source
        let screen = WindowPlacementEngine.Screen(id: 0, frame: target.frame, visibleFrame: target.visibleFrame)
        let proposed = WindowLayoutInteraction.proposed(frame, delta: delta, handle: handle,
                                                        bounds: WindowLayoutGeometry.box(screen, gap: gap))
        let neighbors = WindowLayoutInteraction.neighbors(of: entry, in: draft.entries,
                                                         displayID: target.display.uuid)
            .compactMap { WindowLayoutGeometry.resolve($0, on: screen, gap: gap) }
        if target.id != source.id {
            let rounded = WindowPlacementEngine.rounded(proposed)
            if neighbors.contains(where: { WindowLayoutInteraction.overlaps(rounded, $0) }) {
                return (source.display, .init(id: 0, frame: source.frame, visibleFrame: source.visibleFrame), frame)
            }
            return (target.display, screen, rounded)
        }
        return (target.display, screen,
                WindowLayoutInteraction.constrained(from: frame, to: proposed, neighbors: neighbors, handle: handle))
    }

    private func commit(_ entry: WindowLayoutEntry, on source: WindowLayoutDisplaySnapshot, frame: CGRect, translation: CGSize,
                        handle: WindowLayoutInteraction.Handle, geometry: WindowLayoutMapGeometry) {
        let result = placement(entry, on: source, frame: frame, translation: translation, handle: handle, geometry: geometry)
        draft.select(entryID: entry.id)
        draft.placeSelected(frame: result.frame, display: result.display,
                            capture: WindowLayoutGeometry.describe(result.frame, on: result.screen, gap: gap))
        mapFocused = true
    }
}
