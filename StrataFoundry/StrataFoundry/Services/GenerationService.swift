//
//  GenerationService.swift
//  StrataFoundry
//
//  Text generation operations.
//

import Foundation

final class GenerationService: Sendable {
    private let client: StrataTypedClient
    init(client: StrataTypedClient) { self.client = client }

    func generate(model: String, prompt: String, maxTokens: Int? = nil, temperature: Float? = nil, topK: Int? = nil, topP: Float? = nil, seed: UInt64? = nil, stopTokens: [UInt32]? = nil) async throws -> GenerationResult {
        let output = try await client.execute(.generate(model: model, prompt: prompt, maxTokens: maxTokens, temperature: temperature, topK: topK, topP: topP, seed: seed, stopTokens: stopTokens))
        guard case .generated(let result) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Generated", got: output.variantName)
        }
        return result
    }

    func tokenize(model: String, text: String, addSpecialTokens: Bool? = nil) async throws -> TokenizeResult {
        let output = try await client.execute(.tokenize(model: model, text: text, addSpecialTokens: addSpecialTokens))
        guard case .tokenIds(let result) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "TokenIds", got: output.variantName)
        }
        return result
    }

    func detokenize(model: String, ids: [UInt32]) async throws -> String {
        let output = try await client.execute(.detokenize(model: model, ids: ids))
        guard case .text(let text) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Text", got: output.variantName)
        }
        return text
    }

    func unload(model: String) async throws -> Bool {
        let output = try await client.execute(.generateUnload(model: model))
        guard case .bool(let b) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Bool", got: output.variantName)
        }
        return b
    }
}
