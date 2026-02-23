//
//  SpaceService.swift
//  StrataFoundry
//
//  Space management operations.
//

import Foundation

final class SpaceService: Sendable {
    private let client: StrataTypedClient
    init(client: StrataTypedClient) { self.client = client }

    func list(branch: String? = nil) async throws -> [String] {
        let output = try await client.execute(.spaceList(branch: branch))
        guard case .spaceList(let spaces) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "SpaceList", got: output.variantName)
        }
        return spaces
    }

    func create(space: String, branch: String? = nil) async throws {
        let output = try await client.execute(.spaceCreate(branch: branch, space: space))
        guard case .unit = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Unit", got: output.variantName)
        }
    }

    func delete(space: String, force: Bool = false, branch: String? = nil) async throws {
        let output = try await client.execute(.spaceDelete(branch: branch, space: space, force: force))
        guard case .unit = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Unit", got: output.variantName)
        }
    }

    func exists(space: String, branch: String? = nil) async throws -> Bool {
        let output = try await client.execute(.spaceExists(branch: branch, space: space))
        guard case .bool(let b) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Bool", got: output.variantName)
        }
        return b
    }
}
