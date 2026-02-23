//
//  BranchService.swift
//  StrataFoundry
//
//  Branch lifecycle operations.
//

import Foundation

final class BranchService: Sendable {
    private let client: StrataTypedClient
    init(client: StrataTypedClient) { self.client = client }

    func create(branchId: String? = nil, metadata: StrataValue? = nil) async throws -> (info: BranchInfo, version: UInt64) {
        let output = try await client.execute(.branchCreate(branchId: branchId, metadata: metadata))
        guard case .branchWithVersion(let info, let version) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "BranchWithVersion", got: output.variantName)
        }
        return (info: info, version: version)
    }

    func get(branch: String) async throws -> VersionedBranchInfo? {
        let output = try await client.execute(.branchGet(branch: branch))
        guard case .maybeBranchInfo(let info) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "MaybeBranchInfo", got: output.variantName)
        }
        return info
    }

    func list(state: BranchStatus? = nil, limit: UInt64? = nil, offset: UInt64? = nil) async throws -> [VersionedBranchInfo] {
        let output = try await client.execute(.branchList(state: state, limit: limit, offset: offset))
        guard case .branchInfoList(let list) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "BranchInfoList", got: output.variantName)
        }
        return list
    }

    func exists(branch: String) async throws -> Bool {
        let output = try await client.execute(.branchExists(branch: branch))
        guard case .bool(let b) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Bool", got: output.variantName)
        }
        return b
    }

    func delete(branch: String) async throws {
        let output = try await client.execute(.branchDelete(branch: branch))
        guard case .unit = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Unit", got: output.variantName)
        }
    }

    func fork(source: String, destination: String) async throws -> ForkInfo {
        let output = try await client.execute(.branchFork(source: source, destination: destination))
        guard case .branchForked(let info) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "BranchForked", got: output.variantName)
        }
        return info
    }

    func diff(branchA: String, branchB: String) async throws -> BranchDiffResult {
        let output = try await client.execute(.branchDiff(branchA: branchA, branchB: branchB))
        guard case .branchDiff(let result) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "BranchDiff", got: output.variantName)
        }
        return result
    }

    func merge(source: String, target: String, strategy: MergeStrategy) async throws -> MergeInfo {
        let output = try await client.execute(.branchMerge(source: source, target: target, strategy: strategy))
        guard case .branchMerged(let info) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "BranchMerged", got: output.variantName)
        }
        return info
    }

    func export(branchId: String, path: String) async throws -> StrataBranchExportResult {
        let output = try await client.execute(.branchExport(branchId: branchId, path: path))
        guard case .branchExported(let result) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "BranchExported", got: output.variantName)
        }
        return result
    }

    func importBundle(path: String) async throws -> StrataBranchImportResult {
        let output = try await client.execute(.branchImport(path: path))
        guard case .branchImported(let result) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "BranchImported", got: output.variantName)
        }
        return result
    }

    func validateBundle(path: String) async throws -> StrataBundleValidateResult {
        let output = try await client.execute(.branchBundleValidate(path: path))
        guard case .bundleValidated(let result) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "BundleValidated", got: output.variantName)
        }
        return result
    }
}
