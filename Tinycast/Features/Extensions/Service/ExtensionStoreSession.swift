import Foundation
import Observation

@MainActor
@Observable
final class ExtensionStoreSession {
    private(set) var listings: [ExtensionListing] = []
    private(set) var loading = false
    private(set) var failure: String?
    private(set) var hasMore = false
    private(set) var featured: [ExtensionListing] = []
    private(set) var trending: [ExtensionListing] = []
    private(set) var discoveryFailure: String?
    private(set) var detail: ExtensionListing?
    private(set) var detailFailure: String?
    private(set) var loadingDetail = false
    private(set) var installing: [String: String] = [:]
    private(set) var installFailures: [String: String] = [:]
    var category: String?
    @ObservationIgnored private var detailTask: Task<Void, Never>?
    @ObservationIgnored private var installTasks: [String: Task<Void, Never>] = [:]
    private var query = ""
    private var page = 0
    private var generation = UUID()
    @ObservationIgnored private var task: Task<Void, Never>?
    private let client: ExtensionStoreClient

    init(client: ExtensionStoreClient = ExtensionStoreClient()) {
        self.client = client
    }

    isolated deinit {
        task?.cancel()
        detailTask?.cancel()
        for task in installTasks.values { task.cancel() }
    }

    func search(_ value: String, debounce: Bool = true) {
        let requested = ExtensionStoreResponse.scopedQuery(
            value.trimmingCharacters(in: .whitespacesAndNewlines), category: category)
        guard requested != query || (page == 0 && !loading) else { return }
        stop()
        query = requested
        featured = []
        trending = []
        discoveryFailure = nil
        listings = []
        page = 0
        hasMore = false
        failure = nil
        loading = true
        load(debounce: debounce)
    }

    func loadMore() {
        guard !loading, hasMore else { return }
        loading = true
        failure = nil
        load(debounce: false)
    }

    func retry() {
        guard !loading else { return }
        loading = true
        failure = nil
        load(debounce: false)
    }

    func stop() {
        task?.cancel()
        task = nil
        generation = UUID()
        loading = false
    }

    func showDetail(_ listing: ExtensionListing) {
        detailTask?.cancel()
        detail = listing
        detailFailure = nil
        loadingDetail = true
        let client = client
        detailTask = Task { [weak self] in
            do {
                let result = try await client.lookup(handle: listing.ownerHandle, name: listing.name)
                guard !Task.isCancelled, let self, self.detail?.name == listing.name else { return }
                if let result { self.detail = result }
                self.loadingDetail = false
            } catch {
                guard !Task.isCancelled, let self, self.detail?.name == listing.name else { return }
                self.detailFailure = error.localizedDescription
                self.loadingDetail = false
            }
        }
    }

    func install(_ listing: ExtensionListing, coordinator: ExtensionCoordinator) {
        guard installing[listing.name] == nil else { return }
        installing[listing.name] = "Downloading…"
        installFailures[listing.name] = nil
        let client = client
        installTasks[listing.name] = Task { [weak self] in
            do {
                guard let fresh = try await client.lookup(handle: listing.ownerHandle, name: listing.name) else {
                    throw ExtensionStoreError.rejected("This extension is no longer available in the Store.")
                }
                try await coordinator.installStoreExtension(fresh) { [weak self] progress in
                    Task { @MainActor [weak self] in
                        guard self?.installing[listing.name] != nil else { return }
                        self?.installing[listing.name] = progress.message
                    }
                }
            } catch {
                self?.installFailures[listing.name] = error.localizedDescription
            }
            self?.installing[listing.name] = nil
            self?.installTasks[listing.name] = nil
        }
    }

    private func load(debounce: Bool) {
        let token = generation
        let nextPage = page + 1
        let requestedQuery = query
        let client = client
        task = Task { [weak self] in
            do {
                if debounce { try await Task.sleep(for: .milliseconds(350)) }
                async let requestedPage = client.page(query: requestedQuery, number: nextPage)
                var curated: ([ExtensionListing], [ExtensionListing]) = ([], [])
                var discoveryError: String?
                if nextPage == 1, requestedQuery.isEmpty {
                    do {
                        async let featured = client.curated("featured")
                        async let trending = client.curated("trending")
                        curated = try await (featured, trending)
                    } catch {
                        discoveryError = error.localizedDescription
                    }
                }
                let result = try await requestedPage
                guard !Task.isCancelled, let self, self.generation == token else { return }
                if nextPage == 1 {
                    self.featured = curated.0
                    self.trending = curated.1
                    self.discoveryFailure = discoveryError
                }
                var names = Set(self.listings.map(\.name))
                self.listings += result.listings.filter { names.insert($0.name).inserted }
                self.page = nextPage
                self.hasMore = result.hasMore
                self.loading = false
            } catch {
                guard !Task.isCancelled, let self, self.generation == token else { return }
                self.failure = error.localizedDescription
                self.loading = false
            }
        }
    }
}
