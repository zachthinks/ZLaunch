import Foundation

/// Optional layout metadata shares the native Codable schema; runtime handles never leave it.
enum WindowLayoutArrangementFile {
    static func json<T: Encodable>(_ value: T) -> SettingsFileJSON {
        guard let data = try? JSONEncoder().encode(value),
            let object = try? JSONSerialization.jsonObject(with: data)
        else { return .null }
        return SettingsFileJSON(jsonObject: object)
    }

    static func decode<T: Decodable>(_ type: T.Type, from value: SettingsFileJSON) -> T? {
        guard let data = try? JSONSerialization.data(withJSONObject: object(value)) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func portable(_ arrangements: [WindowLayoutArrangement]) -> [WindowLayoutArrangement] {
        arrangements.map { arrangement in
            var value = arrangement
            for index in value.entries.indices {
                value.entries[index].terminalWindowID = nil
                value.entries[index].terminalSession = nil
            }
            return value
        }
    }

    private static func object(_ value: SettingsFileJSON) -> Any {
        switch value {
        case .null: return NSNull()
        case .bool(let value): return value
        case .number(let value): return value
        case .string(let value): return value
        case .array(let values): return values.map(object)
        case .object(let members): return Dictionary(uniqueKeysWithValues: members.map { ($0.key, object($0.value)) })
        }
    }
}
