//
//  StrataOutput.swift
//  StrataFoundry
//
//  Decodable enum mirroring Rust's Output enum from executor/output.rs.
//  Parses externally-tagged JSON responses: {"MaybeVersioned": {...}}.
//

import Foundation

/// All possible Strata command output types as a typed, Decodable enum.
///
/// Each case maps to exactly one Rust `Output` variant.
/// The JSON uses Rust's serde externally-tagged format.
enum StrataOutput: Decodable, Sendable {

    // Primitive Results
    case unit
    case maybe(StrataValue?)
    case maybeVersioned(VersionedValue?)
    case maybeVersion(UInt64?)
    case version(UInt64)
    case bool(Bool)
    case uint(UInt64)

    // Collections
    case versionedValues([VersionedValue])
    case versionHistory([VersionedValue]?)
    case keys([String])

    // Scan Results
    case jsonListResult(keys: [String], cursor: String?)

    // Search Results
    case vectorMatches([VectorMatch])

    // Vector-specific
    case vectorData(VersionedVectorData?)
    case vectorCollectionList([CollectionInfo])
    case versions([UInt64])
    case batchResults([BatchItemResult])

    // Branch-specific
    case maybeBranchInfo(VersionedBranchInfo?)
    case branchInfoList([VersionedBranchInfo])
    case branchWithVersion(info: BranchInfo, version: UInt64)
    case branchForked(ForkInfo)
    case branchDiff(BranchDiffResult)
    case branchMerged(MergeInfo)
    case config(StrataConfig)
    case durabilityCounters(WalCounters)

    // Transaction-specific
    case txnInfo(TransactionInfo?)
    case txnBegun
    case txnCommitted(version: UInt64)
    case txnAborted

    // Database-specific
    case databaseInfo(StrataDatabaseInfo)
    case pong(version: String)

    // Intelligence
    case searchResults([SearchResultHit])

    // Space
    case spaceList([String])

    // Bundle
    case branchExported(StrataBranchExportResult)
    case branchImported(StrataBranchImportResult)
    case bundleValidated(StrataBundleValidateResult)

    // Time range
    case timeRange(oldestTs: UInt64?, latestTs: UInt64?)

    // Embedding
    case embedStatus(EmbedStatusInfo)
    case embedding([Float])
    case embeddings([[Float]])

    // Models
    case modelsList([ModelInfoOutput])

    // Generation
    case generated(GenerationResult)
    case tokenIds(TokenizeResult)
    case text(String)

    // Graph
    case graphNeighbors([GraphNeighborHit])
    case graphBfs(GraphBfsResult)
    case graphBulkInsertResult(nodesInserted: UInt64, edgesInserted: UInt64)

    // Model pull
    case modelsPulled(name: String, path: String)

    // MARK: - Decodable

    init(from decoder: Decoder) throws {
        // Try bare string first: "Unit", "TxnBegun", "TxnAborted"
        if let container = try? decoder.singleValueContainer(),
           let str = try? container.decode(String.self) {
            switch str {
            case "Unit":
                self = .unit
                return
            case "TxnBegun":
                self = .txnBegun
                return
            case "TxnAborted":
                self = .txnAborted
                return
            default:
                break
            }
        }

        // Externally-tagged: {"VariantName": payload}
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)

        guard let key = container.allKeys.first else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath,
                      debugDescription: "Empty object for StrataOutput"))
        }

        switch key.stringValue {
        case "Unit":
            self = .unit

        case "Maybe":
            let val = try container.decodeIfPresent(StrataValue.self, forKey: key)
            self = .maybe(val)

        case "MaybeVersioned":
            let val = try container.decodeIfPresent(VersionedValue.self, forKey: key)
            self = .maybeVersioned(val)

        case "MaybeVersion":
            let val = try container.decodeIfPresent(UInt64.self, forKey: key)
            self = .maybeVersion(val)

        case "Version":
            self = .version(try container.decode(UInt64.self, forKey: key))

        case "Bool":
            self = .bool(try container.decode(Bool.self, forKey: key))

        case "Uint":
            self = .uint(try container.decode(UInt64.self, forKey: key))

        case "VersionedValues":
            self = .versionedValues(try container.decode([VersionedValue].self, forKey: key))

        case "VersionHistory":
            let val = try container.decodeIfPresent([VersionedValue].self, forKey: key)
            self = .versionHistory(val)

        case "Keys":
            self = .keys(try container.decode([String].self, forKey: key))

        case "JsonListResult":
            let payload = try container.decode(JsonListResultPayload.self, forKey: key)
            self = .jsonListResult(keys: payload.keys, cursor: payload.cursor)

        case "VectorMatches":
            self = .vectorMatches(try container.decode([VectorMatch].self, forKey: key))

        case "VectorData":
            let val = try container.decodeIfPresent(VersionedVectorData.self, forKey: key)
            self = .vectorData(val)

        case "VectorCollectionList":
            self = .vectorCollectionList(try container.decode([CollectionInfo].self, forKey: key))

        case "Versions":
            self = .versions(try container.decode([UInt64].self, forKey: key))

        case "BatchResults":
            self = .batchResults(try container.decode([BatchItemResult].self, forKey: key))

        case "MaybeBranchInfo":
            let val = try container.decodeIfPresent(VersionedBranchInfo.self, forKey: key)
            self = .maybeBranchInfo(val)

        case "BranchInfoList":
            self = .branchInfoList(try container.decode([VersionedBranchInfo].self, forKey: key))

        case "BranchWithVersion":
            let payload = try container.decode(BranchWithVersionPayload.self, forKey: key)
            self = .branchWithVersion(info: payload.info, version: payload.version)

        case "BranchForked":
            self = .branchForked(try container.decode(ForkInfo.self, forKey: key))

        case "BranchDiff":
            self = .branchDiff(try container.decode(BranchDiffResult.self, forKey: key))

        case "BranchMerged":
            self = .branchMerged(try container.decode(MergeInfo.self, forKey: key))

        case "Config":
            self = .config(try container.decode(StrataConfig.self, forKey: key))

        case "DurabilityCounters":
            self = .durabilityCounters(try container.decode(WalCounters.self, forKey: key))

        case "TxnInfo":
            let val = try container.decodeIfPresent(TransactionInfo.self, forKey: key)
            self = .txnInfo(val)

        case "TxnBegun":
            self = .txnBegun

        case "TxnCommitted":
            let payload = try container.decode(TxnCommittedPayload.self, forKey: key)
            self = .txnCommitted(version: payload.version)

        case "TxnAborted":
            self = .txnAborted

        case "DatabaseInfo":
            self = .databaseInfo(try container.decode(StrataDatabaseInfo.self, forKey: key))

        case "Pong":
            let payload = try container.decode(PongPayload.self, forKey: key)
            self = .pong(version: payload.version)

        case "SearchResults":
            self = .searchResults(try container.decode([SearchResultHit].self, forKey: key))

        case "SpaceList":
            self = .spaceList(try container.decode([String].self, forKey: key))

        case "BranchExported":
            self = .branchExported(try container.decode(StrataBranchExportResult.self, forKey: key))

        case "BranchImported":
            self = .branchImported(try container.decode(StrataBranchImportResult.self, forKey: key))

        case "BundleValidated":
            self = .bundleValidated(try container.decode(StrataBundleValidateResult.self, forKey: key))

        case "TimeRange":
            let payload = try container.decode(TimeRangePayload.self, forKey: key)
            self = .timeRange(oldestTs: payload.oldestTs, latestTs: payload.latestTs)

        case "EmbedStatus":
            self = .embedStatus(try container.decode(EmbedStatusInfo.self, forKey: key))

        case "Embedding":
            self = .embedding(try container.decode([Float].self, forKey: key))

        case "Embeddings":
            self = .embeddings(try container.decode([[Float]].self, forKey: key))

        case "ModelsList":
            self = .modelsList(try container.decode([ModelInfoOutput].self, forKey: key))

        case "Generated":
            self = .generated(try container.decode(GenerationResult.self, forKey: key))

        case "TokenIds":
            self = .tokenIds(try container.decode(TokenizeResult.self, forKey: key))

        case "Text":
            self = .text(try container.decode(String.self, forKey: key))

        case "GraphNeighbors":
            self = .graphNeighbors(try container.decode([GraphNeighborHit].self, forKey: key))

        case "GraphBfs":
            self = .graphBfs(try container.decode(GraphBfsResult.self, forKey: key))

        case "GraphBulkInsertResult":
            let payload = try container.decode(GraphBulkInsertResultPayload.self, forKey: key)
            self = .graphBulkInsertResult(nodesInserted: payload.nodesInserted, edgesInserted: payload.edgesInserted)

        case "ModelsPulled":
            let payload = try container.decode(ModelsPulledPayload.self, forKey: key)
            self = .modelsPulled(name: payload.name, path: payload.path)

        default:
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath,
                      debugDescription: "Unknown StrataOutput variant: \(key.stringValue)"))
        }
    }

    /// Debug-friendly variant name.
    var variantName: String {
        switch self {
        case .unit: return "Unit"
        case .maybe: return "Maybe"
        case .maybeVersioned: return "MaybeVersioned"
        case .maybeVersion: return "MaybeVersion"
        case .version: return "Version"
        case .bool: return "Bool"
        case .uint: return "Uint"
        case .versionedValues: return "VersionedValues"
        case .versionHistory: return "VersionHistory"
        case .keys: return "Keys"
        case .jsonListResult: return "JsonListResult"
        case .vectorMatches: return "VectorMatches"
        case .vectorData: return "VectorData"
        case .vectorCollectionList: return "VectorCollectionList"
        case .versions: return "Versions"
        case .batchResults: return "BatchResults"
        case .maybeBranchInfo: return "MaybeBranchInfo"
        case .branchInfoList: return "BranchInfoList"
        case .branchWithVersion: return "BranchWithVersion"
        case .branchForked: return "BranchForked"
        case .branchDiff: return "BranchDiff"
        case .branchMerged: return "BranchMerged"
        case .config: return "Config"
        case .durabilityCounters: return "DurabilityCounters"
        case .txnInfo: return "TxnInfo"
        case .txnBegun: return "TxnBegun"
        case .txnCommitted: return "TxnCommitted"
        case .txnAborted: return "TxnAborted"
        case .databaseInfo: return "DatabaseInfo"
        case .pong: return "Pong"
        case .searchResults: return "SearchResults"
        case .spaceList: return "SpaceList"
        case .branchExported: return "BranchExported"
        case .branchImported: return "BranchImported"
        case .bundleValidated: return "BundleValidated"
        case .timeRange: return "TimeRange"
        case .embedStatus: return "EmbedStatus"
        case .embedding: return "Embedding"
        case .embeddings: return "Embeddings"
        case .modelsList: return "ModelsList"
        case .generated: return "Generated"
        case .tokenIds: return "TokenIds"
        case .text: return "Text"
        case .graphNeighbors: return "GraphNeighbors"
        case .graphBfs: return "GraphBfs"
        case .graphBulkInsertResult: return "GraphBulkInsertResult"
        case .modelsPulled: return "ModelsPulled"
        }
    }
}

// MARK: - Internal Decode Payloads

private struct JsonListResultPayload: Decodable {
    let keys: [String]
    let cursor: String?
}

private struct BranchWithVersionPayload: Decodable {
    let info: BranchInfo
    let version: UInt64
}

private struct TxnCommittedPayload: Decodable {
    let version: UInt64
}

private struct PongPayload: Decodable {
    let version: String
}

private struct TimeRangePayload: Decodable {
    let oldestTs: UInt64?
    let latestTs: UInt64?
    enum CodingKeys: String, CodingKey {
        case oldestTs = "oldest_ts"
        case latestTs = "latest_ts"
    }
}

private struct GraphBulkInsertResultPayload: Decodable {
    let nodesInserted: UInt64
    let edgesInserted: UInt64
    enum CodingKeys: String, CodingKey {
        case nodesInserted = "nodes_inserted"
        case edgesInserted = "edges_inserted"
    }
}

private struct ModelsPulledPayload: Decodable {
    let name: String
    let path: String
}
