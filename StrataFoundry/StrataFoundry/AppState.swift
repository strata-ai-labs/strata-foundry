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

    /// Whether a database is currently open.
    var isOpen: Bool { client?.isOpen ?? false }

    /// Display name for the open database.
    var databaseName: String {
        if let path = databasePath {
            return URL(fileURLWithPath: path).deletingLastPathComponent().lastPathComponent
        }
        return "In-Memory"
    }

    /// Open a database at a filesystem path.
    func openDatabase(at path: String) async {
        // Close existing if open
        closeDatabase()

        let newClient = StrataClient()
        do {
            try await newClient.open(path: path)
            client = newClient
            databasePath = path
            await refreshInfo()
            await loadBranches()
        } catch {
            errorMessage = "Failed to open database: \(error.localizedDescription)"
        }
    }

    /// Create a new database at a path.
    func createDatabase(at path: String) async {
        closeDatabase()

        let newClient = StrataClient()
        do {
            // strata_open creates the database if it doesn't exist
            try await newClient.open(path: path)
            client = newClient
            databasePath = path
            await refreshInfo()
            await loadBranches()
        } catch {
            errorMessage = "Failed to create database: \(error.localizedDescription)"
        }
    }

    /// Close the current database.
    func closeDatabase() {
        client?.close()
        client = nil
        databasePath = nil
        databaseInfo = nil
        selectedBranch = "default"
        branches = []
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
