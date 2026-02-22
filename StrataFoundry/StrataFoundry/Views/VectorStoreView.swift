//
//  VectorStoreView.swift
//  StrataFoundry
//

import SwiftUI

// MARK: - Model Structs

struct CollectionEntry: Identifiable {
    let id: String
    let name: String
    let dimension: Int
    let count: Int
    let metric: String
}

struct CollectionStats {
    let name: String
    let dimension: Int
    let metric: String
    let count: Int
    let indexType: String
    let memoryBytes: Int
}

struct VectorResult {
    let key: String
    let embedding: [Double]
    let metadata: String
    let version: Int
    let timestamp: Int64
}

struct VectorMatchEntry: Identifiable {
    var id: String { key }
    let key: String
    let score: Double
    let metadataJSON: String
}

enum RightPaneMode: String, CaseIterable {
    case lookup = "Lookup"
    case upsert = "Upsert"
    case search = "Search"
    case batch = "Batch"
}

// MARK: - View

struct VectorStoreView: View {
    @Environment(AppState.self) private var appState
    @State private var collections: [CollectionEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedCollection: String?

    // Write-related state
    @State private var showCreateSheet = false
    @State private var showDeleteConfirm = false
    @State private var formName = ""
    @State private var formDimension = "384"
    @State private var formMetric = "Cosine"

    // Right pane
    @State private var rightPaneMode: RightPaneMode = .lookup
    @State private var collectionStats: CollectionStats?

    // Lookup
    @State private var lookupKey = ""
    @State private var lookupResult: VectorResult?
    @State private var lookupError: String?
    @State private var showFullEmbedding = false
    @State private var showDeleteVectorConfirm = false

    // Upsert
    @State private var upsertKey = ""
    @State private var upsertVector = ""
    @State private var upsertMetadata = ""
    @State private var upsertSuccess: String?
    @State private var upsertError: String?

    // Search
    @State private var searchQuery = ""
    @State private var searchK = "10"
    @State private var searchFilter = ""
    @State private var searchResults: [VectorMatchEntry] = []
    @State private var searchError: String?
    @State private var selectedMatch: String?
    @State private var isSearching = false

    // Batch Upsert
    @State private var batchUpsertJSON = ""
    @State private var batchUpsertSuccess: String?
    @State private var batchUpsertError: String?

    private var isTimeTraveling: Bool { appState.timeTravelDate != nil }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Toolbar
            HStack {
                Text("Vector Store")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(collections.count) collections")
                    .foregroundStyle(.secondary)
                Button {
                    formName = ""
                    formDimension = "384"
                    formMetric = "Cosine"
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Create Collection")
                .disabled(isTimeTraveling)
                Button {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                }
                .help("Drop Collection")
                .disabled(isTimeTraveling || selectedCollection == nil)
                Button {
                    Task { await loadCollections() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)

            Divider()

            // MARK: Content
            if isLoading {
                Spacer()
                ProgressView("Loading collections...")
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                Text(error).foregroundStyle(.red)
                Spacer()
            } else if collections.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "arrow.trianglehead.branch")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No vector collections")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                HSplitView {
                    // Left pane: collection list
                    List(collections, selection: $selectedCollection) { collection in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(collection.name)
                                .font(.system(.body, design: .monospaced))
                            Text("dim=\(collection.dimension)  \(collection.metric)  \(collection.count) vectors")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(collection.id)
                    }
                    .frame(minWidth: 180, idealWidth: 220)

                    // Right pane: operations
                    rightPane
                }
            }
        }
        .task(id: appState.reloadToken) {
            await loadCollections()
        }
        .onChange(of: selectedCollection) { _, newValue in
            resetRightPaneState()
            if newValue != nil {
                Task { await loadCollectionStats() }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            VStack(spacing: 16) {
                Text("Create Collection")
                    .font(.headline)

                TextField("Collection Name", text: $formName)
                    .textFieldStyle(.roundedBorder)

                TextField("Dimension", text: $formDimension)
                    .textFieldStyle(.roundedBorder)

                Picker("Distance Metric", selection: $formMetric) {
                    Text("Cosine").tag("Cosine")
                    Text("Euclidean").tag("Euclidean")
                    Text("DotProduct").tag("DotProduct")
                }
                .pickerStyle(.segmented)

                HStack {
                    Button("Cancel") {
                        showCreateSheet = false
                    }
                    .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Create") {
                        Task {
                            await createCollection()
                            showCreateSheet = false
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(formName.isEmpty || Int(formDimension) == nil)
                }
            }
            .padding(20)
            .frame(minWidth: 350)
        }
        .alert("Drop Collection", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Drop", role: .destructive) {
                if let name = selectedCollection {
                    Task { await dropCollection(name) }
                }
            }
        } message: {
            if let name = selectedCollection {
                Text("Drop collection \"\(name)\"? All vectors will be deleted.")
            }
        }
        .alert("Delete Vector", isPresented: $showDeleteVectorConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await vectorDelete() }
            }
        } message: {
            Text("Delete vector \"\(lookupKey)\" from this collection?")
        }
    }

    // MARK: - Right Pane

    @ViewBuilder
    private var rightPane: some View {
        if let collName = selectedCollection {
            VStack(spacing: 0) {
                // Stats banner
                if let stats = collectionStats {
                    statsBanner(stats)
                    Divider()
                }

                // Mode picker
                Picker("Mode", selection: $rightPaneMode) {
                    ForEach(RightPaneMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                Divider()

                // Mode content
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        switch rightPaneMode {
                        case .lookup:
                            lookupModeView(collection: collName)
                        case .upsert:
                            upsertModeView(collection: collName)
                        case .search:
                            searchModeView(collection: collName)
                        case .batch:
                            batchUpsertModeView(collection: collName)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } else {
            VStack {
                Spacer()
                Text("Select a collection")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Stats Banner

    @ViewBuilder
    private func statsBanner(_ stats: CollectionStats) -> some View {
        HStack(spacing: 8) {
            statsCapsule("Dim", "\(stats.dimension)")
            statsCapsule("Metric", stats.metric)
            statsCapsule("Count", "\(stats.count)")
            if !stats.indexType.isEmpty {
                statsCapsule("Index", stats.indexType)
            }
            if stats.memoryBytes > 0 {
                statsCapsule("Memory", formatBytes(stats.memoryBytes))
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func statsCapsule(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary, in: Capsule())
    }

    // MARK: - Lookup Mode

    @ViewBuilder
    private func lookupModeView(collection: String) -> some View {
        HStack {
            TextField("Vector key", text: $lookupKey)
                .textFieldStyle(.roundedBorder)
            Button("Get") {
                Task { await vectorGet(collection: collection) }
            }
            .disabled(lookupKey.isEmpty)
            Button("Delete") {
                showDeleteVectorConfirm = true
            }
            .disabled(lookupKey.isEmpty || isTimeTraveling)
        }

        if let error = lookupError {
            Text(error)
                .foregroundStyle(.secondary)
                .font(.callout)
        }

        if let result = lookupResult {
            GroupBox("Result") {
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Key", value: result.key)
                    LabeledContent("Version", value: "\(result.version)")
                    LabeledContent("Timestamp", value: "\(result.timestamp)")

                    Divider()

                    Text("Embedding (\(result.embedding.count) dimensions)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    let displayEmbedding = showFullEmbedding
                        ? result.embedding
                        : Array(result.embedding.prefix(20))
                    Text("[\(displayEmbedding.map { String(format: "%.6f", $0) }.joined(separator: ", "))\(showFullEmbedding || result.embedding.count <= 20 ? "" : ", …")]")
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)

                    if result.embedding.count > 20 {
                        Button(showFullEmbedding ? "Show truncated" : "Show all \(result.embedding.count) values") {
                            showFullEmbedding.toggle()
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }

                    if !result.metadata.isEmpty && result.metadata != "{}" {
                        Divider()
                        Text("Metadata")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(result.metadata)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Upsert Mode

    @ViewBuilder
    private func upsertModeView(collection: String) -> some View {
        if isTimeTraveling {
            Label("Upsert is disabled during time travel", systemImage: "info.circle")
                .foregroundStyle(.orange)
                .font(.callout)
        }

        TextField("Key", text: $upsertKey)
            .textFieldStyle(.roundedBorder)
            .disabled(isTimeTraveling)

        Text("Embedding (JSON array of floats)")
            .font(.caption)
            .foregroundStyle(.secondary)
        TextEditor(text: $upsertVector)
            .font(.system(.body, design: .monospaced))
            .frame(minHeight: 80)
            .border(Color.secondary.opacity(0.3))
            .disabled(isTimeTraveling)

        if let stats = collectionStats, !upsertVector.isEmpty {
            if let parsed = parseFloatArray(upsertVector), parsed.count != stats.dimension {
                Text("Warning: expected \(stats.dimension) dimensions, got \(parsed.count)")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
        }

        Text("Metadata (optional JSON object)")
            .font(.caption)
            .foregroundStyle(.secondary)
        TextEditor(text: $upsertMetadata)
            .font(.system(.body, design: .monospaced))
            .frame(minHeight: 60)
            .border(Color.secondary.opacity(0.3))
            .disabled(isTimeTraveling)

        Button("Upsert") {
            Task { await vectorUpsert(collection: collection) }
        }
        .disabled(isTimeTraveling || upsertKey.isEmpty || upsertVector.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        if let success = upsertSuccess {
            Text(success)
                .foregroundStyle(.green)
                .font(.callout)
        }
        if let error = upsertError {
            Text(error)
                .foregroundStyle(.red)
                .font(.callout)
        }
    }

    // MARK: - Search Mode

    @ViewBuilder
    private func searchModeView(collection: String) -> some View {
        Text("Query vector (JSON array of floats)")
            .font(.caption)
            .foregroundStyle(.secondary)
        TextEditor(text: $searchQuery)
            .font(.system(.body, design: .monospaced))
            .frame(minHeight: 80)
            .border(Color.secondary.opacity(0.3))

        HStack {
            Text("k")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("10", text: $searchK)
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
        }

        Text("Filters (optional JSON array)")
            .font(.caption)
            .foregroundStyle(.secondary)
        TextEditor(text: $searchFilter)
            .font(.system(.body, design: .monospaced))
            .frame(minHeight: 60)
            .border(Color.secondary.opacity(0.3))

        Button("Search") {
            Task { await vectorSearch(collection: collection) }
        }
        .disabled(searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching)

        if isSearching {
            ProgressView()
                .controlSize(.small)
        }

        if let error = searchError {
            Text(error)
                .foregroundStyle(.red)
                .font(.callout)
        }

        if !searchResults.isEmpty {
            GroupBox("Results (\(searchResults.count) matches)") {
                VStack(spacing: 0) {
                    List(searchResults, selection: $selectedMatch) { match in
                        HStack {
                            Text(match.key)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Text(String(format: "%.4f", match.score))
                                .foregroundStyle(.secondary)
                                .font(.system(.body, design: .monospaced))
                        }
                        .tag(match.key)
                    }
                    .frame(minHeight: 120, maxHeight: 250)

                    if let matchKey = selectedMatch,
                       let match = searchResults.first(where: { $0.key == matchKey }),
                       !match.metadataJSON.isEmpty && match.metadataJSON != "{}" {
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Metadata for \"\(matchKey)\"")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(match.metadataJSON)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    // MARK: - Batch Upsert Mode

    @ViewBuilder
    private func batchUpsertModeView(collection: String) -> some View {
        if isTimeTraveling {
            Label("Batch upsert is disabled during time travel", systemImage: "info.circle")
                .foregroundStyle(.orange)
                .font(.callout)
        }

        Text("JSON array of vectors")
            .font(.caption)
            .foregroundStyle(.secondary)
        Text("Each item: {\"key\": \"...\", \"vector\": [...], \"metadata\": {...}}")
            .font(.caption)
            .foregroundStyle(.tertiary)

        TextEditor(text: $batchUpsertJSON)
            .font(.system(.body, design: .monospaced))
            .frame(minHeight: 200)
            .border(Color.secondary.opacity(0.3))
            .disabled(isTimeTraveling)

        Button("Batch Upsert") {
            Task { await vectorBatchUpsert(collection: collection) }
        }
        .disabled(isTimeTraveling || batchUpsertJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        if let success = batchUpsertSuccess {
            Text(success).foregroundStyle(.green).font(.callout)
        }
        if let error = batchUpsertError {
            Text(error).foregroundStyle(.red).font(.callout)
        }
    }

    // MARK: - State Management

    private func resetRightPaneState() {
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

    // MARK: - Collection Operations

    private func createCollection() async {
        guard let client = appState.client else { return }
        guard let dim = Int(formDimension) else { return }
        do {
            var cmd: [String: Any] = [
                "collection": formName,
                "dimension": dim,
                "metric": formMetric,
                "branch": appState.selectedBranch
            ]
            if appState.selectedSpace != "default" {
                cmd["space"] = appState.selectedSpace
            }
            let wrapper: [String: Any] = ["VectorCreateCollection": cmd]
            let data = try JSONSerialization.data(withJSONObject: wrapper)
            let jsonStr = String(data: data, encoding: .utf8)!
            _ = try await client.executeRaw(jsonStr)
            await loadCollections()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func dropCollection(_ name: String) async {
        guard let client = appState.client else { return }
        do {
            var cmd: [String: Any] = [
                "collection": name,
                "branch": appState.selectedBranch
            ]
            if appState.selectedSpace != "default" {
                cmd["space"] = appState.selectedSpace
            }
            let wrapper: [String: Any] = ["VectorDeleteCollection": cmd]
            let data = try JSONSerialization.data(withJSONObject: wrapper)
            let jsonStr = String(data: data, encoding: .utf8)!
            _ = try await client.executeRaw(jsonStr)
            if selectedCollection == name { selectedCollection = nil }
            await loadCollections()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Load Collections

    private func loadCollections() async {
        guard let client = appState.client else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let json = try await client.executeRaw("{\"VectorListCollections\": {\"branch\": \"\(appState.selectedBranch)\"\(appState.spaceFragment())\(appState.asOfFragment())}}")
            guard let data = json.data(using: .utf8),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let list = root["VectorCollectionList"] as? [[String: Any]] else {
                collections = []
                return
            }

            collections = list.compactMap { item in
                guard let name = item["name"] as? String else { return nil }
                return CollectionEntry(
                    id: name,
                    name: name,
                    dimension: item["dimension"] as? Int ?? 0,
                    count: item["count"] as? Int ?? 0,
                    metric: item["metric"] as? String ?? "unknown"
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Collection Stats

    private func loadCollectionStats() async {
        guard let client = appState.client,
              let collName = selectedCollection else { return }
        do {
            var cmd: [String: Any] = [
                "collection": collName,
                "branch": appState.selectedBranch
            ]
            if appState.selectedSpace != "default" {
                cmd["space"] = appState.selectedSpace
            }
            if let date = appState.timeTravelDate {
                cmd["as_of"] = Int64(date.timeIntervalSince1970 * 1_000_000)
            }
            let wrapper: [String: Any] = ["VectorCollectionStats": cmd]
            let data = try JSONSerialization.data(withJSONObject: wrapper)
            let jsonStr = String(data: data, encoding: .utf8)!
            let json = try await client.executeRaw(jsonStr)

            guard let respData = json.data(using: .utf8),
                  let root = try? JSONSerialization.jsonObject(with: respData) as? [String: Any],
                  let list = root["VectorCollectionList"] as? [[String: Any]],
                  let first = list.first else {
                collectionStats = nil
                return
            }

            collectionStats = CollectionStats(
                name: first["name"] as? String ?? collName,
                dimension: first["dimension"] as? Int ?? 0,
                metric: first["metric"] as? String ?? "unknown",
                count: first["count"] as? Int ?? 0,
                indexType: first["index_type"] as? String ?? "",
                memoryBytes: first["memory_bytes"] as? Int ?? 0
            )
        } catch {
            collectionStats = nil
        }
    }

    // MARK: - Vector Get

    private func vectorGet(collection: String) async {
        guard let client = appState.client else { return }
        lookupResult = nil
        lookupError = nil
        showFullEmbedding = false
        do {
            var cmd: [String: Any] = [
                "collection": collection,
                "key": lookupKey,
                "branch": appState.selectedBranch
            ]
            if appState.selectedSpace != "default" {
                cmd["space"] = appState.selectedSpace
            }
            if let date = appState.timeTravelDate {
                cmd["as_of"] = Int64(date.timeIntervalSince1970 * 1_000_000)
            }
            let wrapper: [String: Any] = ["VectorGet": cmd]
            let data = try JSONSerialization.data(withJSONObject: wrapper)
            let jsonStr = String(data: data, encoding: .utf8)!
            let json = try await client.executeRaw(jsonStr)

            guard let respData = json.data(using: .utf8),
                  let root = try? JSONSerialization.jsonObject(with: respData) as? [String: Any],
                  let vd = root["VectorData"] as? [String: Any] else {
                lookupError = "Vector not found for key \"\(lookupKey)\""
                return
            }

            let key = vd["key"] as? String ?? lookupKey
            let version = vd["version"] as? Int ?? 0
            let timestamp = vd["timestamp"] as? Int64 ?? 0
            let innerData = vd["data"] as? [String: Any] ?? [:]
            let embedding = innerData["embedding"] as? [Double] ?? (innerData["embedding"] as? [NSNumber])?.map { $0.doubleValue } ?? []

            var metadataStr = "{}"
            if let meta = innerData["metadata"] {
                if let metaData = try? JSONSerialization.data(withJSONObject: meta, options: [.prettyPrinted, .sortedKeys]),
                   let str = String(data: metaData, encoding: .utf8) {
                    metadataStr = str
                }
            }

            lookupResult = VectorResult(
                key: key,
                embedding: embedding,
                metadata: metadataStr,
                version: version,
                timestamp: timestamp
            )
        } catch {
            lookupError = error.localizedDescription
        }
    }

    // MARK: - Vector Delete

    private func vectorDelete() async {
        guard let client = appState.client,
              let collName = selectedCollection else { return }
        do {
            var cmd: [String: Any] = [
                "collection": collName,
                "key": lookupKey,
                "branch": appState.selectedBranch
            ]
            if appState.selectedSpace != "default" {
                cmd["space"] = appState.selectedSpace
            }
            let wrapper: [String: Any] = ["VectorDelete": cmd]
            let data = try JSONSerialization.data(withJSONObject: wrapper)
            let jsonStr = String(data: data, encoding: .utf8)!
            _ = try await client.executeRaw(jsonStr)
            lookupResult = nil
            lookupError = "Vector \"\(lookupKey)\" deleted."
            await loadCollectionStats()
        } catch {
            lookupError = error.localizedDescription
        }
    }

    // MARK: - Vector Upsert

    private func vectorUpsert(collection: String) async {
        guard let client = appState.client else { return }
        upsertSuccess = nil
        upsertError = nil
        do {
            guard let vectorArray = parseFloatArray(upsertVector) else {
                upsertError = "Invalid embedding: must be a JSON array of numbers"
                return
            }

            var cmd: [String: Any] = [
                "collection": collection,
                "key": upsertKey,
                "vector": vectorArray,
                "branch": appState.selectedBranch
            ]
            if appState.selectedSpace != "default" {
                cmd["space"] = appState.selectedSpace
            }

            if !upsertMetadata.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                guard let metaData = upsertMetadata.data(using: .utf8),
                      let metaObj = try? JSONSerialization.jsonObject(with: metaData) as? [String: Any] else {
                    upsertError = "Invalid metadata: must be a JSON object"
                    return
                }
                cmd["metadata"] = metaObj
            }

            let wrapper: [String: Any] = ["VectorUpsert": cmd]
            let data = try JSONSerialization.data(withJSONObject: wrapper)
            let jsonStr = String(data: data, encoding: .utf8)!
            let json = try await client.executeRaw(jsonStr)

            if let respData = json.data(using: .utf8),
               let root = try? JSONSerialization.jsonObject(with: respData) as? [String: Any],
               let version = root["Version"] as? Int {
                upsertSuccess = "Upserted successfully — version \(version)"
            } else {
                upsertSuccess = "Upserted successfully"
            }
            await loadCollectionStats()
        } catch {
            upsertError = error.localizedDescription
        }
    }

    // MARK: - Vector Search

    private func vectorSearch(collection: String) async {
        guard let client = appState.client else { return }
        searchResults = []
        searchError = nil
        selectedMatch = nil
        isSearching = true
        defer { isSearching = false }

        do {
            guard let queryArray = parseFloatArray(searchQuery) else {
                searchError = "Invalid query: must be a JSON array of numbers"
                return
            }

            let k = Int(searchK) ?? 10

            var cmd: [String: Any] = [
                "collection": collection,
                "query": queryArray,
                "k": k,
                "branch": appState.selectedBranch
            ]
            if appState.selectedSpace != "default" {
                cmd["space"] = appState.selectedSpace
            }
            if let date = appState.timeTravelDate {
                cmd["as_of"] = Int64(date.timeIntervalSince1970 * 1_000_000)
            }

            if !searchFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                guard let filterData = searchFilter.data(using: .utf8),
                      let filterObj = try? JSONSerialization.jsonObject(with: filterData) as? [[String: Any]] else {
                    searchError = "Invalid filter: must be a JSON array of filter objects"
                    return
                }
                cmd["filter"] = filterObj
            }

            let wrapper: [String: Any] = ["VectorSearch": cmd]
            let data = try JSONSerialization.data(withJSONObject: wrapper)
            let jsonStr = String(data: data, encoding: .utf8)!
            let json = try await client.executeRaw(jsonStr)

            guard let respData = json.data(using: .utf8),
                  let root = try? JSONSerialization.jsonObject(with: respData) as? [String: Any],
                  let matches = root["VectorMatches"] as? [[String: Any]] else {
                searchError = "No matches found"
                return
            }

            searchResults = matches.compactMap { match in
                guard let key = match["key"] as? String else { return nil }
                let score = match["score"] as? Double ?? 0.0
                var metaStr = "{}"
                if let meta = match["metadata"] {
                    if let metaData = try? JSONSerialization.data(withJSONObject: meta, options: [.prettyPrinted, .sortedKeys]),
                       let str = String(data: metaData, encoding: .utf8) {
                        metaStr = str
                    }
                }
                return VectorMatchEntry(key: key, score: score, metadataJSON: metaStr)
            }

            if searchResults.isEmpty {
                searchError = "No matches found"
            }
        } catch {
            searchError = error.localizedDescription
        }
    }

    // MARK: - Vector Batch Upsert

    private func vectorBatchUpsert(collection: String) async {
        guard let client = appState.client else { return }
        batchUpsertSuccess = nil
        batchUpsertError = nil
        do {
            guard let data = batchUpsertJSON.data(using: .utf8),
                  let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                batchUpsertError = "Invalid JSON: expected an array of {\"key\": ..., \"vector\": [...], \"metadata\": {...}} objects"
                return
            }

            var cmd: [String: Any] = [
                "collection": collection,
                "vectors": items,
                "branch": appState.selectedBranch
            ]
            if appState.selectedSpace != "default" {
                cmd["space"] = appState.selectedSpace
            }
            let wrapper: [String: Any] = ["VectorBatchUpsert": cmd]
            let wrapperData = try JSONSerialization.data(withJSONObject: wrapper)
            let jsonStr = String(data: wrapperData, encoding: .utf8)!
            let json = try await client.executeRaw(jsonStr)

            if let respData = json.data(using: .utf8),
               let root = try? JSONSerialization.jsonObject(with: respData) as? [String: Any],
               let count = root["BatchCount"] as? Int {
                batchUpsertSuccess = "Upserted \(count) vectors."
            } else {
                batchUpsertSuccess = "Batch upsert completed (\(items.count) items)."
            }
            await loadCollectionStats()
        } catch {
            batchUpsertError = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func parseFloatArray(_ text: String) -> [Double]? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [Any] else {
            return nil
        }
        let doubles = arr.compactMap { elem -> Double? in
            if let d = elem as? Double { return d }
            if let n = elem as? NSNumber { return n.doubleValue }
            return nil
        }
        guard doubles.count == arr.count else { return nil }
        return doubles
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        let kb = Double(bytes) / 1024
        if kb < 1024 { return String(format: "%.1f KB", kb) }
        let mb = kb / 1024
        if mb < 1024 { return String(format: "%.1f MB", mb) }
        let gb = mb / 1024
        return String(format: "%.1f GB", gb)
    }
}
