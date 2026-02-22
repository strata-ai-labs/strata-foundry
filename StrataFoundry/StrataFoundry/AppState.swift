//
//  AppState.swift
//  StrataFoundry
//
//  Global app state shared across views.
//

import SwiftUI

@Observable
final class AppState {
    /// The active database client, or nil if no database is open.
    var client: StrataClient?

    /// Path of the open database (nil for in-memory).
    var databasePath: String?

    /// OpenOptions used when opening the current database.
    var openOptions: OpenOptions?

    /// Info about the open database.
    var databaseInfo: DatabaseInfo?

    /// Trigger the Open Database panel.
    var showOpenPanel = false

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

    /// Returns a JSON fragment like `, "space": "myspace"` or empty string for "default".
    func spaceFragment() -> String {
        guard selectedSpace != "default" else { return "" }
        return ", \"space\": \"\(selectedSpace)\""
    }

    /// Returns a JSON fragment like `, "as_of": 1234567890` or empty string.
    func asOfFragment() -> String {
        guard let date = timeTravelDate else { return "" }
        let micros = Int64(date.timeIntervalSince1970 * 1_000_000)
        return ", \"as_of\": \(micros)"
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

        let newClient = StrataClient()
        do {
            try await newClient.open(path: path, options: options)
            client = newClient
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

        let newClient = StrataClient()
        do {
            // strata_open creates the database if it doesn't exist
            try await newClient.open(path: path, options: options)
            client = newClient
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
        guard let client else { return }
        do {
            let json = try await client.executeRaw("{\"TimeRange\": {\"branch\": \"\(selectedBranch)\"}}")
            guard let data = json.data(using: .utf8),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let range = root["TimeRange"] as? [String: Any] else {
                timeRangeOldest = nil
                timeRangeLatest = nil
                return
            }
            if let oldest = range["oldest_ts"] as? Int64, oldest > 0 {
                timeRangeOldest = Date(timeIntervalSince1970: Double(oldest) / 1_000_000.0)
            } else if let oldest = range["oldest_ts"] as? Double, oldest > 0 {
                timeRangeOldest = Date(timeIntervalSince1970: oldest / 1_000_000.0)
            } else {
                timeRangeOldest = nil
            }
            if let latest = range["latest_ts"] as? Int64, latest > 0 {
                timeRangeLatest = Date(timeIntervalSince1970: Double(latest) / 1_000_000.0)
            } else if let latest = range["latest_ts"] as? Double, latest > 0 {
                timeRangeLatest = Date(timeIntervalSince1970: latest / 1_000_000.0)
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
        guard let client else { return }
        do {
            let json = try await client.executeRaw(#"{"BranchList": {}}"#)
            guard let data = json.data(using: .utf8),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let list = root["BranchInfoList"] as? [[String: Any]] else {
                branches = []
                return
            }
            branches = list.compactMap { item in
                (item["info"] as? [String: Any])?["id"] as? String
            }
        } catch {
            errorMessage = "Failed to load branches: \(error.localizedDescription)"
        }
    }

    /// Load the list of spaces for the current branch.
    func loadSpaces() async {
        guard let client else { return }
        do {
            let json = try await client.executeRaw("{\"SpaceList\": {\"branch\": \"\(selectedBranch)\"}}")
            guard let data = json.data(using: .utf8),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let list = root["SpaceList"] as? [String] else {
                spaces = ["default"]
                return
            }
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
        guard let client else { return }
        _ = try await client.executeRaw(
            "{\"SpaceCreate\": {\"branch\": \"\(selectedBranch)\", \"space\": \"\(name)\"}}")
        await loadSpaces()
    }

    /// Delete a space on the current branch.
    func deleteSpace(_ name: String, force: Bool) async throws {
        guard let client else { return }
        _ = try await client.executeRaw(
            "{\"SpaceDelete\": {\"branch\": \"\(selectedBranch)\", \"space\": \"\(name)\", \"force\": \(force)}}")
        if selectedSpace == name { selectedSpace = "default" }
        await loadSpaces()
    }

    // MARK: - Branch Management

    /// Create a new branch.
    func createBranch(_ name: String) async throws {
        guard let client else { return }
        _ = try await client.executeRaw(
            "{\"BranchCreate\": {\"branch_id\": \"\(name)\"}}")
        await loadBranches()
    }

    /// Delete a branch.
    func deleteBranch(_ name: String) async throws {
        guard let client else { return }
        _ = try await client.executeRaw(
            "{\"BranchDelete\": {\"branch\": \"\(name)\"}}")
        if selectedBranch == name { selectedBranch = "default" }
        await loadBranches()
        await loadSpaces()
    }

    /// Export a branch to a bundle file.
    func exportBranch(_ name: String, to path: String) async throws -> BranchExportResult {
        guard let client else {
            throw NSError(domain: "AppState", code: 1, userInfo: [NSLocalizedDescriptionKey: "No database open"])
        }
        let json = try await client.executeRaw(
            "{\"BranchExport\": {\"branch_id\": \"\(name)\", \"path\": \"\(path)\"}}")
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exported = root["BranchExported"] as? [String: Any] else {
            throw NSError(domain: "AppState", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unexpected response: \(json)"])
        }
        return BranchExportResult(
            branchId: exported["branch_id"] as? String ?? name,
            path: exported["path"] as? String ?? path,
            entryCount: exported["entry_count"] as? Int ?? 0,
            bundleSize: exported["bundle_size"] as? Int ?? 0
        )
    }

    /// Import a branch from a bundle file.
    func importBranch(from path: String) async throws -> BranchImportResult {
        guard let client else {
            throw NSError(domain: "AppState", code: 1, userInfo: [NSLocalizedDescriptionKey: "No database open"])
        }
        let json = try await client.executeRaw(
            "{\"BranchImport\": {\"path\": \"\(path)\"}}")
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let imported = root["BranchImported"] as? [String: Any] else {
            throw NSError(domain: "AppState", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unexpected response: \(json)"])
        }
        await loadBranches()
        return BranchImportResult(
            branchId: imported["branch_id"] as? String ?? "",
            transactionsApplied: imported["transactions_applied"] as? Int ?? 0,
            keysWritten: imported["keys_written"] as? Int ?? 0
        )
    }

    /// Validate a branch bundle file.
    func validateBundle(at path: String) async throws -> BundleValidateResult {
        guard let client else {
            throw NSError(domain: "AppState", code: 1, userInfo: [NSLocalizedDescriptionKey: "No database open"])
        }
        let json = try await client.executeRaw(
            "{\"BranchBundleValidate\": {\"path\": \"\(path)\"}}")
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let validated = root["BundleValidated"] as? [String: Any] else {
            throw NSError(domain: "AppState", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unexpected response: \(json)"])
        }
        return BundleValidateResult(
            branchId: validated["branch_id"] as? String ?? "",
            formatVersion: validated["format_version"] as? Int ?? 0,
            entryCount: validated["entry_count"] as? Int ?? 0,
            checksumsValid: validated["checksums_valid"] as? Bool ?? false
        )
    }

    // MARK: - Branch Advanced Operations

    /// Fork a branch to a new destination.
    func forkBranch(source: String, destination: String) async throws {
        guard let client else {
            throw NSError(domain: "AppState", code: 1, userInfo: [NSLocalizedDescriptionKey: "No database open"])
        }
        let wrapper: [String: Any] = ["BranchFork": ["source": source, "destination": destination]]
        let data = try JSONSerialization.data(withJSONObject: wrapper)
        let jsonStr = String(data: data, encoding: .utf8)!
        _ = try await client.executeRaw(jsonStr)
        await loadBranches()
    }

    /// Diff two branches — returns formatted diff string.
    func diffBranches(branchA: String, branchB: String) async throws -> String {
        guard let client else {
            throw NSError(domain: "AppState", code: 1, userInfo: [NSLocalizedDescriptionKey: "No database open"])
        }
        let wrapper: [String: Any] = ["BranchDiff": ["branch_a": branchA, "branch_b": branchB]]
        let data = try JSONSerialization.data(withJSONObject: wrapper)
        let jsonStr = String(data: data, encoding: .utf8)!
        let json = try await client.executeRaw(jsonStr)

        if let respData = json.data(using: .utf8),
           let root = try? JSONSerialization.jsonObject(with: respData) as? [String: Any],
           let diff = root["BranchDiff"] {
            if let prettyData = try? JSONSerialization.data(withJSONObject: diff, options: [.prettyPrinted, .sortedKeys]),
               let str = String(data: prettyData, encoding: .utf8) {
                return str
            }
            return "\(diff)"
        }
        return json
    }

    /// Merge source branch into target with given strategy.
    func mergeBranches(source: String, target: String, strategy: String) async throws -> String {
        guard let client else {
            throw NSError(domain: "AppState", code: 1, userInfo: [NSLocalizedDescriptionKey: "No database open"])
        }
        let wrapper: [String: Any] = ["BranchMerge": [
            "source": source,
            "target": target,
            "strategy": strategy
        ]]
        let data = try JSONSerialization.data(withJSONObject: wrapper)
        let jsonStr = String(data: data, encoding: .utf8)!
        let json = try await client.executeRaw(jsonStr)

        if let respData = json.data(using: .utf8),
           let root = try? JSONSerialization.jsonObject(with: respData) as? [String: Any],
           root["BranchMerged"] != nil {
            return "Merged \(source) into \(target) (\(strategy))."
        }
        return "Merge completed."
    }

    /// Refresh database info.
    func refreshInfo() async {
        guard let client else { return }
        do {
            let json = try await client.executeRaw(#"{"Info": null}"#)
            databaseInfo = DatabaseInfo.parse(from: json)
        } catch {
            errorMessage = "Failed to get database info: \(error.localizedDescription)"
        }
    }
}

struct BranchExportResult {
    let branchId: String
    let path: String
    let entryCount: Int
    let bundleSize: Int
}

struct BranchImportResult {
    let branchId: String
    let transactionsApplied: Int
    let keysWritten: Int
}

struct BundleValidateResult {
    let branchId: String
    let formatVersion: Int
    let entryCount: Int
    let checksumsValid: Bool
}

/// Parsed database info from the Info command.
struct DatabaseInfo {
    let version: String
    let uptimeSecs: Int
    let branchCount: Int
    let totalKeys: Int

    static func parse(from json: String) -> DatabaseInfo? {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let info = root["DatabaseInfo"] as? [String: Any] else {
            return nil
        }
        return DatabaseInfo(
            version: info["version"] as? String ?? "unknown",
            uptimeSecs: info["uptime_secs"] as? Int ?? 0,
            branchCount: info["branch_count"] as? Int ?? 0,
            totalKeys: info["total_keys"] as? Int ?? 0
        )
    }
}
