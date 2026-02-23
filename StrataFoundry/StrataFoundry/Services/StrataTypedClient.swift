//
//  StrataTypedClient.swift
//  StrataFoundry
//
//  Typed client wrapping StrataTransport. Encodes StrataCommand to JSON,
//  sends via FFI, and decodes StrataOutput from the response.
//

import Foundation

/// Typed Strata client that converts between `StrataCommand` and `StrataOutput`.
///
/// Usage:
/// ```swift
/// let output = try await client.execute(.kvGet(branch: "default", key: "mykey"))
/// if case .maybeVersioned(let vv) = output { ... }
/// ```
final class StrataTypedClient: @unchecked Sendable {
    private let transport: StrataTransport

    init(transport: StrataTransport) {
        self.transport = transport
    }

    /// Execute a typed command and return the typed output.
    func execute(_ command: StrataCommand) async throws -> StrataOutput {
        let jsonData = try JSONEncoder.strataEncoder.encode(command)
        let jsonString = String(data: jsonData, encoding: .utf8)!

        let responseJSON = try await transport.executeRaw(jsonString)

        guard let responseData = responseJSON.data(using: .utf8) else {
            throw StrataError.invalidResponse(responseJSON)
        }

        do {
            return try JSONDecoder.strataDecoder.decode(StrataOutput.self, from: responseData)
        } catch {
            throw StrataError.invalidResponse("Failed to decode output: \(error.localizedDescription). Raw: \(responseJSON.prefix(500))")
        }
    }

    /// Whether the underlying transport has an open database.
    var isOpen: Bool { transport.isOpen }
}
