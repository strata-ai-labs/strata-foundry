import Foundation

enum VectorPaneMode: String, CaseIterable {
    case lookup = "Lookup"
    case upsert = "Upsert"
    case search = "Search"
    case batch = "Batch"
}

struct VectorResultDisplay {
    let key: String
    let embedding: [Double]
    let metadata: String
    let version: Int
    let timestamp: Int64
}

struct VectorMatchDisplay: Identifiable {
    var id: String { key }
    let key: String
    let score: Double
    let metadataJSON: String
}

@Observable
final class VectorFeatureModel {
    private let vectorService: VectorService
    private let appState: AppState

    var collections: [CollectionInfo] = []
    var isLoading = false
    var errorMessage: String?
    var selectedCollection: String?

    // Create collection
    var showCreateSheet = false
    var showDeleteConfirm = false
    var formName = ""
    var formDimension = "384"
    var formMetric = "Cosine"

    // Right pane
    var paneMode: VectorPaneMode = .lookup
    var collectionStats: CollectionInfo?

    // Lookup
    var lookupKey = ""
    var lookupResult: VectorResultDisplay?
    var lookupError: String?
    var showFullEmbedding = false
    var showDeleteVectorConfirm = false

    // Upsert
    var upsertKey = ""
    var upsertVector = ""
    var upsertMetadata = ""
    var upsertSuccess: String?
    var upsertError: String?

    // Search
    var searchQuery = ""
    var searchK = "10"
    var searchFilter = ""
    var searchResults: [VectorMatchDisplay] = []
    var searchError: String?
    var selectedMatch: String?
    var isSearching = false

    // Batch
    var batchUpsertJSON = ""
    var batchUpsertSuccess: String?
    var batchUpsertError: String?

    var isTimeTraveling: Bool { appState.timeTravelDate != nil }

    init(vectorService: VectorService, appState: AppState) {
        self.vectorService = vectorService
        self.appState = appState
    }

    // MARK: - Collection Operations

    func loadCollections() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let branch = appState.selectedBranch
        let space: String? = appState.selectedSpace == "default" ? nil : appState.selectedSpace

        do {
            collections = try await vectorService.listCollections(branch: branch, space: space)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createCollection() async {
        guard let dim = UInt64(formDimension) else { return }
        let metric: DistanceMetric
        switch formMetric {
        case "Euclidean": metric = .euclidean
        case "DotProduct": metric = .dotProduct
        default: metric = .cosine
        }

        let branch = appState.selectedBranch
        let space: String? = appState.selectedSpace == "default" ? nil : appState.selectedSpace

        do {
            _ = try await vectorService.createCollection(collection: formName, dimension: dim, metric: metric, branch: branch, space: space)
            showCreateSheet = false
            await loadCollections()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dropCollection(_ name: String) async {
        let branch = appState.selectedBranch
        let space: String? = appState.selectedSpace == "default" ? nil : appState.selectedSpace

        do {
            _ = try await vectorService.deleteCollection(collection: name, branch: branch, space: space)
            if selectedCollection == name { selectedCollection = nil }
            await loadCollections()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadCollectionStats() async {
        guard let collName = selectedCollection else { return }
        let branch = appState.selectedBranch
        let space: String? = appState.selectedSpace == "default" ? nil : appState.selectedSpace

        do {
            collectionStats = try await vectorService.collectionStats(collection: collName, branch: branch, space: space)
        } catch {
            collectionStats = nil
        }
    }

    // MARK: - Vector Operations

    func vectorGet() async {
        guard let collName = selectedCollection else { return }
        lookupResult = nil
        lookupError = nil
        showFullEmbedding = false

        let branch = appState.selectedBranch
        let space: String? = appState.selectedSpace == "default" ? nil : appState.selectedSpace
        let asOf = asOfFromDate(appState.timeTravelDate)

        do {
            guard let vd = try await vectorService.get(collection: collName, key: lookupKey, branch: branch, space: space, asOf: asOf) else {
                lookupError = "Vector not found for key \"\(lookupKey)\""
                return
            }

            var metadataStr = "{}"
            if let meta = vd.data.metadata {
                metadataStr = meta.prettyJSON
            }

            lookupResult = VectorResultDisplay(
                key: vd.key,
                embedding: vd.data.embedding.map { Double($0) },
                metadata: metadataStr,
                version: Int(vd.version),
                timestamp: Int64(vd.timestamp)
            )
        } catch {
            lookupError = error.localizedDescription
        }
    }

    func vectorDelete() async {
        guard let collName = selectedCollection else { return }
        let branch = appState.selectedBranch
        let space: String? = appState.selectedSpace == "default" ? nil : appState.selectedSpace

        do {
            _ = try await vectorService.delete(collection: collName, key: lookupKey, branch: branch, space: space)
            lookupResult = nil
            lookupError = "Vector \"\(lookupKey)\" deleted."
            await loadCollectionStats()
        } catch {
            lookupError = error.localizedDescription
        }
    }

    func vectorUpsert() async {
        guard let collName = selectedCollection else { return }
        upsertSuccess = nil
        upsertError = nil

        guard let vectorArray = parseFloatArray(upsertVector) else {
            upsertError = "Invalid embedding: must be a JSON array of numbers"
            return
        }

        var metadata: StrataValue? = nil
        if !upsertMetadata.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let parsed = StrataValue.fromJSONString(upsertMetadata),
                  case .object = parsed else {
                upsertError = "Invalid metadata: must be a JSON object"
                return
            }
            metadata = parsed
        }

        let branch = appState.selectedBranch
        let space: String? = appState.selectedSpace == "default" ? nil : appState.selectedSpace

        do {
            let version = try await vectorService.upsert(collection: collName, key: upsertKey, vector: vectorArray, metadata: metadata, branch: branch, space: space)
            upsertSuccess = "Upserted successfully — version \(version)"
            await loadCollectionStats()
        } catch {
            upsertError = error.localizedDescription
        }
    }

    func vectorSearch() async {
        guard let collName = selectedCollection else { return }
        searchResults = []
        searchError = nil
        selectedMatch = nil
        isSearching = true
        defer { isSearching = false }

        guard let queryArray = parseFloatArray(searchQuery) else {
            searchError = "Invalid query: must be a JSON array of numbers"
            return
        }

        let k = UInt64(searchK) ?? 10
        let branch = appState.selectedBranch
        let space: String? = appState.selectedSpace == "default" ? nil : appState.selectedSpace
        let asOf = asOfFromDate(appState.timeTravelDate)

        do {
            let matches = try await vectorService.search(collection: collName, query: queryArray, k: k, branch: branch, space: space, asOf: asOf)
            searchResults = matches.map { match in
                let metaStr = match.metadata?.prettyJSON ?? "{}"
                return VectorMatchDisplay(key: match.key, score: Double(match.score), metadataJSON: metaStr)
            }
            if searchResults.isEmpty {
                searchError = "No matches found"
            }
        } catch {
            searchError = error.localizedDescription
        }
    }

    func vectorBatchUpsert() async {
        guard let collName = selectedCollection else { return }
        batchUpsertSuccess = nil
        batchUpsertError = nil

        guard let data = batchUpsertJSON.data(using: .utf8),
              let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            batchUpsertError = "Invalid JSON: expected an array of {\"key\": ..., \"vector\": [...], \"metadata\": {...}} objects"
            return
        }

        var entries: [BatchVectorEntry] = []
        for item in items {
            guard let key = item["key"] as? String,
                  let vectorObj = item["vector"] as? [Any] else {
                batchUpsertError = "Each item must have \"key\" and \"vector\" fields"
                return
            }
            let vector = vectorObj.compactMap { elem -> Float? in
                if let d = elem as? Double { return Float(d) }
                if let n = elem as? NSNumber { return n.floatValue }
                return nil
            }
            guard vector.count == vectorObj.count else {
                batchUpsertError = "Vector must contain only numbers"
                return
            }
            var metadata: StrataValue? = nil
            if let metaObj = item["metadata"] {
                metadata = StrataValue.fromJSONObject(metaObj)
            }
            entries.append(BatchVectorEntry(key: key, vector: vector, metadata: metadata))
        }

        let branch = appState.selectedBranch
        let space: String? = appState.selectedSpace == "default" ? nil : appState.selectedSpace

        do {
            let versions = try await vectorService.batchUpsert(collection: collName, entries: entries, branch: branch, space: space)
            batchUpsertSuccess = "Upserted \(versions.count) vectors."
            await loadCollectionStats()
        } catch {
            batchUpsertError = error.localizedDescription
        }
    }

    // MARK: - State Management

    func resetRightPaneState() {
        collectionStats = nil
        lookupKey = ""
        lookupResult = nil
        lookupError = nil
        showFullEmbedding = false
        upsertKey = ""
        upsertVector = ""
        upsertMetadata = ""
        upsertSuccess = nil
        upsertError = nil
        searchQuery = ""
        searchK = "10"
        searchFilter = ""
        searchResults = []
        searchError = nil
        selectedMatch = nil
        batchUpsertJSON = ""
        batchUpsertSuccess = nil
        batchUpsertError = nil
    }

    func onSelectCollection(_ name: String?) {
        resetRightPaneState()
        selectedCollection = name
        if name != nil {
            Task { await loadCollectionStats() }
        }
    }

    // MARK: - Helpers

    func parseFloatArray(_ text: String) -> [Float]? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [Any] else {
            return nil
        }
        let floats = arr.compactMap { elem -> Float? in
            if let d = elem as? Double { return Float(d) }
            if let n = elem as? NSNumber { return n.floatValue }
            return nil
        }
        guard floats.count == arr.count else { return nil }
        return floats
    }
}
