import Foundation

/// Someone else's endpoint, so every field an install doesn't need is optional.
enum ExtensionStoreResponse {
    struct Page: Sendable {
        let listings: [ExtensionListing]
        let hasMore: Bool
    }

    static func browseURL(page: Int) -> URL? {
        var components = URLComponents(string: "https://www.raycast.com/api/v1/store_listings")
        components?.queryItems = [
            URLQueryItem(name: "platform", value: "macOS"),
            URLQueryItem(name: "page", value: String(page))
        ]
        return components?.url
    }

    static func scopedQuery(_ query: String, category: String?) -> String {
        guard let category else { return query }
        return "category:\"\(category)\" \(query)".trimmingCharacters(in: .whitespaces)
    }

    /// The endpoint the store's own site searches with; unofficial, so it can change unannounced.
    static func searchURL(query: String, page: Int) -> URL? {
        var components = URLComponents(string: "https://www.raycast.com/frontend_api/extensions/search")
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "page", value: String(page)),
            // Case-sensitive: any other spelling returns only extensions listing no platforms.
            URLQueryItem(name: "platform", value: "macOS")
        ]
        return components?.url
    }

    /// One extension by the handle and name its manifest carries.
    static func lookupURL(handle: String, name: String) -> URL? {
        guard !handle.isEmpty, !name.isEmpty else { return nil }
        return URL(string: "https://www.raycast.com/api/v1/extensions")?
            .appending(path: handle)
            .appending(path: name)
    }

    private struct StorePayload: Decodable {
        let data: [StoreEntry]
        let totalResults: Int?

        enum CodingKeys: String, CodingKey {
            case data
            case totalResults = "total_results"
        }
    }

    private struct StoreEntry: Decodable {
        let id: String
        let name: String
        let title: String?
        let description: String?
        let author: Author?
        let icons: Icons?
        let commands: [Command]?
        let downloadCount: Int?
        let downloadURL: String?
        let commitSHA: String?
        let status: String?
        let categories: [String]?
        let storeURL: String?
        let sourceURL: String?
        let readmeURL: String?
        let owner: Author?
        let metadata: [String]?
        let contributors: [Author]?
        let updatedAt: Double?
        let platforms: [String]?

        struct Author: Decodable {
            let name: String?
            let handle: String?
            let avatar: String?
        }
        struct Icons: Decodable {
            let light: String?
            let dark: String?
        }
        struct Command: Decodable {
            let name: String?
            let title: String?
            let description: String?
        }

        enum CodingKeys: String, CodingKey {
            case id, name, title, description, author, icons, commands, status, categories
            case owner, metadata, contributors, platforms
            case downloadCount = "download_count"
            case downloadURL = "download_url"
            case commitSHA = "commit_sha"
            case storeURL = "store_url"
            case sourceURL = "source_url"
            case readmeURL = "readme_url"
            case updatedAt = "updated_at"
        }
    }

    static func parseStore(_ data: Data) throws -> [ExtensionListing] {
        try JSONDecoder().decode(StorePayload.self, from: data).data.compactMap(listing(from:))
    }

    static func parsePage(_ data: Data, page: Int, browsing: Bool) throws -> Page {
        let payload = try JSONDecoder().decode(StorePayload.self, from: data)
        let pageSize = browsing ? 25 : 10
        let hasMore = payload.totalResults.map { page * pageSize < $0 }
            ?? (payload.data.count == pageSize)
        return Page(listings: payload.data.compactMap(listing(from:)), hasMore: hasMore)
    }

    /// A lookup answers with the entry itself, not a page of them.
    static func parseEntry(_ data: Data) throws -> ExtensionListing? {
        listing(from: try JSONDecoder().decode(StoreEntry.self, from: data))
    }

    /// An entry without a usable download is dropped, not listed as uninstallable.
    private static func listing(from entry: StoreEntry) -> ExtensionListing? {
        // A de-listed extension is still returned by search; it can't be downloaded any more.
        guard entry.status == nil || entry.status == "active" else { return nil }
        guard entry.platforms == nil || entry.platforms?.isEmpty == true || entry.platforms?.contains("macOS") == true
        else { return nil }
        guard let raw = entry.downloadURL, let url = URL(string: raw) else { return nil }
        return ExtensionListing(
            id: entry.id,
            name: entry.name,
            title: entry.title ?? entry.name,
            summary: entry.description ?? "",
            author: entry.author?.name ?? entry.author?.handle ?? "",
            lightIconURL: entry.icons?.light.flatMap(URL.init(string:)),
            darkIconURL: entry.icons?.dark.flatMap(URL.init(string:)),
            commandCount: entry.commands?.count ?? 0,
            downloadCount: entry.downloadCount,
            downloadURL: url,
            commitSHA: entry.commitSHA,
            commands: (entry.commands ?? []).compactMap { command in
                guard let name = command.name else { return nil }
                return .init(name: name, title: command.title ?? name, summary: command.description ?? "")
            },
            categories: entry.categories ?? [],
            storeURL: entry.storeURL.flatMap(URL.init(string:)),
            sourceURL: entry.sourceURL.flatMap(URL.init(string:)),
            readmeURL: entry.readmeURL.flatMap(URL.init(string:)),
            ownerHandle: entry.owner?.handle ?? entry.author?.handle ?? "",
            authorAvatarURL: entry.author?.avatar.flatMap(URL.init(string:)),
            screenshots: (entry.metadata ?? []).compactMap(URL.init(string:)),
            contributors: (entry.contributors ?? []).compactMap { $0.name ?? $0.handle },
            updatedAt: entry.updatedAt.map(Date.init(timeIntervalSince1970:)))
    }
}

enum ExtensionStoreError: LocalizedError {
    case malformedResponse
    case rejected(String)
    case downloadFailed(String)
    case noPackageManager
    case noNode
    case buildFailed(String)
    case notAnExtension

    var errorDescription: String? {
        switch self {
        case .malformedResponse:
            return "The server answered with something this version doesn't understand."
        case .rejected(let message):
            return message
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        case .noPackageManager:
            return
                "No package manager was found. Install pnpm, npm, Yarn or Bun, or add the folder "
                + "it lives in to Custom search paths."
        case .noNode:
            return
                "Node wasn't found. Install Node.js, add the folder it lives in to Custom search "
                + "paths, or install this extension from the Raycast Store instead."
        case .buildFailed(let output):
            return "The extension didn't build: \(output)"
        case .notAnExtension:
            return "That download didn't contain a Raycast extension."
        }
    }
}
