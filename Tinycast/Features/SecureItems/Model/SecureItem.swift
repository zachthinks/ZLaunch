import Foundation

struct SecureItem: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var value: String
    var tags: [String]

    init(id: UUID = UUID(), name: String, value: String, tags: [String] = []) {
        self.id = id
        self.name = name
        self.value = value
        self.tags = tags
    }

    init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        id = try fields.decode(UUID.self, forKey: .id)
        name = try fields.decode(String.self, forKey: .name)
        value = try fields.decode(String.self, forKey: .value)
        tags = try fields.decodeIfPresent([String].self, forKey: .tags) ?? []
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !value.isEmpty
            && name.utf8.count <= 512 && value.utf8.count <= 65_536
            && tags.count <= 20 && tags.allSatisfy { !$0.isEmpty && $0.utf8.count <= 64 }
    }

    func matches(_ query: String) -> Bool {
        let searchable = ([name] + tags).joined(separator: " ")
        return query.split(whereSeparator: \.isWhitespace).allSatisfy {
            searchable.localizedStandardContains(String($0))
        }
    }

    static func normalizedTags(_ text: String) -> [String] {
        var seen: Set<String> = []
        return text.split(separator: ",").compactMap {
            let tag = $0.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !tag.isEmpty, seen.insert(tag.lowercased()).inserted else { return nil }
            return tag
        }
    }
}

enum SecureItemsTiming {
    static let idleOptions = [30, 60, 120, 300, 600, 900, 1800, 7_200, 21_600]
    static let clipboardOptions = [15, 30, 60, 120, 300]
    static func idleSeconds(_ value: Int) -> Int { idleOptions.contains(value) ? value : 120 }
    static func clipboardSeconds(_ value: Int) -> Int { clipboardOptions.contains(value) ? value : 30 }
}
