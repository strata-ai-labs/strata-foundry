//
//  DatabaseInfoView.swift
//  StrataFoundry
//
//  Shows basic database information.
//

import SwiftUI

struct DatabaseInfoView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Database Info")
                .font(.title2)
                .fontWeight(.semibold)

            if let info = appState.databaseInfo {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                    GridRow {
                        Text("Path")
                            .foregroundStyle(.secondary)
                        Text(appState.databasePath ?? "In-Memory")
                            .textSelection(.enabled)
                    }
                    GridRow {
                        Text("Version")
                            .foregroundStyle(.secondary)
                        Text(info.version)
                    }
                    GridRow {
                        Text("Branches")
                            .foregroundStyle(.secondary)
                        Text("\(info.branchCount)")
                    }
                    GridRow {
                        Text("Total Keys")
                            .foregroundStyle(.secondary)
                        Text("\(info.totalKeys)")
                    }
                }
                .font(.body)
            } else {
                ProgressView("Loading...")
                    .task {
                        await appState.refreshInfo()
                    }
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
