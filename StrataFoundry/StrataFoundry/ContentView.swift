//
//  ContentView.swift
//  StrataFoundry
//
//  Created by Aniruddha Joshi on 2/20/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.isOpen {
                DatabaseView()
            } else {
                WelcomeView()
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .onChange(of: appState.showOpenPanel) { _, show in
            if show {
                openDatabasePanel()
                appState.showOpenPanel = false
            }
        }
        .onChange(of: appState.showCreatePanel) { _, show in
            if show {
                createDatabasePanel()
                appState.showCreatePanel = false
            }
        }
        .alert("Error", isPresented: .init(
            get: { appState.errorMessage != nil },
            set: { if !$0 { appState.errorMessage = nil } }
        )) {
            Button("OK") { appState.errorMessage = nil }
        } message: {
            Text(appState.errorMessage ?? "")
        }
    }

    private func openDatabasePanel() {
        // Dispatch outside SwiftUI's layout transaction to avoid
        // "cannot run inside a transaction begin/commit pair" error.
        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.title = "Open Strata Database"
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.message = "Select the folder containing your .strata database"

            if panel.runModal() == .OK, let url = panel.url {
                // If the user selected a directory containing .strata, use that.
                // If the selected directory IS a .strata directory, use it directly.
                let strataURL = url.lastPathComponent == ".strata"
                    ? url
                    : url.appendingPathComponent(".strata")
                Task {
                    await appState.openDatabase(at: strataURL.path)
                }
            }
        }
    }

    private func createDatabasePanel() {
        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.title = "Create Strata Database"
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.canCreateDirectories = true
            panel.message = "Choose a directory for the new database"
            panel.prompt = "Create"

            if panel.runModal() == .OK, let url = panel.url {
                let dbPath = url.appendingPathComponent(".strata").path
                Task {
                    await appState.createDatabase(at: dbPath)
                }
            }
        }
    }
}
