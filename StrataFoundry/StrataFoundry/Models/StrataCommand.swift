//
//  StrataCommand.swift
//  StrataFoundry
//
//  Encodable enum mirroring Rust's Command enum from executor/command.rs.
//  Produces externally-tagged JSON: {"KvPut": {"key": "...", "value": {...}}}.
//

import Foundation

/// All Strata database operations as a typed, Encodable enum.
///
/// Each case maps to exactly one Rust `Command` variant. Inner field names
/// use snake_case CodingKeys to match Rust's serde format.
enum StrataCommand: Encodable, Sendable {

    // MARK: - KV (6)
    case kvPut(branch: String? = nil, space: String? = nil, key: String, value: StrataValue)
    case kvGet(branch: String? = nil, space: String? = nil, key: String, asOf: UInt64? = nil)
    case kvDelete(branch: String? = nil, space: String? = nil, key: String)
    case kvList(branch: String? = nil, space: String? = nil, prefix: String? = nil, cursor: String? = nil, limit: UInt64? = nil, asOf: UInt64? = nil)
    case kvBatchPut(branch: String? = nil, space: String? = nil, entries: [BatchKvEntry])
    case kvGetv(branch: String? = nil, space: String? = nil, key: String, asOf: UInt64? = nil)

    // MARK: - JSON (6)
    case jsonSet(branch: String? = nil, space: String? = nil, key: String, path: String, value: StrataValue)
    case jsonGet(branch: String? = nil, space: String? = nil, key: String, path: String, asOf: UInt64? = nil)
    case jsonDelete(branch: String? = nil, space: String? = nil, key: String, path: String)
    case jsonGetv(branch: String? = nil, space: String? = nil, key: String, asOf: UInt64? = nil)
    case jsonBatchSet(branch: String? = nil, space: String? = nil, entries: [BatchJsonEntry])
    case jsonList(branch: String? = nil, space: String? = nil, prefix: String? = nil, cursor: String? = nil, limit: UInt64, asOf: UInt64? = nil)

    // MARK: - Event (5)
    case eventAppend(branch: String? = nil, space: String? = nil, eventType: String, payload: StrataValue)
    case eventBatchAppend(branch: String? = nil, space: String? = nil, entries: [BatchEventEntry])
    case eventGet(branch: String? = nil, space: String? = nil, sequence: UInt64, asOf: UInt64? = nil)
    case eventGetByType(branch: String? = nil, space: String? = nil, eventType: String, limit: UInt64? = nil, afterSequence: UInt64? = nil, asOf: UInt64? = nil)
    case eventLen(branch: String? = nil, space: String? = nil)

    // MARK: - State (8)
    case stateSet(branch: String? = nil, space: String? = nil, cell: String, value: StrataValue)
    case stateBatchSet(branch: String? = nil, space: String? = nil, entries: [BatchStateEntry])
    case stateGet(branch: String? = nil, space: String? = nil, cell: String, asOf: UInt64? = nil)
    case stateCas(branch: String? = nil, space: String? = nil, cell: String, expectedCounter: UInt64?, value: StrataValue)
    case stateGetv(branch: String? = nil, space: String? = nil, cell: String, asOf: UInt64? = nil)
    case stateInit(branch: String? = nil, space: String? = nil, cell: String, value: StrataValue)
    case stateDelete(branch: String? = nil, space: String? = nil, cell: String)
    case stateList(branch: String? = nil, space: String? = nil, prefix: String? = nil, asOf: UInt64? = nil)

    // MARK: - Vector (9)
    case vectorUpsert(branch: String? = nil, space: String? = nil, collection: String, key: String, vector: [Float], metadata: StrataValue? = nil)
    case vectorGet(branch: String? = nil, space: String? = nil, collection: String, key: String, asOf: UInt64? = nil)
    case vectorDelete(branch: String? = nil, space: String? = nil, collection: String, key: String)
    case vectorSearch(branch: String? = nil, space: String? = nil, collection: String, query: [Float], k: UInt64, filter: [MetadataFilter]? = nil, metric: DistanceMetric? = nil, asOf: UInt64? = nil)
    case vectorCreateCollection(branch: String? = nil, space: String? = nil, collection: String, dimension: UInt64, metric: DistanceMetric)
    case vectorDeleteCollection(branch: String? = nil, space: String? = nil, collection: String)
    case vectorListCollections(branch: String? = nil, space: String? = nil)
    case vectorCollectionStats(branch: String? = nil, space: String? = nil, collection: String)
    case vectorBatchUpsert(branch: String? = nil, space: String? = nil, collection: String, entries: [BatchVectorEntry])

    // MARK: - Branch (8)
    case branchCreate(branchId: String? = nil, metadata: StrataValue? = nil)
    case branchGet(branch: String)
    case branchList(state: BranchStatus? = nil, limit: UInt64? = nil, offset: UInt64? = nil)
    case branchExists(branch: String)
    case branchDelete(branch: String)
    case branchFork(source: String, destination: String)
    case branchDiff(branchA: String, branchB: String)
    case branchMerge(source: String, target: String, strategy: MergeStrategy)

    // MARK: - Transaction (5)
    case txnBegin(branch: String? = nil, options: TxnOptions? = nil)
    case txnCommit
    case txnRollback
    case txnInfo
    case txnIsActive

    // MARK: - Retention (3)
    case retentionApply(branch: String? = nil)
    case retentionStats(branch: String? = nil)
    case retentionPreview(branch: String? = nil)

    // MARK: - Database (5)
    case ping
    case info
    case flush
    case compact
    case timeRange(branch: String? = nil)

    // MARK: - Bundle (3)
    case branchExport(branchId: String, path: String)
    case branchImport(path: String)
    case branchBundleValidate(path: String)

    // MARK: - Intelligence (2)
    case configureModel(endpoint: String, model: String, apiKey: String? = nil, timeoutMs: UInt64? = nil)
    case search(branch: String? = nil, space: String? = nil, search: SearchQuery)

    // MARK: - Embedding (2)
    case embed(text: String)
    case embedBatch(texts: [String])

    // MARK: - Model Management (3)
    case modelsList
    case modelsPull(name: String)
    case modelsLocal

    // MARK: - Generation (4)
    case generate(model: String, prompt: String, maxTokens: Int? = nil, temperature: Float? = nil, topK: Int? = nil, topP: Float? = nil, seed: UInt64? = nil, stopTokens: [UInt32]? = nil)
    case tokenize(model: String, text: String, addSpecialTokens: Bool? = nil)
    case detokenize(model: String, ids: [UInt32])
    case generateUnload(model: String)

    // MARK: - Space (5)
    case spaceList(branch: String? = nil)
    case spaceCreate(branch: String? = nil, space: String)
    case spaceDelete(branch: String? = nil, space: String, force: Bool = false)
    case spaceExists(branch: String? = nil, space: String)

    // MARK: - Config (3)
    case embedStatus
    case configGet
    case configSetAutoEmbed(enabled: Bool)
    case autoEmbedStatus
    case durabilityCounters

    // MARK: - Graph (13)
    case graphCreate(branch: String? = nil, graph: String, cascadePolicy: String? = nil)
    case graphDelete(branch: String? = nil, graph: String)
    case graphList(branch: String? = nil)
    case graphGetMeta(branch: String? = nil, graph: String)
    case graphAddNode(branch: String? = nil, graph: String, nodeId: String, entityRef: String? = nil, properties: StrataValue? = nil)
    case graphGetNode(branch: String? = nil, graph: String, nodeId: String)
    case graphRemoveNode(branch: String? = nil, graph: String, nodeId: String)
    case graphListNodes(branch: String? = nil, graph: String)
    case graphAddEdge(branch: String? = nil, graph: String, src: String, dst: String, edgeType: String, weight: Double? = nil, properties: StrataValue? = nil)
    case graphRemoveEdge(branch: String? = nil, graph: String, src: String, dst: String, edgeType: String)
    case graphNeighbors(branch: String? = nil, graph: String, nodeId: String, direction: String? = nil, edgeType: String? = nil)
    case graphBulkInsert(branch: String? = nil, graph: String, nodes: [BulkGraphNode], edges: [BulkGraphEdge], chunkSize: Int? = nil)
    case graphBfs(branch: String? = nil, graph: String, start: String, maxDepth: Int, maxNodes: Int? = nil, edgeTypes: [String]? = nil, direction: String? = nil)

    // MARK: - Encoding

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)

        switch self {
        // KV
        case let .kvPut(branch, space, key, value):
            try container.encode(
                KvPutPayload(branch: branch, space: space, key: key, value: value),
                forKey: .init("KvPut"))
        case let .kvGet(branch, space, key, asOf):
            try container.encode(
                BranchSpaceKeyAsOf(branch: branch, space: space, key: key, asOf: asOf),
                forKey: .init("KvGet"))
        case let .kvDelete(branch, space, key):
            try container.encode(
                BranchSpaceKey(branch: branch, space: space, key: key),
                forKey: .init("KvDelete"))
        case let .kvList(branch, space, prefix, cursor, limit, asOf):
            try container.encode(
                KvListPayload(branch: branch, space: space, prefix: prefix, cursor: cursor, limit: limit, asOf: asOf),
                forKey: .init("KvList"))
        case let .kvBatchPut(branch, space, entries):
            try container.encode(
                BatchPayload(branch: branch, space: space, entries: entries),
                forKey: .init("KvBatchPut"))
        case let .kvGetv(branch, space, key, asOf):
            try container.encode(
                BranchSpaceKeyAsOf(branch: branch, space: space, key: key, asOf: asOf),
                forKey: .init("KvGetv"))

        // JSON
        case let .jsonSet(branch, space, key, path, value):
            try container.encode(
                JsonSetPayload(branch: branch, space: space, key: key, path: path, value: value),
                forKey: .init("JsonSet"))
        case let .jsonGet(branch, space, key, path, asOf):
            try container.encode(
                JsonGetPayload(branch: branch, space: space, key: key, path: path, asOf: asOf),
                forKey: .init("JsonGet"))
        case let .jsonDelete(branch, space, key, path):
            try container.encode(
                JsonDeletePayload(branch: branch, space: space, key: key, path: path),
                forKey: .init("JsonDelete"))
        case let .jsonGetv(branch, space, key, asOf):
            try container.encode(
                BranchSpaceKeyAsOf(branch: branch, space: space, key: key, asOf: asOf),
                forKey: .init("JsonGetv"))
        case let .jsonBatchSet(branch, space, entries):
            try container.encode(
                BatchPayload(branch: branch, space: space, entries: entries),
                forKey: .init("JsonBatchSet"))
        case let .jsonList(branch, space, prefix, cursor, limit, asOf):
            try container.encode(
                JsonListPayload(branch: branch, space: space, prefix: prefix, cursor: cursor, limit: limit, asOf: asOf),
                forKey: .init("JsonList"))

        // Event
        case let .eventAppend(branch, space, eventType, payload):
            try container.encode(
                EventAppendPayload(branch: branch, space: space, eventType: eventType, payload: payload),
                forKey: .init("EventAppend"))
        case let .eventBatchAppend(branch, space, entries):
            try container.encode(
                BatchPayload(branch: branch, space: space, entries: entries),
                forKey: .init("EventBatchAppend"))
        case let .eventGet(branch, space, sequence, asOf):
            try container.encode(
                EventGetPayload(branch: branch, space: space, sequence: sequence, asOf: asOf),
                forKey: .init("EventGet"))
        case let .eventGetByType(branch, space, eventType, limit, afterSequence, asOf):
            try container.encode(
                EventGetByTypePayload(branch: branch, space: space, eventType: eventType, limit: limit, afterSequence: afterSequence, asOf: asOf),
                forKey: .init("EventGetByType"))
        case let .eventLen(branch, space):
            try container.encode(
                BranchSpace(branch: branch, space: space),
                forKey: .init("EventLen"))

        // State
        case let .stateSet(branch, space, cell, value):
            try container.encode(
                StateCellValue(branch: branch, space: space, cell: cell, value: value),
                forKey: .init("StateSet"))
        case let .stateBatchSet(branch, space, entries):
            try container.encode(
                BatchPayload(branch: branch, space: space, entries: entries),
                forKey: .init("StateBatchSet"))
        case let .stateGet(branch, space, cell, asOf):
            try container.encode(
                BranchSpaceCellAsOf(branch: branch, space: space, cell: cell, asOf: asOf),
                forKey: .init("StateGet"))
        case let .stateCas(branch, space, cell, expectedCounter, value):
            try container.encode(
                StateCasPayload(branch: branch, space: space, cell: cell, expectedCounter: expectedCounter, value: value),
                forKey: .init("StateCas"))
        case let .stateGetv(branch, space, cell, asOf):
            try container.encode(
                BranchSpaceCellAsOf(branch: branch, space: space, cell: cell, asOf: asOf),
                forKey: .init("StateGetv"))
        case let .stateInit(branch, space, cell, value):
            try container.encode(
                StateCellValue(branch: branch, space: space, cell: cell, value: value),
                forKey: .init("StateInit"))
        case let .stateDelete(branch, space, cell):
            try container.encode(
                BranchSpaceCell(branch: branch, space: space, cell: cell),
                forKey: .init("StateDelete"))
        case let .stateList(branch, space, prefix, asOf):
            try container.encode(
                StateListPayload(branch: branch, space: space, prefix: prefix, asOf: asOf),
                forKey: .init("StateList"))

        // Vector
        case let .vectorUpsert(branch, space, collection, key, vector, metadata):
            try container.encode(
                VectorUpsertPayload(branch: branch, space: space, collection: collection, key: key, vector: vector, metadata: metadata),
                forKey: .init("VectorUpsert"))
        case let .vectorGet(branch, space, collection, key, asOf):
            try container.encode(
                VectorGetPayload(branch: branch, space: space, collection: collection, key: key, asOf: asOf),
                forKey: .init("VectorGet"))
        case let .vectorDelete(branch, space, collection, key):
            try container.encode(
                VectorKeyPayload(branch: branch, space: space, collection: collection, key: key),
                forKey: .init("VectorDelete"))
        case let .vectorSearch(branch, space, collection, query, k, filter, metric, asOf):
            try container.encode(
                VectorSearchPayload(branch: branch, space: space, collection: collection, query: query, k: k, filter: filter, metric: metric, asOf: asOf),
                forKey: .init("VectorSearch"))
        case let .vectorCreateCollection(branch, space, collection, dimension, metric):
            try container.encode(
                VectorCreatePayload(branch: branch, space: space, collection: collection, dimension: dimension, metric: metric),
                forKey: .init("VectorCreateCollection"))
        case let .vectorDeleteCollection(branch, space, collection):
            try container.encode(
                BranchSpaceCollection(branch: branch, space: space, collection: collection),
                forKey: .init("VectorDeleteCollection"))
        case let .vectorListCollections(branch, space):
            try container.encode(
                BranchSpace(branch: branch, space: space),
                forKey: .init("VectorListCollections"))
        case let .vectorCollectionStats(branch, space, collection):
            try container.encode(
                BranchSpaceCollection(branch: branch, space: space, collection: collection),
                forKey: .init("VectorCollectionStats"))
        case let .vectorBatchUpsert(branch, space, collection, entries):
            try container.encode(
                VectorBatchPayload(branch: branch, space: space, collection: collection, entries: entries),
                forKey: .init("VectorBatchUpsert"))

        // Branch
        case let .branchCreate(branchId, metadata):
            try container.encode(
                BranchCreatePayload(branchId: branchId, metadata: metadata),
                forKey: .init("BranchCreate"))
        case let .branchGet(branch):
            try container.encode(
                BranchOnly(branch: branch),
                forKey: .init("BranchGet"))
        case let .branchList(state, limit, offset):
            try container.encode(
                BranchListPayload(state: state, limit: limit, offset: offset),
                forKey: .init("BranchList"))
        case let .branchExists(branch):
            try container.encode(
                BranchOnly(branch: branch),
                forKey: .init("BranchExists"))
        case let .branchDelete(branch):
            try container.encode(
                BranchOnly(branch: branch),
                forKey: .init("BranchDelete"))
        case let .branchFork(source, destination):
            try container.encode(
                BranchForkPayload(source: source, destination: destination),
                forKey: .init("BranchFork"))
        case let .branchDiff(branchA, branchB):
            try container.encode(
                BranchDiffPayload(branchA: branchA, branchB: branchB),
                forKey: .init("BranchDiff"))
        case let .branchMerge(source, target, strategy):
            try container.encode(
                BranchMergePayload(source: source, target: target, strategy: strategy),
                forKey: .init("BranchMerge"))

        // Transaction
        case let .txnBegin(branch, options):
            try container.encode(
                TxnBeginPayload(branch: branch, options: options),
                forKey: .init("TxnBegin"))
        case .txnCommit:
            try container.encodeNil(forKey: .init("TxnCommit"))
        case .txnRollback:
            try container.encodeNil(forKey: .init("TxnRollback"))
        case .txnInfo:
            try container.encodeNil(forKey: .init("TxnInfo"))
        case .txnIsActive:
            try container.encodeNil(forKey: .init("TxnIsActive"))

        // Retention
        case let .retentionApply(branch):
            try container.encode(
                OptionalBranch(branch: branch),
                forKey: .init("RetentionApply"))
        case let .retentionStats(branch):
            try container.encode(
                OptionalBranch(branch: branch),
                forKey: .init("RetentionStats"))
        case let .retentionPreview(branch):
            try container.encode(
                OptionalBranch(branch: branch),
                forKey: .init("RetentionPreview"))

        // Database
        case .ping:
            try container.encodeNil(forKey: .init("Ping"))
        case .info:
            try container.encodeNil(forKey: .init("Info"))
        case .flush:
            try container.encodeNil(forKey: .init("Flush"))
        case .compact:
            try container.encodeNil(forKey: .init("Compact"))
        case let .timeRange(branch):
            try container.encode(
                OptionalBranch(branch: branch),
                forKey: .init("TimeRange"))

        // Bundle
        case let .branchExport(branchId, path):
            try container.encode(
                BranchExportPayload(branchId: branchId, path: path),
                forKey: .init("BranchExport"))
        case let .branchImport(path):
            try container.encode(
                PathPayload(path: path),
                forKey: .init("BranchImport"))
        case let .branchBundleValidate(path):
            try container.encode(
                PathPayload(path: path),
                forKey: .init("BranchBundleValidate"))

        // Intelligence
        case let .configureModel(endpoint, model, apiKey, timeoutMs):
            try container.encode(
                ConfigureModelPayload(endpoint: endpoint, model: model, apiKey: apiKey, timeoutMs: timeoutMs),
                forKey: .init("ConfigureModel"))
        case let .search(branch, space, search):
            try container.encode(
                SearchPayload(branch: branch, space: space, search: search),
                forKey: .init("Search"))

        // Embedding
        case let .embed(text):
            try container.encode(
                EmbedPayload(text: text),
                forKey: .init("Embed"))
        case let .embedBatch(texts):
            try container.encode(
                EmbedBatchPayload(texts: texts),
                forKey: .init("EmbedBatch"))

        // Model Management
        case .modelsList:
            try container.encodeNil(forKey: .init("ModelsList"))
        case let .modelsPull(name):
            try container.encode(
                NamePayload(name: name),
                forKey: .init("ModelsPull"))
        case .modelsLocal:
            try container.encodeNil(forKey: .init("ModelsLocal"))

        // Generation
        case let .generate(model, prompt, maxTokens, temperature, topK, topP, seed, stopTokens):
            try container.encode(
                GeneratePayload(model: model, prompt: prompt, maxTokens: maxTokens, temperature: temperature, topK: topK, topP: topP, seed: seed, stopTokens: stopTokens),
                forKey: .init("Generate"))
        case let .tokenize(model, text, addSpecialTokens):
            try container.encode(
                TokenizePayload(model: model, text: text, addSpecialTokens: addSpecialTokens),
                forKey: .init("Tokenize"))
        case let .detokenize(model, ids):
            try container.encode(
                DetokenizePayload(model: model, ids: ids),
                forKey: .init("Detokenize"))
        case let .generateUnload(model):
            try container.encode(
                ModelPayload(model: model),
                forKey: .init("GenerateUnload"))

        // Space
        case let .spaceList(branch):
            try container.encode(
                OptionalBranch(branch: branch),
                forKey: .init("SpaceList"))
        case let .spaceCreate(branch, space):
            try container.encode(
                SpacePayload(branch: branch, space: space),
                forKey: .init("SpaceCreate"))
        case let .spaceDelete(branch, space, force):
            try container.encode(
                SpaceDeletePayload(branch: branch, space: space, force: force),
                forKey: .init("SpaceDelete"))
        case let .spaceExists(branch, space):
            try container.encode(
                SpacePayload(branch: branch, space: space),
                forKey: .init("SpaceExists"))

        // Config
        case .embedStatus:
            try container.encodeNil(forKey: .init("EmbedStatus"))
        case .configGet:
            try container.encodeNil(forKey: .init("ConfigGet"))
        case let .configSetAutoEmbed(enabled):
            try container.encode(
                AutoEmbedPayload(enabled: enabled),
                forKey: .init("ConfigSetAutoEmbed"))
        case .autoEmbedStatus:
            try container.encodeNil(forKey: .init("AutoEmbedStatus"))
        case .durabilityCounters:
            try container.encodeNil(forKey: .init("DurabilityCounters"))

        // Graph
        case let .graphCreate(branch, graph, cascadePolicy):
            try container.encode(
                GraphCreatePayload(branch: branch, graph: graph, cascadePolicy: cascadePolicy),
                forKey: .init("GraphCreate"))
        case let .graphDelete(branch, graph):
            try container.encode(
                BranchGraph(branch: branch, graph: graph),
                forKey: .init("GraphDelete"))
        case let .graphList(branch):
            try container.encode(
                OptionalBranch(branch: branch),
                forKey: .init("GraphList"))
        case let .graphGetMeta(branch, graph):
            try container.encode(
                BranchGraph(branch: branch, graph: graph),
                forKey: .init("GraphGetMeta"))
        case let .graphAddNode(branch, graph, nodeId, entityRef, properties):
            try container.encode(
                GraphAddNodePayload(branch: branch, graph: graph, nodeId: nodeId, entityRef: entityRef, properties: properties),
                forKey: .init("GraphAddNode"))
        case let .graphGetNode(branch, graph, nodeId):
            try container.encode(
                GraphNodePayload(branch: branch, graph: graph, nodeId: nodeId),
                forKey: .init("GraphGetNode"))
        case let .graphRemoveNode(branch, graph, nodeId):
            try container.encode(
                GraphNodePayload(branch: branch, graph: graph, nodeId: nodeId),
                forKey: .init("GraphRemoveNode"))
        case let .graphListNodes(branch, graph):
            try container.encode(
                BranchGraph(branch: branch, graph: graph),
                forKey: .init("GraphListNodes"))
        case let .graphAddEdge(branch, graph, src, dst, edgeType, weight, properties):
            try container.encode(
                GraphAddEdgePayload(branch: branch, graph: graph, src: src, dst: dst, edgeType: edgeType, weight: weight, properties: properties),
                forKey: .init("GraphAddEdge"))
        case let .graphRemoveEdge(branch, graph, src, dst, edgeType):
            try container.encode(
                GraphRemoveEdgePayload(branch: branch, graph: graph, src: src, dst: dst, edgeType: edgeType),
                forKey: .init("GraphRemoveEdge"))
        case let .graphNeighbors(branch, graph, nodeId, direction, edgeType):
            try container.encode(
                GraphNeighborsPayload(branch: branch, graph: graph, nodeId: nodeId, direction: direction, edgeType: edgeType),
                forKey: .init("GraphNeighbors"))
        case let .graphBulkInsert(branch, graph, nodes, edges, chunkSize):
            try container.encode(
                GraphBulkInsertPayload(branch: branch, graph: graph, nodes: nodes, edges: edges, chunkSize: chunkSize),
                forKey: .init("GraphBulkInsert"))
        case let .graphBfs(branch, graph, start, maxDepth, maxNodes, edgeTypes, direction):
            try container.encode(
                GraphBfsPayload(branch: branch, graph: graph, start: start, maxDepth: maxDepth, maxNodes: maxNodes, edgeTypes: edgeTypes, direction: direction),
                forKey: .init("GraphBfs"))
        }
    }
}

// MARK: - Internal Payload Structs

// These structs handle the snake_case JSON field names for each command variant.
// They are only used internally by StrataCommand.encode(to:).

private struct EmptyPayload: Encodable {}

private struct BranchSpace: Encodable {
    let branch: String?
    let space: String?
}

private struct OptionalBranch: Encodable {
    let branch: String?
}

private struct BranchOnly: Encodable {
    let branch: String
}

private struct BranchSpaceKey: Encodable {
    let branch: String?
    let space: String?
    let key: String
}

private struct BranchSpaceKeyAsOf: Encodable {
    let branch: String?
    let space: String?
    let key: String
    let asOf: UInt64?
    enum CodingKeys: String, CodingKey { case branch, space, key, asOf = "as_of" }
}

private struct BranchSpaceCell: Encodable {
    let branch: String?
    let space: String?
    let cell: String
}

private struct BranchSpaceCellAsOf: Encodable {
    let branch: String?
    let space: String?
    let cell: String
    let asOf: UInt64?
    enum CodingKeys: String, CodingKey { case branch, space, cell, asOf = "as_of" }
}

private struct BranchSpaceCollection: Encodable {
    let branch: String?
    let space: String?
    let collection: String
}

private struct BranchGraph: Encodable {
    let branch: String?
    let graph: String
}

private struct KvPutPayload: Encodable {
    let branch: String?
    let space: String?
    let key: String
    let value: StrataValue
}

private struct KvListPayload: Encodable {
    let branch: String?
    let space: String?
    let prefix: String?
    let cursor: String?
    let limit: UInt64?
    let asOf: UInt64?
    enum CodingKeys: String, CodingKey { case branch, space, prefix, cursor, limit, asOf = "as_of" }
}

private struct BatchPayload<T: Encodable>: Encodable {
    let branch: String?
    let space: String?
    let entries: T
}

private struct JsonSetPayload: Encodable {
    let branch: String?
    let space: String?
    let key: String
    let path: String
    let value: StrataValue
}

private struct JsonGetPayload: Encodable {
    let branch: String?
    let space: String?
    let key: String
    let path: String
    let asOf: UInt64?
    enum CodingKeys: String, CodingKey { case branch, space, key, path, asOf = "as_of" }
}

private struct JsonDeletePayload: Encodable {
    let branch: String?
    let space: String?
    let key: String
    let path: String
}

private struct JsonListPayload: Encodable {
    let branch: String?
    let space: String?
    let prefix: String?
    let cursor: String?
    let limit: UInt64
    let asOf: UInt64?
    enum CodingKeys: String, CodingKey { case branch, space, prefix, cursor, limit, asOf = "as_of" }
}

private struct EventAppendPayload: Encodable {
    let branch: String?
    let space: String?
    let eventType: String
    let payload: StrataValue
    enum CodingKeys: String, CodingKey { case branch, space, eventType = "event_type", payload }
}

private struct EventGetPayload: Encodable {
    let branch: String?
    let space: String?
    let sequence: UInt64
    let asOf: UInt64?
    enum CodingKeys: String, CodingKey { case branch, space, sequence, asOf = "as_of" }
}

private struct EventGetByTypePayload: Encodable {
    let branch: String?
    let space: String?
    let eventType: String
    let limit: UInt64?
    let afterSequence: UInt64?
    let asOf: UInt64?
    enum CodingKeys: String, CodingKey {
        case branch, space
        case eventType = "event_type"
        case limit
        case afterSequence = "after_sequence"
        case asOf = "as_of"
    }
}

private struct StateCellValue: Encodable {
    let branch: String?
    let space: String?
    let cell: String
    let value: StrataValue
}

private struct StateCasPayload: Encodable {
    let branch: String?
    let space: String?
    let cell: String
    let expectedCounter: UInt64?
    let value: StrataValue
    enum CodingKeys: String, CodingKey { case branch, space, cell, expectedCounter = "expected_counter", value }
}

private struct StateListPayload: Encodable {
    let branch: String?
    let space: String?
    let prefix: String?
    let asOf: UInt64?
    enum CodingKeys: String, CodingKey { case branch, space, prefix, asOf = "as_of" }
}

private struct VectorUpsertPayload: Encodable {
    let branch: String?
    let space: String?
    let collection: String
    let key: String
    let vector: [Float]
    let metadata: StrataValue?
}

private struct VectorGetPayload: Encodable {
    let branch: String?
    let space: String?
    let collection: String
    let key: String
    let asOf: UInt64?
    enum CodingKeys: String, CodingKey { case branch, space, collection, key, asOf = "as_of" }
}

private struct VectorKeyPayload: Encodable {
    let branch: String?
    let space: String?
    let collection: String
    let key: String
}

private struct VectorSearchPayload: Encodable {
    let branch: String?
    let space: String?
    let collection: String
    let query: [Float]
    let k: UInt64
    let filter: [MetadataFilter]?
    let metric: DistanceMetric?
    let asOf: UInt64?
    enum CodingKeys: String, CodingKey { case branch, space, collection, query, k, filter, metric, asOf = "as_of" }
}

private struct VectorCreatePayload: Encodable {
    let branch: String?
    let space: String?
    let collection: String
    let dimension: UInt64
    let metric: DistanceMetric
}

private struct VectorBatchPayload: Encodable {
    let branch: String?
    let space: String?
    let collection: String
    let entries: [BatchVectorEntry]
}

private struct BranchCreatePayload: Encodable {
    let branchId: String?
    let metadata: StrataValue?
    enum CodingKeys: String, CodingKey { case branchId = "branch_id", metadata }
}

private struct BranchListPayload: Encodable {
    let state: BranchStatus?
    let limit: UInt64?
    let offset: UInt64?
}

private struct BranchForkPayload: Encodable {
    let source: String
    let destination: String
}

private struct BranchDiffPayload: Encodable {
    let branchA: String
    let branchB: String
    enum CodingKeys: String, CodingKey { case branchA = "branch_a", branchB = "branch_b" }
}

private struct BranchMergePayload: Encodable {
    let source: String
    let target: String
    let strategy: MergeStrategy
}

private struct TxnBeginPayload: Encodable {
    let branch: String?
    let options: TxnOptions?
}

private struct BranchExportPayload: Encodable {
    let branchId: String
    let path: String
    enum CodingKeys: String, CodingKey { case branchId = "branch_id", path }
}

private struct PathPayload: Encodable {
    let path: String
}

private struct ConfigureModelPayload: Encodable {
    let endpoint: String
    let model: String
    let apiKey: String?
    let timeoutMs: UInt64?
    enum CodingKeys: String, CodingKey { case endpoint, model, apiKey = "api_key", timeoutMs = "timeout_ms" }
}

private struct SearchPayload: Encodable {
    let branch: String?
    let space: String?
    let search: SearchQuery
}

private struct EmbedPayload: Encodable {
    let text: String
}

private struct EmbedBatchPayload: Encodable {
    let texts: [String]
}

private struct NamePayload: Encodable {
    let name: String
}

private struct ModelPayload: Encodable {
    let model: String
}

private struct GeneratePayload: Encodable {
    let model: String
    let prompt: String
    let maxTokens: Int?
    let temperature: Float?
    let topK: Int?
    let topP: Float?
    let seed: UInt64?
    let stopTokens: [UInt32]?
    enum CodingKeys: String, CodingKey {
        case model, prompt
        case maxTokens = "max_tokens"
        case temperature
        case topK = "top_k"
        case topP = "top_p"
        case seed
        case stopTokens = "stop_tokens"
    }
}

private struct TokenizePayload: Encodable {
    let model: String
    let text: String
    let addSpecialTokens: Bool?
    enum CodingKeys: String, CodingKey { case model, text, addSpecialTokens = "add_special_tokens" }
}

private struct DetokenizePayload: Encodable {
    let model: String
    let ids: [UInt32]
}

private struct SpacePayload: Encodable {
    let branch: String?
    let space: String
}

private struct SpaceDeletePayload: Encodable {
    let branch: String?
    let space: String
    let force: Bool
}

private struct AutoEmbedPayload: Encodable {
    let enabled: Bool
}

private struct GraphCreatePayload: Encodable {
    let branch: String?
    let graph: String
    let cascadePolicy: String?
    enum CodingKeys: String, CodingKey { case branch, graph, cascadePolicy = "cascade_policy" }
}

private struct GraphNodePayload: Encodable {
    let branch: String?
    let graph: String
    let nodeId: String
    enum CodingKeys: String, CodingKey { case branch, graph, nodeId = "node_id" }
}

private struct GraphAddNodePayload: Encodable {
    let branch: String?
    let graph: String
    let nodeId: String
    let entityRef: String?
    let properties: StrataValue?
    enum CodingKeys: String, CodingKey { case branch, graph, nodeId = "node_id", entityRef = "entity_ref", properties }
}

private struct GraphAddEdgePayload: Encodable {
    let branch: String?
    let graph: String
    let src: String
    let dst: String
    let edgeType: String
    let weight: Double?
    let properties: StrataValue?
    enum CodingKeys: String, CodingKey { case branch, graph, src, dst, edgeType = "edge_type", weight, properties }
}

private struct GraphRemoveEdgePayload: Encodable {
    let branch: String?
    let graph: String
    let src: String
    let dst: String
    let edgeType: String
    enum CodingKeys: String, CodingKey { case branch, graph, src, dst, edgeType = "edge_type" }
}

private struct GraphNeighborsPayload: Encodable {
    let branch: String?
    let graph: String
    let nodeId: String
    let direction: String?
    let edgeType: String?
    enum CodingKeys: String, CodingKey { case branch, graph, nodeId = "node_id", direction, edgeType = "edge_type" }
}

private struct GraphBulkInsertPayload: Encodable {
    let branch: String?
    let graph: String
    let nodes: [BulkGraphNode]
    let edges: [BulkGraphEdge]
    let chunkSize: Int?
    enum CodingKeys: String, CodingKey { case branch, graph, nodes, edges, chunkSize = "chunk_size" }
}

private struct GraphBfsPayload: Encodable {
    let branch: String?
    let graph: String
    let start: String
    let maxDepth: Int
    let maxNodes: Int?
    let edgeTypes: [String]?
    let direction: String?
    enum CodingKeys: String, CodingKey {
        case branch, graph, start
        case maxDepth = "max_depth"
        case maxNodes = "max_nodes"
        case edgeTypes = "edge_types"
        case direction
    }
}
