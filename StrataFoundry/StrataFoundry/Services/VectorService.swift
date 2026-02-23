//
//  VectorService.swift
//  StrataFoundry
//
//  Vector store operations.
//

import Foundation

final class VectorService: Sendable {
    private let client: StrataTypedClient
    init(client: StrataTypedClient) { self.client = client }

    func upsert(collection: String, key: String, vector: [Float], metadata: StrataValue? = nil, branch: String? = nil, space: String? = nil) async throws -> UInt64 {
        let output = try await client.execute(.vectorUpsert(branch: branch, space: space, collection: collection, key: key, vector: vector, metadata: metadata))
        guard case .version(let v) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Version", got: output.variantName)
        }
        return v
    }

    func get(collection: String, key: String, branch: String? = nil, space: String? = nil, asOf: UInt64? = nil) async throws -> VersionedVectorData? {
        let output = try await client.execute(.vectorGet(branch: branch, space: space, collection: collection, key: key, asOf: asOf))
        guard case .vectorData(let data) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "VectorData", got: output.variantName)
        }
        return data
    }

    func delete(collection: String, key: String, branch: String? = nil, space: String? = nil) async throws -> Bool {
        let output = try await client.execute(.vectorDelete(branch: branch, space: space, collection: collection, key: key))
        guard case .bool(let b) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Bool", got: output.variantName)
        }
        return b
    }

    func search(collection: String, query: [Float], k: UInt64 = 10, filter: [MetadataFilter]? = nil, metric: DistanceMetric? = nil, branch: String? = nil, space: String? = nil, asOf: UInt64? = nil) async throws -> [VectorMatch] {
        let output = try await client.execute(.vectorSearch(branch: branch, space: space, collection: collection, query: query, k: k, filter: filter, metric: metric, asOf: asOf))
        guard case .vectorMatches(let matches) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "VectorMatches", got: output.variantName)
        }
        return matches
    }

    func createCollection(collection: String, dimension: UInt64, metric: DistanceMetric, branch: String? = nil, space: String? = nil) async throws -> UInt64 {
        let output = try await client.execute(.vectorCreateCollection(branch: branch, space: space, collection: collection, dimension: dimension, metric: metric))
        guard case .version(let v) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Version", got: output.variantName)
        }
        return v
    }

    func deleteCollection(collection: String, branch: String? = nil, space: String? = nil) async throws -> Bool {
        let output = try await client.execute(.vectorDeleteCollection(branch: branch, space: space, collection: collection))
        guard case .bool(let b) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Bool", got: output.variantName)
        }
        return b
    }

    func listCollections(branch: String? = nil, space: String? = nil) async throws -> [CollectionInfo] {
        let output = try await client.execute(.vectorListCollections(branch: branch, space: space))
        guard case .vectorCollectionList(let list) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "VectorCollectionList", got: output.variantName)
        }
        return list
    }

    func collectionStats(collection: String, branch: String? = nil, space: String? = nil) async throws -> CollectionInfo? {
        let output = try await client.execute(.vectorCollectionStats(branch: branch, space: space, collection: collection))
        guard case .vectorCollectionList(let list) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "VectorCollectionList", got: output.variantName)
        }
        return list.first
    }

    func batchUpsert(collection: String, entries: [BatchVectorEntry], branch: String? = nil, space: String? = nil) async throws -> [UInt64] {
        let output = try await client.execute(.vectorBatchUpsert(branch: branch, space: space, collection: collection, entries: entries))
        guard case .versions(let versions) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Versions", got: output.variantName)
        }
        return versions
    }
}
