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
                GroupBox {
                    HStack(spacing: StrataSpacing.xs) {
                        Image(systemName: "externaldrive.fill")
                            .foregroundStyle(.secondary)
                        Text(appState.databasePath ?? "In-Memory")
                            .font(.system(.callout, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: StrataSpacing.sm) {
                    DashboardCard(
                        title: "Version",
                        value: info.version,
                        icon: "tag.fill",
                        iconColor: .gray
                    )
                    DashboardCard(
                        title: "Uptime",
                        value: formatUptime(info.uptimeSecs),
                        icon: "clock.fill",
                        iconColor: .green
                    )
                    DashboardCard(
                        title: "Branches",
                        value: "\(info.branchCount)",
                        icon: "arrow.triangle.branch",
                        iconColor: .orange
                    )
                    DashboardCard(
                        title: "Total Keys",
                        value: "\(info.totalKeys)",
                        icon: "key.fill",
                        iconColor: .purple
                    )
                }
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
