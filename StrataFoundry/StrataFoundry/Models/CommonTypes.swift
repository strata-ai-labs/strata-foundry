//
//  CommonTypes.swift
//  StrataFoundry
//
//  Codable Swift types mirroring Rust's supporting types from executor/types.rs.
//  All types use snake_case CodingKeys to match Rust's serde format.
//

import Foundation

// MARK: - Versioned Types

/// A value with version metadata — the most common return type for get operations.
struct VersionedValue: Codable, Hashable, Sendable {
    let value: StrataValue
    let version: UInt64
    let timestamp: UInt64

    /// Human-readable date from the microsecond timestamp.
    var date: Date {
        Date(timeIntervalSince1970: Double(timestamp) / 1_000_000.0)
    }
}

// MARK: - Branch Types

/// Branch identifier (wraps a string).
/// In JSON, serialized as a bare string: `"default"`.
struct BranchId: Codable, Hashable, Sendable {
    let value: String

    init(_ value: String) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.value = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

/// Branch status.
enum BranchStatus: String, Codable, Sendable {
    case active
}

/// Branch information.
struct BranchInfo: Codable, Sendable {
    let id: BranchId
    let status: BranchStatus
    let createdAt: UInt64
    let updatedAt: UInt64
    let parentId: BranchId?

    enum CodingKeys: String, CodingKey {
        case id, status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case parentId = "parent_id"
    }
}

/// Versioned branch information.
struct VersionedBranchInfo: Codable, Sendable {
    let info: BranchInfo
    let version: UInt64
    let timestamp: UInt64
}

// MARK: - Database Types

/// Database information from the Info command.
struct StrataDatabaseInfo: Codable, Sendable {
    let version: String
    let uptimeSecs: UInt64
    let branchCount: UInt64
    let totalKeys: UInt64

    enum CodingKeys: String, CodingKey {
        case version
        case uptimeSecs = "uptime_secs"
        case branchCount = "branch_count"
        case totalKeys = "total_keys"
    }
}

// MARK: - Vector Types

/// Distance metric for vector similarity search.
enum DistanceMetric: String, Codable, Sendable {
    case cosine
    case euclidean
    case dotProduct = "dot_product"
}

/// Filter operation for vector metadata search.
enum FilterOp: String, Codable, Sendable {
    case eq, ne, gt, gte, lt, lte
    case `in`
    case contains
}

/// Metadata filter for vector search.
struct MetadataFilter: Codable, Sendable {
    let field: String
    let op: FilterOp
    let value: StrataValue
}

/// Vector data (embedding + metadata).
struct VectorData: Codable, Sendable {
    let embedding: [Float]
    let metadata: StrataValue?
}

/// Versioned vector data.
struct VersionedVectorData: Codable, Sendable {
    let key: String
    let data: VectorData
    let version: UInt64
    let timestamp: UInt64
}

/// Vector search match result.
struct VectorMatch: Codable, Sendable {
    let key: String
    let score: Float
    let metadata: StrataValue?
}

/// Vector collection information.
struct CollectionInfo: Codable, Sendable {
    let name: String
    let dimension: Int
    let metric: DistanceMetric
    let count: UInt64
    let indexType: String?
    let memoryBytes: UInt64?

    enum CodingKeys: String, CodingKey {
        case name, dimension, metric, count
        case indexType = "index_type"
        case memoryBytes = "memory_bytes"
    }
}

// MARK: - Batch Entry Types

/// Entry for batch KV put operations.
struct BatchKvEntry: Codable, Sendable {
    let key: String
    let value: StrataValue
}

/// Entry for batch event append operations.
struct BatchEventEntry: Codable, Sendable {
    let eventType: String
    let payload: StrataValue

    enum CodingKeys: String, CodingKey {
        case eventType = "event_type"
        case payload
    }
}

/// Entry for batch state set operations.
struct BatchStateEntry: Codable, Sendable {
    let cell: String
    let value: StrataValue
}

/// Entry for batch JSON set operations.
struct BatchJsonEntry: Codable, Sendable {
    let key: String
    let path: String
    let value: StrataValue
}

/// Batch vector entry for bulk upsert.
struct BatchVectorEntry: Codable, Sendable {
    let key: String
    let vector: [Float]
    let metadata: StrataValue?
}

/// Per-item result for batch operations.
struct BatchItemResult: Codable, Sendable {
    let version: UInt64?
    let error: String?
}

// MARK: - Transaction Types

/// Transaction options.
struct TxnOptions: Codable, Sendable {
    let readOnly: Bool

    enum CodingKeys: String, CodingKey {
        case readOnly = "read_only"
    }
}

/// Transaction status.
enum TxnStatus: String, Codable, Sendable {
    case active
    case committed
    case rolledBack = "rolled_back"
}

/// Transaction information.
struct TransactionInfo: Codable, Sendable {
    let id: String
    let status: TxnStatus
    let startedAt: UInt64

    enum CodingKeys: String, CodingKey {
        case id, status
        case startedAt = "started_at"
    }
}

// MARK: - Bundle Types

/// Information about a branch export operation.
struct StrataBranchExportResult: Codable, Sendable {
    let branchId: String
    let path: String
    let entryCount: UInt64
    let bundleSize: UInt64

    enum CodingKeys: String, CodingKey {
        case branchId = "branch_id"
        case path
        case entryCount = "entry_count"
        case bundleSize = "bundle_size"
    }
}

/// Information about a branch import operation.
struct StrataBranchImportResult: Codable, Sendable {
    let branchId: String
    let transactionsApplied: UInt64
    let keysWritten: UInt64

    enum CodingKeys: String, CodingKey {
        case branchId = "branch_id"
        case transactionsApplied = "transactions_applied"
        case keysWritten = "keys_written"
    }
}

/// Information about bundle validation.
struct StrataBundleValidateResult: Codable, Sendable {
    let branchId: String
    let formatVersion: UInt32
    let entryCount: UInt64
    let checksumsValid: Bool

    enum CodingKeys: String, CodingKey {
        case branchId = "branch_id"
        case formatVersion = "format_version"
        case entryCount = "entry_count"
        case checksumsValid = "checksums_valid"
    }
}

// MARK: - Search / Intelligence Types

/// Time range for search queries (ISO 8601 strings).
struct TimeRangeInput: Codable, Sendable {
    let start: String
    let end: String
}

/// Structured search query.
struct SearchQuery: Codable, Sendable {
    let query: String
    var k: UInt64?
    var primitives: [String]?
    var timeRange: TimeRangeInput?
    var mode: String?
    var expand: Bool?
    var rerank: Bool?

    enum CodingKeys: String, CodingKey {
        case query, k, primitives
        case timeRange = "time_range"
        case mode, expand, rerank
    }
}

/// A single hit from a cross-primitive search.
struct SearchResultHit: Codable, Sendable {
    let entity: String
    let primitive: String
    let score: Float
    let rank: UInt32
    let snippet: String?
}

// MARK: - Model / Generation Types

/// Information about a model in the registry.
struct ModelInfoOutput: Codable, Sendable {
    let name: String
    let task: String
    let architecture: String
    let defaultQuant: String
    let embeddingDim: Int
    let isLocal: Bool
    let sizeBytes: UInt64

    enum CodingKeys: String, CodingKey {
        case name, task, architecture
        case defaultQuant = "default_quant"
        case embeddingDim = "embedding_dim"
        case isLocal = "is_local"
        case sizeBytes = "size_bytes"
    }
}

/// Result of text generation.
struct GenerationResult: Codable, Sendable {
    let text: String
    let stopReason: String
    let promptTokens: Int
    let completionTokens: Int
    let model: String

    enum CodingKeys: String, CodingKey {
        case text
        case stopReason = "stop_reason"
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case model
    }
}

/// Result of tokenization.
struct TokenizeResult: Codable, Sendable {
    let ids: [UInt32]
    let count: Int
    let model: String
}

// MARK: - Graph Types

/// A neighbor entry from graph neighbor queries.
struct GraphNeighborHit: Codable, Sendable {
    let nodeId: String
    let edgeType: String
    let weight: Double

    enum CodingKeys: String, CodingKey {
        case nodeId = "node_id"
        case edgeType = "edge_type"
        case weight
    }
}

/// BFS traversal result.
struct GraphBfsResult: Codable, Sendable {
    let visited: [String]
    let depths: [String: Int]
    let edges: [[String]]

    /// Parse the edges tuples — Rust serializes (String, String, String) as [String, String, String].
    var parsedEdges: [(src: String, dst: String, edgeType: String)] {
        edges.compactMap { tuple in
            guard tuple.count == 3 else { return nil }
            return (src: tuple[0], dst: tuple[1], edgeType: tuple[2])
        }
    }
}

/// A node entry for bulk graph insertion.
struct BulkGraphNode: Codable, Sendable {
    let nodeId: String
    var entityRef: String?
    var properties: StrataValue?

    enum CodingKeys: String, CodingKey {
        case nodeId = "node_id"
        case entityRef = "entity_ref"
        case properties
    }
}

/// An edge entry for bulk graph insertion.
struct BulkGraphEdge: Codable, Sendable {
    let src: String
    let dst: String
    let edgeType: String
    var weight: Double?
    var properties: StrataValue?

    enum CodingKeys: String, CodingKey {
        case src, dst
        case edgeType = "edge_type"
        case weight, properties
    }
}

// MARK: - Embedding Types

/// Embedding pipeline status.
struct EmbedStatusInfo: Codable, Sendable {
    let autoEmbed: Bool
    let batchSize: Int
    let pending: Int
    let totalQueued: UInt64
    let totalEmbedded: UInt64
    let totalFailed: UInt64
    let schedulerQueueDepth: Int
    let schedulerActiveTasks: Int

    enum CodingKeys: String, CodingKey {
        case autoEmbed = "auto_embed"
        case batchSize = "batch_size"
        case pending
        case totalQueued = "total_queued"
        case totalEmbedded = "total_embedded"
        case totalFailed = "total_failed"
        case schedulerQueueDepth = "scheduler_queue_depth"
        case schedulerActiveTasks = "scheduler_active_tasks"
    }
}

// MARK: - Branch Operation Types

/// Merge strategy for branch merges.
enum MergeStrategy: String, Codable, Sendable {
    case lastWriterWins = "LastWriterWins"
    case strict = "Strict"
}

/// Information returned after forking a branch.
struct ForkInfo: Codable, Sendable {
    let source: String
    let destination: String
    let keysCopied: UInt64
    let spacesCopied: UInt64

    enum CodingKeys: String, CodingKey {
        case source, destination
        case keysCopied = "keys_copied"
        case spacesCopied = "spaces_copied"
    }
}

/// Complete result of comparing two branches.
struct BranchDiffResult: Codable, Sendable {
    let branchA: String
    let branchB: String
    let spaces: [SpaceDiff]
    let summary: DiffSummary

    enum CodingKeys: String, CodingKey {
        case branchA = "branch_a"
        case branchB = "branch_b"
        case spaces, summary
    }
}

/// Per-space diff result.
struct SpaceDiff: Codable, Sendable {
    let space: String
    let onlyInA: [String]
    let onlyInB: [String]
    let modified: [String]

    enum CodingKeys: String, CodingKey {
        case space
        case onlyInA = "only_in_a"
        case onlyInB = "only_in_b"
        case modified
    }
}

/// Aggregate diff summary.
struct DiffSummary: Codable, Sendable {
    let totalOnlyInA: UInt64
    let totalOnlyInB: UInt64
    let totalModified: UInt64

    enum CodingKeys: String, CodingKey {
        case totalOnlyInA = "total_only_in_a"
        case totalOnlyInB = "total_only_in_b"
        case totalModified = "total_modified"
    }
}

/// Information returned after merging branches.
struct MergeInfo: Codable, Sendable {
    let source: String
    let target: String
    let keysApplied: UInt64
    let conflicts: [ConflictEntry]
    let spacesMerged: UInt64

    enum CodingKeys: String, CodingKey {
        case source, target
        case keysApplied = "keys_applied"
        case conflicts
        case spacesMerged = "spaces_merged"
    }
}

/// A conflict entry from merge operations.
struct ConflictEntry: Codable, Sendable {
    let key: String
    let space: String?
}

// MARK: - Config Types

/// Database configuration snapshot.
struct StrataConfig: Codable, Sendable {
    let durability: String
    let autoEmbed: Bool
    let model: ModelConfig?
    let embedBatchSize: Int?
    let bm25K1: Float?
    let bm25B: Float?

    enum CodingKeys: String, CodingKey {
        case durability
        case autoEmbed = "auto_embed"
        case model
        case embedBatchSize = "embed_batch_size"
        case bm25K1 = "bm25_k1"
        case bm25B = "bm25_b"
    }
}

/// Model configuration within StrataConfig.
struct ModelConfig: Codable, Sendable {
    let endpoint: String?
    let model: String?
    let apiKey: String?
    let timeoutMs: UInt64?

    enum CodingKeys: String, CodingKey {
        case endpoint, model
        case apiKey = "api_key"
        case timeoutMs = "timeout_ms"
    }
}

// MARK: - WAL Types

/// Cumulative WAL operation counters.
struct WalCounters: Codable, Sendable {
    let walAppends: UInt64
    let syncCalls: UInt64
    let bytesWritten: UInt64
    let syncNanos: UInt64

    enum CodingKeys: String, CodingKey {
        case walAppends = "wal_appends"
        case syncCalls = "sync_calls"
        case bytesWritten = "bytes_written"
        case syncNanos = "sync_nanos"
    }
}

// MARK: - Service Error

/// Errors from typed service operations.
enum StrataServiceError: Error, LocalizedError {
    case unexpectedOutput(expected: String, got: String)
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .unexpectedOutput(let expected, let got):
            return "Expected \(expected), got \(got)"
        case .executionFailed(let msg):
            return msg
        }
    }
}
