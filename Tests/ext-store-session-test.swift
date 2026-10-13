import Foundation

struct ExtensionInstaller {
    enum Progress: Sendable {
        case installing
        var message: String { "Installing…" }
    }
}

struct ExtensionStoreClient: Sendable {
    static let listing = ExtensionListing(
        id: "test", name: "test", title: "Test Extension", summary: "", author: "test",
        lightIconURL: nil, darkIconURL: nil, commandCount: 1, downloadCount: nil,
        downloadURL: URL(string: "https://example.com/test.zip")!, commitSHA: "test")

    func lookup(handle: String, name: String) async throws -> ExtensionListing? { Self.listing }
    func page(query: String, number: Int) async throws -> ExtensionStoreResponse.Page {
        .init(listings: [], hasMore: false)
    }
    func curated(_ section: String) async throws -> [ExtensionListing] { [] }
}

@MainActor
final class ExtensionCoordinator {
    var installedNames: Set<String> = []
    var starts = 0
    var reports: [String] = []
    var pending: CheckedContinuation<Void, Error>?

    func installStoreExtension(
        _ listing: ExtensionListing,
        onProgress: @Sendable @escaping (ExtensionInstaller.Progress) -> Void
    ) async throws {
        starts += 1
        onProgress(.installing)
        try await withCheckedThrowingContinuation { pending = $0 }
        installedNames.insert(listing.name)
    }

    func reportStoreInstall(_ listing: ExtensionListing, failure: String? = nil) {
        reports.append(failure ?? "success")
    }

    func finish(failing: Bool) {
        let continuation = pending
        pending = nil
        if failing {
            continuation?.resume(throwing: ExtensionStoreError.rejected("Download interrupted"))
        } else {
            continuation?.resume()
        }
    }
}

@main
@MainActor
struct ExtensionStoreSessionTests {
    static func expect(_ condition: Bool, _ message: String) {
        guard condition else { fatalError(message) }
    }

    static func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<200 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        fatalError("Timed out waiting for Store installation state")
    }

    static func main() async throws {
        let session = ExtensionStoreSession()
        let coordinator = ExtensionCoordinator()
        let listing = ExtensionStoreClient.listing
        session.install(listing, coordinator: coordinator)
        expect(session.installing[listing.name] == "Downloading…", "Immediate progress must be visible")
        session.install(listing, coordinator: coordinator)
        try await waitUntil { session.installing[listing.name] == "Installing…" }
        expect(coordinator.starts == 1, "Repeated Return must not start a second installation")
        coordinator.finish(failing: true)
        try await waitUntil { session.installing.isEmpty }
        expect(session.installFailures[listing.name] != nil, "Failure must survive after progress clears")
        expect(coordinator.reports.count == 1, "Failure must notify once")
        expect(coordinator.installedNames.isEmpty, "Failed installation must not become Installed")

        session.install(listing, coordinator: coordinator)
        expect(session.installFailures.isEmpty, "Retry must clear the previous failure")
        try await waitUntil { coordinator.pending != nil }
        coordinator.finish(failing: false)
        try await waitUntil { session.installing.isEmpty }
        expect(coordinator.installedNames.contains(listing.name), "Success must become Installed")
        expect(coordinator.reports.last == "success", "Success must notify")
        session.install(listing, coordinator: coordinator)
        expect(session.installing.isEmpty, "An installed extension must not download again")
        expect(coordinator.starts == 2, "Only the first attempt and retry should run")
        print("Store progress, failure, retry, success and duplicate guards passed")
    }
}
