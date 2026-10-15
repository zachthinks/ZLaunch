import AppKit
import SwiftUI

/// Pointer interactions stay local to each tile; geometry policy remains in the model.
struct WindowLayoutMapTile: View {
    let entry: WindowLayoutEntry
    let selected: Bool
    let rect: CGRect
    let isOffline: Bool
    let select: () -> Void
    let preview: (CGSize, WindowLayoutInteraction.Handle) -> CGRect
    let commit: (CGSize, WindowLayoutInteraction.Handle) -> Void
    @Environment(AppIndex.self) private var appIndex
    @State private var operation: WindowLayoutInteraction.Handle?
    @State private var previewFrame: CGRect?

    var body: some View {
        let app = AppPresentation.resolve(bundleID: entry.bundleID, in: appIndex)
        let shown = previewFrame ?? rect
        GeometryReader { proxy in
            Button(action: select) {
                RoundedRectangle(cornerRadius: Theme.Radius.thumbnail)
                    .fill(selected ? Theme.Colors.layoutPreviewWindowSelected : Theme.Colors.layoutPreviewWindow)
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.thumbnail)
                        .stroke(selected ? Color.accentColor : Theme.Colors.border))
                    .overlay {
                        Image(nsImage: app.icon).resizable()
                            .frame(width: Theme.Size.layoutPreviewIcon, height: Theme.Size.layoutPreviewIcon)
                            .allowsHitTesting(false)
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .highPriorityGesture(DragGesture(minimumDistance: 3, coordinateSpace: .global)
                .onChanged { value in
                    if operation == nil {
                        let origin = proxy.frame(in: .global).origin
                        operation = WindowLayoutInteraction.handle(
                            at: CGPoint(x: value.startLocation.x - origin.x, y: value.startLocation.y - origin.y),
                            size: rect.size)
                        select()
                    }
                    guard let operation else { return }
                    cursor(operation).set()
                    previewFrame = preview(value.translation, operation)
                }
                .onEnded { value in
                    if let operation { commit(value.translation, operation) }
                    operation = nil
                    previewFrame = nil
                    NSCursor.arrow.set()
                })
            .onContinuousHover(coordinateSpace: .local) { phase in
                switch phase {
                case .active(let point):
                    cursor(operation ?? WindowLayoutInteraction.handle(at: point, size: shown.size)).set()
                case .ended: if operation == nil { NSCursor.arrow.set() }
                }
            }
        }
        .frame(width: max(1, shown.width), height: max(1, shown.height))
        .opacity(isOffline ? 0.6 : 1)
        .offset(x: shown.minX, y: shown.minY)
        .zIndex(selected ? 2 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(app.name) window")
        .accessibilityHint("Drag to move; drag any edge or corner to resize; press Delete to remove")
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityAction { select() }
        .onDisappear { NSCursor.arrow.set() }
    }

    private func cursor(_ handle: WindowLayoutInteraction.Handle) -> NSCursor {
        let position: NSCursor.FrameResizePosition
        switch handle {
        case .move: return operation == nil ? .openHand : .closedHand
        case .left: position = .left
        case .right: position = .right
        case .top: position = .top
        case .bottom: position = .bottom
        case .topLeft: position = .topLeft
        case .topRight: position = .topRight
        case .bottomLeft: position = .bottomLeft
        case .bottomRight: position = .bottomRight
        }
        return .frameResize(position: position, directions: .all)
    }
}
