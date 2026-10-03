import Foundation

enum PaletteStyle: String, CaseIterable, Identifiable, Sendable {
    case glass
    case classic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .glass: "Original Glass"
        case .classic: "Raycast Classic"
        }
    }
}
