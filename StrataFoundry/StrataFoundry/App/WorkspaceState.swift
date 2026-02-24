//
//  WorkspaceState.swift
//  StrataFoundry
//
//  Manages multiple open database sessions (tabs).
//

import SwiftUI

@Observable
final class DatabaseSession: Identifiable {
    let id = UUID()
    let appState = AppState()

    /// Display name for the tab.
    var name: String {
        appState.databaseName
    }

    /// Whether this session has an open database.
    var isOpen: Bool { appState.isOpen }
}

@Observable
final class WorkspaceState {
    /// All open database sessions.
    var sessions: [DatabaseSession] = []

    /// The ID of the currently active session.
    var activeSessionId: UUID?

    /// The currently active session.
    var activeSession: DatabaseSession? {
        sessions.first { $0.id == activeSessionId }
    }

    /// The AppState of the currently active session.
    var activeAppState: AppState? {
        activeSession?.appState
    }

    /// Trigger the Open Database panel (direct open, no config sheet).
    var showOpenPanel = false

    /// Trigger the Open Database panel with advanced options (config sheet).
    var showAdvancedOpenPanel = false

    /// Trigger the Create Database panel.
    var showCreatePanel = false

    /// Error to display.
    var errorMessage: String?

    init() {
        // Start with one empty session
        let initial = DatabaseSession()
        sessions = [initial]
        activeSessionId = initial.id
    }

    /// Add a new empty tab and make it active.
    @discardableResult
    func addTab() -> DatabaseSession {
        let session = DatabaseSession()
        sessions.append(session)
        activeSessionId = session.id
        return session
    }

    /// Close a tab. If it's the last tab, add a new empty one.
    func closeTab(_ id: UUID) {
        // Close the database if open
        if let session = sessions.first(where: { $0.id == id }) {
            session.appState.closeDatabase()
        }

        sessions.removeAll { $0.id == id }

        // If we closed the active tab, switch to another
        if activeSessionId == id {
            activeSessionId = sessions.last?.id
        }

        // Always keep at least one tab
        if sessions.isEmpty {
            let newSession = DatabaseSession()
            sessions.append(newSession)
            activeSessionId = newSession.id
        }
    }

    /// Open a database in the active session (or a new tab if active is already open).
    func openDatabase(at path: String, options: OpenOptions? = nil) async {
        let session: DatabaseSession
        if let active = activeSession, !active.isOpen {
            session = active
        } else {
            session = addTab()
        }
        await session.appState.openDatabase(at: path, options: options)
    }

    /// Create a new database in the active session (or a new tab if active is already open).
    func createDatabase(at path: String, options: OpenOptions? = nil) async {
        let session: DatabaseSession
        if let active = activeSession, !active.isOpen {
            session = active
        } else {
            session = addTab()
        }
        await session.appState.createDatabase(at: path, options: options)
    }
}
