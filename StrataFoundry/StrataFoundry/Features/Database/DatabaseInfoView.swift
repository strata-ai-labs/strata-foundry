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
        VStack(alignment: .leading, spacing: StrataSpacing.lg) {
            Text("Database Info")
                .font(.title2)
                .fontWeight(.semibold)

            if let info = appState.databaseInfo {
                Grid(alignment: .leading, horizontalSpacing: StrataSpacing.md, verticalSpacing: StrataSpacing.sm) {
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
                            .contentTransition(.numericText())
                    }
                    GridRow {
                        Text("Total Keys")
                            .foregroundStyle(.secondary)
                        Text("\(info.totalKeys)")
                            .contentTransition(.numericText())
                    }
                }
                .font(.body)
                .transition(.opacity)
            } else {
                SkeletonLoadingView(rows: 4, columns: 2)
                    .task {
                        await appState.refreshInfo()
                    }
            }

            Spacer()
        }
        .padding(StrataSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeInOut(duration: 0.25), value: appState.databaseInfo != nil)
    }
}
