import Foundation

struct ShortcutPaletteRepository: Sendable {
    let directory: URL

    var configurationURL: URL { directory.appending(path: "shortcuts.json") }
    var actionsURL: URL { directory.appending(path: "available-actions.json") }

    func load() throws -> ShortcutPaletteConfiguration {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: configurationURL.path) {
            try encode(ShortcutPaletteConfiguration.starter).write(to: configurationURL, options: .atomic)
        }
        let data = try Data(contentsOf: configurationURL)
        guard data.count <= 256_000 else {
            throw ShortcutPaletteConfiguration.Issue(message: "shortcuts.json must be smaller than 256 KB.")
        }
        let configuration = try JSONDecoder().decode(ShortcutPaletteConfiguration.self, from: data)
        try configuration.validate()
        return configuration
    }

    func save(_ configuration: ShortcutPaletteConfiguration) throws {
        try configuration.validate()
        let data = try encode(configuration)
        guard data.count <= 256_000 else {
            throw ShortcutPaletteConfiguration.Issue(message: "This menu is too large to save.")
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: configurationURL, options: .atomic)
    }

    func exportActions(_ actions: [Action]) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try encode(actions).write(to: actionsURL, options: .atomic)
    }

    struct Action: Codable, Sendable {
        let label: String
        let action: String
    }

    private func encode(_ value: some Encodable) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }
}
