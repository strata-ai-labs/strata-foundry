//
//  StrataFoundryApp.swift
//  StrataFoundry
//
//  Created by Aniruddha Joshi on 2/20/26.
//

import SwiftUI

@main
struct StrataFoundryApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open Database...") {
                    appState.showOpenPanel = true
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("New Database...") {
                    appState.showCreatePanel = true
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
        }
    }
}
