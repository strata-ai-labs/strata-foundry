//  EventService.swift - Event log operations

import Foundation

final class EventService: Sendable {
    private let client: StrataTypedClient
    init(client: StrataTypedClient) { self.client = client }

    func append(eventType: String, payload: StrataValue, branch: String? = nil, space: String? = nil) async throws -> UInt64 {
        let output = try await client.execute(.eventAppend(branch: branch, space: space, eventType: eventType, payload: payload))
        guard case .version(let v) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Version", got: output.variantName)
        }
        return v
    }

    func batchAppend(entries: [BatchEventEntry], branch: String? = nil, space: String? = nil) async throws -> [BatchItemResult] {
        let output = try await client.execute(.eventBatchAppend(branch: branch, space: space, entries: entries))
        guard case .batchResults(let results) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "BatchResults", got: output.variantName)
        }
        return results
    }

    func get(sequence: UInt64, branch: String? = nil, space: String? = nil, asOf: UInt64? = nil) async throws -> VersionedValue? {
        let output = try await client.execute(.eventGet(branch: branch, space: space, sequence: sequence, asOf: asOf))
        guard case .maybeVersioned(let vv) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "MaybeVersioned", got: output.variantName)
        }
        return vv
    }

    func getByType(eventType: String, branch: String? = nil, space: String? = nil, limit: UInt64? = nil, afterSequence: UInt64? = nil, asOf: UInt64? = nil) async throws -> [VersionedValue] {
        let output = try await client.execute(.eventGetByType(branch: branch, space: space, eventType: eventType, limit: limit, afterSequence: afterSequence, asOf: asOf))
        guard case .versionedValues(let values) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "VersionedValues", got: output.variantName)
        }
        return values
    }

    func len(branch: String? = nil, space: String? = nil) async throws -> UInt64 {
        let output = try await client.execute(.eventLen(branch: branch, space: space))
        guard case .uint(let count) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Uint", got: output.variantName)
        }
        return count
    }
}
