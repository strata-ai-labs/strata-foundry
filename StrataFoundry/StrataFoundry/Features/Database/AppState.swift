//
//  AppState.swift
//  StrataFoundry
//
//  Global app state shared across views.
//  All database operations use typed services — no raw JSON.
//

import SwiftUI

@Observable
final class AppState {
    /// The active FFI transport, or nil if no database is open.
    var client: StrataTransport?

    /// Typed service container — created alongside client when a database is opened.
    var services: ServiceContainer?

    /// Path of the open database (nil for in-memory).
    var databasePath: String?

    /// OpenOptions used when opening the current database.
    var openOptions: OpenOptions?

    /// Info about the open database.
    var databaseInfo: StrataDatabaseInfo?

    /// Trigger the Open Database panel (direct open, no config sheet).
    var showOpenPanel = false

    /// Trigger the Open Database panel with advanced options (config sheet).
    var showAdvancedOpenPanel = false

    /// Trigger the Create Database panel.
    var showCreatePanel = false

    /// Error to display.
    var errorMessage: String?

    /// Currently selected branch.
    var selectedBranch: String = "default"

    /// List of branch names in the open database.
    var branches: [String] = []

    // MARK: - Spaces

    /// Currently selected space within the branch.
    var selectedSpace: String = "default"

    /// List of space names in the current branch.
    var spaces: [String] = []

    // MARK: - Time Travel

    /// Date for time-travel queries. nil means "live" (current data).
    var timeTravelDate: Date? = nil

    /// Oldest timestamp available on the current branch.
    var timeRangeOldest: Date? = nil

    /// Latest timestamp available on the current branch.
    var timeRangeLatest: Date? = nil

    /// Combined token that changes when branch or time-travel date changes,
    /// so `.task(id:)` modifiers reload on either change.
    var reloadToken: String {
        let branchPart = selectedBranch
        let spacePart = selectedSpace
        let timePart = timeTravelDate.map { String(Int64($0.timeIntervalSince1970 * 1_000_000)) } ?? "live"
        return "\(branchPart)|\(spacePart)|\(timePart)"
    }

    /// Whether a database is currently open.
    var isOpen: Bool { client?.isOpen ?? false }

    /// Display name for the open database.
    var databaseName: String {
        if let path = databasePath {
            return URL(fileURLWithPath: path).deletingLastPathComponent().lastPathComponent
        }
        return "In-Memory"
    }

    /// Open a database at a filesystem path with optional configuration.
    func openDatabase(at path: String, options: OpenOptions? = nil) async {
        // Close existing if open
        closeDatabase()

        let newClient = StrataTransport()
        do {
            try await newClient.open(path: path, options: options)
            client = newClient
            services = ServiceContainer(transport: newClient)
            databasePath = path
            openOptions = options
            await refreshInfo()
            await loadBranches()
            await loadSpaces()
            await loadTimeRange()
        } catch {
            errorMessage = "Failed to open database: \(error.localizedDescription)"
        }
    }

    /// Create a new database at a path with optional configuration.
    func createDatabase(at path: String, options: OpenOptions? = nil) async {
        closeDatabase()

        let newClient = StrataTransport()
        do {
            // strata_open creates the database if it doesn't exist
            try await newClient.open(path: path, options: options)
            client = newClient
            services = ServiceContainer(transport: newClient)
            databasePath = path
            openOptions = options
            await refreshInfo()
            await loadBranches()
            await loadSpaces()
            await loadTimeRange()
        } catch {
            errorMessage = "Failed to create database: \(error.localizedDescription)"
        }
    }

    /// Close the current database.
    func closeDatabase() {
        client?.close()
        client = nil
        services = nil
        databasePath = nil
        openOptions = nil
        databaseInfo = nil
        selectedBranch = "default"
        branches = []
        selectedSpace = "default"
        spaces = []
        timeTravelDate = nil
        timeRangeOldest = nil
        timeRangeLatest = nil
    }

    /// Load the oldest/latest timestamps for the current branch via TimeRange.
    func loadTimeRange() async {
        guard let services else { return }
        do {
            let range = try await services.adminService.timeRange(branch: selectedBranch)
            if let oldest = range.oldestTs, oldest > 0 {
                timeRangeOldest = Date(timeIntervalSince1970: Double(oldest) / 1_000_000.0)
            } else {
                timeRangeOldest = nil
            }
            if let latest = range.latestTs, latest > 0 {
                timeRangeLatest = Date(timeIntervalSince1970: Double(latest) / 1_000_000.0)
            } else {
                timeRangeLatest = nil
            }
        } catch {
            // TimeRange may not be supported — silently ignore
            timeRangeOldest = nil
            timeRangeLatest = nil
        }
    }

    /// Load the list of branch names from the database.
    func loadBranches() async {
        guard let services else { return }
        do {
            let list = try await services.branchService.list()
            branches = list.map { $0.info.id.value }
        } catch {
            errorMessage = "Failed to load branches: \(error.localizedDescription)"
        }
    }

    /// Load the list of spaces for the current branch.
    func loadSpaces() async {
        guard let services else { return }
        do {
            let list = try await services.spaceService.list(branch: selectedBranch)
            spaces = list.isEmpty ? ["default"] : list
            if !spaces.contains(selectedSpace) {
                selectedSpace = "default"
            }
        } catch {
            // SpaceList may not be supported — default to single space
            spaces = ["default"]
        }
    }

    /// Create a new space on the current branch.
    func createSpace(_ name: String) async throws {
        guard let services else { return }
        try await services.spaceService.create(space: name, branch: selectedBranch)
        await loadSpaces()
    }

    /// Delete a space on the current branch.
    func deleteSpace(_ name: String, force: Bool) async throws {
        guard let services else { return }
        try await services.spaceService.delete(space: name, force: force, branch: selectedBranch)
        if selectedSpace == name { selectedSpace = "default" }
        await loadSpaces()
    }

    // MARK: - Branch Management

    /// Create a new branch.
    func createBranch(_ name: String) async throws {
        guard let services else { return }
        _ = try await services.branchService.create(branchId: name)
        await loadBranches()
    }

    /// Delete a branch.
    func deleteBranch(_ name: String) async throws {
        guard let services else { return }
        try await services.branchService.delete(branch: name)
        if selectedBranch == name { selectedBranch = "default" }
        await loadBranches()
        await loadSpaces()
    }

    /// Export a branch to a bundle file.
    func exportBranch(_ name: String, to path: String) async throws -> StrataBranchExportResult {
        guard let services else {
            throw NSError(domain: "AppState", code: 1, userInfo: [NSLocalizedDescriptionKey: "No database open"])
        }
        return try await services.branchService.export(branchId: name, path: path)
    }

    /// Import a branch from a bundle file.
    func importBranch(from path: String) async throws -> StrataBranchImportResult {
        guard let services else {
            throw NSError(domain: "AppState", code: 1, userInfo: [NSLocalizedDescriptionKey: "No database open"])
        }
        let result = try await services.branchService.importBundle(path: path)
        await loadBranches()
        return result
    }

    /// Validate a branch bundle file.
    func validateBundle(at path: String) async throws -> StrataBundleValidateResult {
        guard let services else {
            throw NSError(domain: "AppState", code: 1, userInfo: [NSLocalizedDescriptionKey: "No database open"])
        }
        return try await services.branchService.validateBundle(path: path)
    }

    // MARK: - Branch Advanced Operations

    /// Fork a branch to a new destination.
    func forkBranch(source: String, destination: String) async throws {
        guard let services else {
            throw NSError(domain: "AppState", code: 1, userInfo: [NSLocalizedDescriptionKey: "No database open"])
        }
        _ = try await services.branchService.fork(source: source, destination: destination)
        await loadBranches()
    }

    /// Diff two branches — returns formatted diff string.
    func diffBranches(branchA: String, branchB: String) async throws -> String {
        guard let services else {
            throw NSError(domain: "AppState", code: 1, userInfo: [NSLocalizedDescriptionKey: "No database open"])
        }
        let diff = try await services.branchService.diff(branchA: branchA, branchB: branchB)
        let data = try JSONEncoder.strataEncoder.encode(diff)
        if let obj = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
           let str = String(data: pretty, encoding: .utf8) {
            return str
        }
        return String(data: data, encoding: .utf8) ?? "Diff completed"
    }

    /// Merge source branch into target with given strategy.
    func mergeBranches(source: String, target: String, strategy: String) async throws -> String {
        guard let services else {
            throw NSError(domain: "AppState", code: 1, userInfo: [NSLocalizedDescriptionKey: "No database open"])
        }
        let mergeStrategy: MergeStrategy = strategy.lowercased().contains("strict") ? .strict : .lastWriterWins
        _ = try await services.branchService.merge(source: source, target: target, strategy: mergeStrategy)
        return "Merged \(source) into \(target) (\(strategy))."
    }

    /// Refresh database info.
    func refreshInfo() async {
        guard let services else { return }
        do {
            databaseInfo = try await services.adminService.info()
        } catch {
            errorMessage = "Failed to get database info: \(error.localizedDescription)"
        }
    }
}
