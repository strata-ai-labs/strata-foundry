//
//  ModelService.swift
//  StrataFoundry
//
//  Model registry and embedding operations.
//

import Foundation

final class ModelService: Sendable {
    private let client: StrataTypedClient
    init(client: StrataTypedClient) { self.client = client }

    func listRegistry() async throws -> [ModelInfoOutput] {
        let output = try await client.execute(.modelsList)
        guard case .modelsList(let models) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "ModelsList", got: output.variantName)
        }
        return models
    }

    func listLocal() async throws -> [ModelInfoOutput] {
        let output = try await client.execute(.modelsLocal)
        guard case .modelsList(let models) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "ModelsList", got: output.variantName)
        }
        return models
    }

    func pull(name: String) async throws -> (name: String, path: String) {
        let output = try await client.execute(.modelsPull(name: name))
        guard case .modelsPulled(let name, let path) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "ModelsPulled", got: output.variantName)
        }
        return (name: name, path: path)
    }

    func embed(text: String) async throws -> [Float] {
        let output = try await client.execute(.embed(text: text))
        guard case .embedding(let vec) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Embedding", got: output.variantName)
        }
        return vec
    }

    func embedBatch(texts: [String]) async throws -> [[Float]] {
        let output = try await client.execute(.embedBatch(texts: texts))
        guard case .embeddings(let vecs) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Embeddings", got: output.variantName)
        }
        return vecs
    }

    func embedStatus() async throws -> EmbedStatusInfo {
        let output = try await client.execute(.embedStatus)
        guard case .embedStatus(let info) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "EmbedStatus", got: output.variantName)
        }
        return info
    }
}
