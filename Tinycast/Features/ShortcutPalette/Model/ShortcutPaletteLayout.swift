import CoreGraphics
import Foundation

struct ShortcutPaletteLayout {
    let width: CGFloat
    let height: CGFloat
    let columns: Int
    let rows: Int
    let tileEdge: CGFloat
    let needsScrolling: Bool
    static let gap: CGFloat = 16

    func floatingFrame(in screen: CGRect, topMarginFraction: CGFloat) -> CGRect {
        let x = screen.midX - width / 2
        let top = screen.maxY - screen.height * topMarginFraction
        let y = max(screen.minY + 16, top - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    init(mode: ShortcutPaletteConfiguration.DisplayMode?, size: ShortcutPaletteConfiguration.TileSize?,
         itemCount: Int, isRoot: Bool, availableSize: CGSize, showsMessage: Bool = false) {
        let count = max(1, itemCount)
        let usableWidth = max(1, availableSize.width - 32)
        let usableHeight = max(1, availableSize.height - 32)
        let desiredEdge: CGFloat = switch size ?? .medium {
        case .small: 128
        case .medium: 160
        case .large: 192
        }
        let padding: CGFloat = mode == .floatingTiles ? 80 : 48
        tileEdge = min(desiredEdge, max(1, usableWidth - padding))
        if mode == nil || mode == .list {
            width = min(580, usableWidth)
            let desiredHeight = max(280, 156 + CGFloat(count) * 58 + (showsMessage ? 60 : 0))
            height = min(640, usableHeight, desiredHeight)
            columns = 1
            rows = count
            needsScrolling = height < desiredHeight
            return
        }
        let maximumColumns = max(1, Int((usableWidth - padding + Self.gap) / (tileEdge + Self.gap)))
        if mode == .floatingTiles {
            let requiredRows = (count + maximumColumns - 1) / maximumColumns
            columns = min(maximumColumns, (count + requiredRows - 1) / requiredRows)
        } else {
            columns = min(maximumColumns, min(4, max(1, Int(ceil(sqrt(Double(count)))))))
        }
        rows = (count + columns - 1) / columns
        width = min(usableWidth, max(320, padding + CGFloat(columns) * tileEdge + CGFloat(columns - 1) * Self.gap))
        let chrome: CGFloat = mode == .floatingTiles ? 80 : (isRoot ? 168 : 192)
        let desiredHeight = chrome + (showsMessage ? 60 : 0) + CGFloat(rows) * tileEdge + CGFloat(rows - 1) * Self.gap
        height = min(usableHeight, desiredHeight)
        needsScrolling = height < desiredHeight
    }
}
