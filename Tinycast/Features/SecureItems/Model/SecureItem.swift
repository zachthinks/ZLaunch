import Foundation

struct SecureItem: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var name: String
    var value: String

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !value.isEmpty
            && name.utf8.count <= 512 && value.utf8.count <= 65_536
    }
}
