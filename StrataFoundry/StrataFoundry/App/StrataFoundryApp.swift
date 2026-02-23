//
//  StrataFoundryApp.swift
//  StrataFoundry
//
//  Created by Aniruddha Joshi on 2/20/26.
//

import SwiftUI

@main
struct StrataFoundryApp: App {
    @State private var workspace = WorkspaceState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(workspace)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open Database...") {
                    workspace.showOpenPanel = true
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("New Database...") {
                    workspace.showCreatePanel = true
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Divider()

                Button("New Tab") {
                    workspace.addTab()
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("Close Tab") {
                    if let id = workspace.activeSessionId {
                        workspace.closeTab(id)
                    }
                }
                .disabled(workspace.sessions.count <= 1 && !(workspace.activeSession?.isOpen ?? false))
            }
        }
    }
}
