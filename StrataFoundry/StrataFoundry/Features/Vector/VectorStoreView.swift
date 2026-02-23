//
//  VectorStoreView.swift
//  StrataFoundry
//
//  Thin view observing VectorFeatureModel — all business logic delegated to model.
//

import SwiftUI

struct VectorStoreView: View {
    @Environment(AppState.self) private var appState
    @State private var model: VectorFeatureModel?

    var body: some View {
        VStack(spacing: 0) {
            if let model {
                toolbar(model)
                Divider()
                content(model)
            } else {
                Spacer()
                ProgressView("Loading...")
                Spacer()
            }
        }
        .task(id: appState.reloadToken) {
            if model == nil, let services = appState.services {
                model = VectorFeatureModel(vectorService: services.vectorService, appState: appState)
            }
            await model?.loadCollections()
        }
        .sheet(isPresented: Binding(
            get: { model?.showCreateSheet ?? false },
            set: { model?.showCreateSheet = $0 }
        )) {
            if let model {
                createCollectionSheet(model)
            }
        }
        .alert("Drop Collection", isPresented: Binding(
            get: { model?.showDeleteConfirm ?? false },
            set: { model?.showDeleteConfirm = $0 }
        )) {
            Button("Cancel", role: .cancel) {}
            Button("Drop", role: .destructive) {
                if let name = model?.selectedCollection {
                    Task { await model?.dropCollection(name) }
                }
            }
        } message: {
            if let name = model?.selectedCollection {
                Text("Drop collection \"\(name)\"? All vectors will be deleted.")
            }
        }
        .alert("Delete Vector", isPresented: Binding(
            get: { model?.showDeleteVectorConfirm ?? false },
            set: { model?.showDeleteVectorConfirm = $0 }
        )) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await model?.vectorDelete() }
            }
        } message: {
            if let key = model?.lookupKey {
                Text("Delete vector \"\(key)\" from this collection?")
            }
        }
    }

    // MARK: - Toolbar

    @ViewBuilder
    private func toolbar(_ model: VectorFeatureModel) -> some View {
        HStack {
            Text("Vector Store")
                .font(.title2)
                .fontWeight(.semibold)
            Spacer()
            Text("\(model.collections.count) collections")
                .foregroundStyle(.secondary)
            Button {
                model.formName = ""
                model.formDimension = "384"
                model.formMetric = "Cosine"
                model.showCreateSheet = true
            } label: {
                Image(systemName: "plus")
            }
            .help("Create Collection")
            .disabled(model.isTimeTraveling)
            Button {
                model.showDeleteConfirm = true
            } label: {
                Image(systemName: "trash")
            }
            .help("Drop Collection")
            .disabled(model.isTimeTraveling || model.selectedCollection == nil)
            Button {
                Task { await model.loadCollections() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    // MARK: - Content

    @ViewBuilder
    private func content(_ model: VectorFeatureModel) -> some View {
        LoadingErrorEmptyView(
            isLoading: model.isLoading,
            errorMessage: model.errorMessage,
            isEmpty: model.collections.isEmpty,
            emptyIcon: "arrow.trianglehead.branch",
            emptyText: "No vector collections"
        ) {
            HSplitView {
                collectionList(model)
                rightPane(model)
            }
        }
        .onChange(of: model.selectedCollection) { _, newValue in
            model.onSelectCollection(newValue)
        }
    }

    // MARK: - Collection List (Left Pane)

    @ViewBuilder
    private func collectionList(_ model: VectorFeatureModel) -> some View {
        List(model.collections, id: \.name, selection: Binding(
            get: { model.selectedCollection },
            set: { model.selectedCollection = $0 }
        )) { collection in
            VStack(alignment: .leading, spacing: 2) {
                Text(collection.name)
                    .font(.system(.body, design: .monospaced))
                Text("dim=\(collection.dimension)  \(collection.metric.rawValue)  \(collection.count) vectors")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .tag(collection.name)
        }
        .frame(minWidth: 180, idealWidth: 220)
    }

    // MARK: - Right Pane

    @ViewBuilder
    private func rightPane(_ model: VectorFeatureModel) -> some View {
        if let collName = model.selectedCollection {
            VStack(spacing: 0) {
                // Stats banner
                if let stats = model.collectionStats {
                    statsBanner(stats)
                    Divider()
                }

                // Mode picker
                Picker("Mode", selection: Binding(
                    get: { model.paneMode },
                    set: { model.paneMode = $0 }
                )) {
                    ForEach(VectorPaneMode.allCases, id: \.self) { mode in
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
                        switch model.paneMode {
                        case .lookup:
                            lookupModeView(model, collection: collName)
                        case .upsert:
                            upsertModeView(model)
                        case .search:
                            searchModeView(model)
                        case .batch:
                            batchUpsertModeView(model)
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
    private func statsBanner(_ stats: CollectionInfo) -> some View {
        HStack(spacing: 8) {
            StatsCapsule(label: "Dim", value: "\(stats.dimension)")
            StatsCapsule(label: "Metric", value: stats.metric.rawValue)
            StatsCapsule(label: "Count", value: "\(stats.count)")
            if let indexType = stats.indexType, !indexType.isEmpty {
                StatsCapsule(label: "Index", value: indexType)
            }
            if let memoryBytes = stats.memoryBytes, memoryBytes > 0 {
                StatsCapsule(label: "Memory", value: formatBytes(memoryBytes))
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Lookup Mode

    @ViewBuilder
    private func lookupModeView(_ model: VectorFeatureModel, collection: String) -> some View {
        HStack {
            TextField("Vector key", text: Binding(
                get: { model.lookupKey },
                set: { model.lookupKey = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            Button("Get") {
                Task { await model.vectorGet() }
            }
            .disabled(model.lookupKey.isEmpty)
            Button("Delete") {
                model.showDeleteVectorConfirm = true
            }
            .disabled(model.lookupKey.isEmpty || model.isTimeTraveling)
        }

        if let error = model.lookupError {
            Text(error)
                .foregroundStyle(.secondary)
                .font(.callout)
        }

        if let result = model.lookupResult {
            GroupBox("Result") {
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Key", value: result.key)
                    LabeledContent("Version", value: "\(result.version)")
                    LabeledContent("Timestamp", value: "\(result.timestamp)")

                    Divider()

                    Text("Embedding (\(result.embedding.count) dimensions)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    let displayEmbedding = model.showFullEmbedding
                        ? result.embedding
                        : Array(result.embedding.prefix(20))
                    Text("[\(displayEmbedding.map { String(format: "%.6f", $0) }.joined(separator: ", "))\(model.showFullEmbedding || result.embedding.count <= 20 ? "" : ", ...")]")
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)

                    if result.embedding.count > 20 {
                        Button(model.showFullEmbedding ? "Show truncated" : "Show all \(result.embedding.count) values") {
                            model.showFullEmbedding.toggle()
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
    private func upsertModeView(_ model: VectorFeatureModel) -> some View {
        if model.isTimeTraveling {
            Label("Upsert is disabled during time travel", systemImage: "info.circle")
                .foregroundStyle(.orange)
                .font(.callout)
        }

        TextField("Key", text: Binding(
            get: { model.upsertKey },
            set: { model.upsertKey = $0 }
        ))
        .textFieldStyle(.roundedBorder)
        .disabled(model.isTimeTraveling)

        Text("Embedding (JSON array of floats)")
            .font(.caption)
            .foregroundStyle(.secondary)
        TextEditor(text: Binding(
            get: { model.upsertVector },
            set: { model.upsertVector = $0 }
        ))
        .font(.system(.body, design: .monospaced))
        .frame(minHeight: 80)
        .border(Color.secondary.opacity(0.3))
        .disabled(model.isTimeTraveling)

        if let stats = model.collectionStats, !model.upsertVector.isEmpty {
            if let parsed = model.parseFloatArray(model.upsertVector), parsed.count != stats.dimension {
                Text("Warning: expected \(stats.dimension) dimensions, got \(parsed.count)")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
        }

        Text("Metadata (optional JSON object)")
            .font(.caption)
            .foregroundStyle(.secondary)
        TextEditor(text: Binding(
            get: { model.upsertMetadata },
            set: { model.upsertMetadata = $0 }
        ))
        .font(.system(.body, design: .monospaced))
        .frame(minHeight: 60)
        .border(Color.secondary.opacity(0.3))
        .disabled(model.isTimeTraveling)

        Button("Upsert") {
            Task { await model.vectorUpsert() }
        }
        .disabled(model.isTimeTraveling || model.upsertKey.isEmpty || model.upsertVector.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        if let success = model.upsertSuccess {
            Text(success)
                .foregroundStyle(.green)
                .font(.callout)
        }
        if let error = model.upsertError {
            Text(error)
                .foregroundStyle(.red)
                .font(.callout)
        }
    }

    // MARK: - Search Mode

    @ViewBuilder
    private func searchModeView(_ model: VectorFeatureModel) -> some View {
        Text("Query vector (JSON array of floats)")
            .font(.caption)
            .foregroundStyle(.secondary)
        TextEditor(text: Binding(
            get: { model.searchQuery },
            set: { model.searchQuery = $0 }
        ))
        .font(.system(.body, design: .monospaced))
        .frame(minHeight: 80)
        .border(Color.secondary.opacity(0.3))

        HStack {
            Text("k")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("10", text: Binding(
                get: { model.searchK },
                set: { model.searchK = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .frame(width: 60)
        }

        Text("Filters (optional JSON array)")
            .font(.caption)
            .foregroundStyle(.secondary)
        TextEditor(text: Binding(
            get: { model.searchFilter },
            set: { model.searchFilter = $0 }
        ))
        .font(.system(.body, design: .monospaced))
        .frame(minHeight: 60)
        .border(Color.secondary.opacity(0.3))

        Button("Search") {
            Task { await model.vectorSearch() }
        }
        .disabled(model.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isSearching)

        if model.isSearching {
            ProgressView()
                .controlSize(.small)
        }

        if let error = model.searchError {
            Text(error)
                .foregroundStyle(.red)
                .font(.callout)
        }

        if !model.searchResults.isEmpty {
            GroupBox("Results (\(model.searchResults.count) matches)") {
                VStack(spacing: 0) {
                    List(model.searchResults, selection: Binding(
                        get: { model.selectedMatch },
                        set: { model.selectedMatch = $0 }
                    )) { match in
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

                    if let matchKey = model.selectedMatch,
                       let match = model.searchResults.first(where: { $0.key == matchKey }),
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
    private func batchUpsertModeView(_ model: VectorFeatureModel) -> some View {
        if model.isTimeTraveling {
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

        TextEditor(text: Binding(
            get: { model.batchUpsertJSON },
            set: { model.batchUpsertJSON = $0 }
        ))
        .font(.system(.body, design: .monospaced))
        .frame(minHeight: 200)
        .border(Color.secondary.opacity(0.3))
        .disabled(model.isTimeTraveling)

        Button("Batch Upsert") {
            Task { await model.vectorBatchUpsert() }
        }
        .disabled(model.isTimeTraveling || model.batchUpsertJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        if let success = model.batchUpsertSuccess {
            Text(success).foregroundStyle(.green).font(.callout)
        }
        if let error = model.batchUpsertError {
            Text(error).foregroundStyle(.red).font(.callout)
        }
    }

    // MARK: - Create Collection Sheet

    @ViewBuilder
    private func createCollectionSheet(_ model: VectorFeatureModel) -> some View {
        VStack(spacing: 16) {
            Text("Create Collection")
                .font(.headline)

            TextField("Collection Name", text: Binding(
                get: { model.formName },
                set: { model.formName = $0 }
            ))
            .textFieldStyle(.roundedBorder)

            TextField("Dimension", text: Binding(
                get: { model.formDimension },
                set: { model.formDimension = $0 }
            ))
            .textFieldStyle(.roundedBorder)

            Picker("Distance Metric", selection: Binding(
                get: { model.formMetric },
                set: { model.formMetric = $0 }
            )) {
                Text("Cosine").tag("Cosine")
                Text("Euclidean").tag("Euclidean")
                Text("DotProduct").tag("DotProduct")
            }
            .pickerStyle(.segmented)

            HStack {
                Button("Cancel") {
                    model.showCreateSheet = false
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create") {
                    Task {
                        await model.createCollection()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(model.formName.isEmpty || Int(model.formDimension) == nil)
            }
        }
        .padding(20)
        .frame(minWidth: 350)
    }
}
