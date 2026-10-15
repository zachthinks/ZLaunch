import CoreGraphics
import Foundation

/// Affine map between AX desktop coordinates and the editor; one scale preserves relative sizes.
struct WindowLayoutMapGeometry {
    let bounds: CGRect
    let scale: CGFloat
    let origin: CGPoint

    init(frames: [CGRect], canvas: CGSize) {
        bounds = frames.reduce(CGRect.null) { $0.union($1) }
        let usable = !bounds.isNull && bounds.width > 0 && bounds.height > 0
        scale = usable ? max(0.001, min(canvas.width / bounds.width, canvas.height / bounds.height)) : 1
        origin = usable ? CGPoint(x: (canvas.width - bounds.width * scale) / 2,
                                  y: (canvas.height - bounds.height * scale) / 2) : .zero
    }

    func map(_ frame: CGRect) -> CGRect {
        CGRect(x: origin.x + (frame.minX - bounds.minX) * scale,
               y: origin.y + (frame.minY - bounds.minY) * scale,
               width: frame.width * scale, height: frame.height * scale)
    }

    func desktopPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: bounds.minX + (point.x - origin.x) / scale,
                y: bounds.minY + (point.y - origin.y) / scale)
    }
}

extension WindowLayoutScreen {
    var snapshot: WindowLayoutDisplaySnapshot {
        WindowLayoutDisplaySnapshot(display: display, frame: screen.frame,
                                    visibleFrame: screen.visibleFrame, desktopCount: desktopIDs.count)
    }
}
