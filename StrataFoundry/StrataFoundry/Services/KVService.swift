//  KVService.swift - Key-Value store operations

import Foundation

final class KVService: Sendable {
    private let client: StrataTypedClient
    init(client: StrataTypedClient) { self.client = client }

    func get(key: String, branch: String? = nil, space: String? = nil, asOf: UInt64? = nil) async throws -> VersionedValue? {
        let output = try await client.execute(.kvGet(branch: branch, space: space, key: key, asOf: asOf))
        guard case .maybeVersioned(let vv) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "MaybeVersioned", got: output.variantName)
        }
        return vv
    }

    func put(key: String, value: StrataValue, branch: String? = nil, space: String? = nil) async throws -> UInt64 {
        let output = try await client.execute(.kvPut(branch: branch, space: space, key: key, value: value))
        guard case .version(let v) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Version", got: output.variantName)
        }
        return v
    }

    func delete(key: String, branch: String? = nil, space: String? = nil) async throws -> Bool {
        let output = try await client.execute(.kvDelete(branch: branch, space: space, key: key))
        guard case .bool(let b) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Bool", got: output.variantName)
        }
        return b
    }

    func list(branch: String? = nil, space: String? = nil, prefix: String? = nil, cursor: String? = nil, limit: UInt64? = nil, asOf: UInt64? = nil) async throws -> [String] {
        let output = try await client.execute(.kvList(branch: branch, space: space, prefix: prefix, cursor: cursor, limit: limit, asOf: asOf))
        guard case .keys(let keys) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Keys", got: output.variantName)
        }
        return keys
    }

    func batchPut(entries: [BatchKvEntry], branch: String? = nil, space: String? = nil) async throws -> [BatchItemResult] {
        let output = try await client.execute(.kvBatchPut(branch: branch, space: space, entries: entries))
        guard case .batchResults(let results) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "BatchResults", got: output.variantName)
        }
        return results
    }

    func getVersionHistory(key: String, branch: String? = nil, space: String? = nil, asOf: UInt64? = nil) async throws -> [VersionedValue]? {
        let output = try await client.execute(.kvGetv(branch: branch, space: space, key: key, asOf: asOf))
        guard case .versionHistory(let history) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "VersionHistory", got: output.variantName)
        }
        return history
    }
}
