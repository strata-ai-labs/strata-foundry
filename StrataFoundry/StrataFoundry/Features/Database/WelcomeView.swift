//
//  WelcomeView.swift
//  StrataFoundry
//
//  Shown when no database is open.
//

import SwiftUI

struct WelcomeView: View {
    @Environment(AppState.self) private var appState
    @State private var appeared = false

    var body: some View {
        VStack(spacing: StrataSpacing.lg) {
            Spacer()

            Image(systemName: "cylinder.split.1x2")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
                .scaleEffect(appeared ? 1.0 : 0.8)
                .opacity(appeared ? 1.0 : 0.0)

            Text("Strata Foundry")
                .font(.largeTitle)
                .fontWeight(.bold)
                .opacity(appeared ? 1.0 : 0.0)

            Text("Open or create a StrataDB database to get started.")
                .foregroundStyle(.secondary)
                .opacity(appeared ? 1.0 : 0.0)

            HStack(spacing: StrataSpacing.md) {
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
            .opacity(appeared ? 1.0 : 0.0)

            Spacer()
        }
        .padding(StrataSpacing.xxl)
        .animation(.easeOut(duration: 0.4), value: appeared)
        .onAppear { appeared = true }
    }
}
