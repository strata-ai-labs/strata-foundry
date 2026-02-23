//  StateService.swift - State cell operations

import Foundation

final class StateService: Sendable {
    private let client: StrataTypedClient
    init(client: StrataTypedClient) { self.client = client }

    func get(cell: String, branch: String? = nil, space: String? = nil, asOf: UInt64? = nil) async throws -> VersionedValue? {
        let output = try await client.execute(.stateGet(branch: branch, space: space, cell: cell, asOf: asOf))
        guard case .maybeVersioned(let vv) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "MaybeVersioned", got: output.variantName)
        }
        return vv
    }

    func set(cell: String, value: StrataValue, branch: String? = nil, space: String? = nil) async throws -> UInt64 {
        let output = try await client.execute(.stateSet(branch: branch, space: space, cell: cell, value: value))
        guard case .version(let v) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Version", got: output.variantName)
        }
        return v
    }

    func delete(cell: String, branch: String? = nil, space: String? = nil) async throws -> Bool {
        let output = try await client.execute(.stateDelete(branch: branch, space: space, cell: cell))
        guard case .bool(let b) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Bool", got: output.variantName)
        }
        return b
    }

    func list(branch: String? = nil, space: String? = nil, prefix: String? = nil, asOf: UInt64? = nil) async throws -> [String] {
        let output = try await client.execute(.stateList(branch: branch, space: space, prefix: prefix, asOf: asOf))
        guard case .keys(let keys) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Keys", got: output.variantName)
        }
        return keys
    }

    func batchSet(entries: [BatchStateEntry], branch: String? = nil, space: String? = nil) async throws -> [BatchItemResult] {
        let output = try await client.execute(.stateBatchSet(branch: branch, space: space, entries: entries))
        guard case .batchResults(let results) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "BatchResults", got: output.variantName)
        }
        return results
    }

    func cas(cell: String, expectedCounter: UInt64?, value: StrataValue, branch: String? = nil, space: String? = nil) async throws -> UInt64? {
        let output = try await client.execute(.stateCas(branch: branch, space: space, cell: cell, expectedCounter: expectedCounter, value: value))
        guard case .maybeVersion(let v) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "MaybeVersion", got: output.variantName)
        }
        return v
    }

    func initialize(cell: String, value: StrataValue, branch: String? = nil, space: String? = nil) async throws -> UInt64 {
        let output = try await client.execute(.stateInit(branch: branch, space: space, cell: cell, value: value))
        guard case .version(let v) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Version", got: output.variantName)
        }
        return v
    }

    func getVersionHistory(cell: String, branch: String? = nil, space: String? = nil, asOf: UInt64? = nil) async throws -> [VersionedValue]? {
        let output = try await client.execute(.stateGetv(branch: branch, space: space, cell: cell, asOf: asOf))
        guard case .versionHistory(let history) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "VersionHistory", got: output.variantName)
        }
        return history
    }
}
