//
//  WelcomeView.swift
//  StrataFoundry
//
//  Shown when no database is open.
//

import SwiftUI

struct WelcomeView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "cylinder.split.1x2")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Strata Foundry")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Open or create a StrataDB database to get started.")
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Button("Open Database...") {
                    appState.showOpenPanel = true
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("New Database...") {
                    appState.showCreatePanel = true
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding(40)
    }
}
