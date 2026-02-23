//
//  SearchService.swift
//  StrataFoundry
//
//  Cross-primitive search operations.
//

import Foundation

final class SearchService: Sendable {
    private let client: StrataTypedClient
    init(client: StrataTypedClient) { self.client = client }

    func search(query: String, k: UInt64? = nil, primitives: [String]? = nil, timeRange: TimeRangeInput? = nil, mode: String? = nil, expand: Bool? = nil, rerank: Bool? = nil, branch: String? = nil, space: String? = nil) async throws -> [SearchResultHit] {
        let searchQuery = SearchQuery(query: query, k: k, primitives: primitives, timeRange: timeRange, mode: mode, expand: expand, rerank: rerank)
        let output = try await client.execute(.search(branch: branch, space: space, search: searchQuery))
        guard case .searchResults(let results) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "SearchResults", got: output.variantName)
        }
        return results
    }

    func configureModel(endpoint: String, model: String, apiKey: String? = nil, timeoutMs: UInt64? = nil) async throws {
        let output = try await client.execute(.configureModel(endpoint: endpoint, model: model, apiKey: apiKey, timeoutMs: timeoutMs))
        guard case .unit = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Unit", got: output.variantName)
        }
    }
}
