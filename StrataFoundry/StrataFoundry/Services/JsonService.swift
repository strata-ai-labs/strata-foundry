//
//  JsonService.swift
//  StrataFoundry
//
//  JSON document store operations.
//

import Foundation

final class JsonService: Sendable {
    private let client: StrataTypedClient
    init(client: StrataTypedClient) { self.client = client }

    func set(key: String, path: String = "$", value: StrataValue, branch: String? = nil, space: String? = nil) async throws -> UInt64 {
        let output = try await client.execute(.jsonSet(branch: branch, space: space, key: key, path: path, value: value))
        guard case .version(let v) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Version", got: output.variantName)
        }
        return v
    }

    func get(key: String, path: String = "$", branch: String? = nil, space: String? = nil, asOf: UInt64? = nil) async throws -> VersionedValue? {
        let output = try await client.execute(.jsonGet(branch: branch, space: space, key: key, path: path, asOf: asOf))
        guard case .maybeVersioned(let vv) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "MaybeVersioned", got: output.variantName)
        }
        return vv
    }

    func delete(key: String, path: String = "$", branch: String? = nil, space: String? = nil) async throws -> UInt64 {
        let output = try await client.execute(.jsonDelete(branch: branch, space: space, key: key, path: path))
        guard case .uint(let count) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Uint", got: output.variantName)
        }
        return count
    }

    func list(branch: String? = nil, space: String? = nil, prefix: String? = nil, cursor: String? = nil, limit: UInt64 = 1000, asOf: UInt64? = nil) async throws -> (keys: [String], cursor: String?) {
        let output = try await client.execute(.jsonList(branch: branch, space: space, prefix: prefix, cursor: cursor, limit: limit, asOf: asOf))
        guard case .jsonListResult(let keys, let nextCursor) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "JsonListResult", got: output.variantName)
        }
        return (keys: keys, cursor: nextCursor)
    }

    func batchSet(entries: [BatchJsonEntry], branch: String? = nil, space: String? = nil) async throws -> [BatchItemResult] {
        let output = try await client.execute(.jsonBatchSet(branch: branch, space: space, entries: entries))
        guard case .batchResults(let results) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "BatchResults", got: output.variantName)
        }
        return results
    }

    func getVersionHistory(key: String, branch: String? = nil, space: String? = nil, asOf: UInt64? = nil) async throws -> [VersionedValue]? {
        let output = try await client.execute(.jsonGetv(branch: branch, space: space, key: key, asOf: asOf))
        guard case .versionHistory(let history) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "VersionHistory", got: output.variantName)
        }
        return history
    }
}
