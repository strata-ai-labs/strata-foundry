//
//  VersionHistoryView.swift
//  StrataFoundry
//
//  Reusable view that fetches and displays version history for a key.
//  Uses typed services — no raw JSON.
//

import SwiftUI

struct VersionedEntry: Identifiable {
    let id: Int
    let version: UInt64
    let timestamp: UInt64
    let displayValue: String
    let valueType: String
}

struct VersionHistoryView: View {
    @Environment(AppState.self) private var appState

    let primitive: String  // "Kv", "State", or "Json"
    let key: String

    @State private var versions: [VersionedEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var expandedVersion: Int?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.secondary)
                Text("Version History")
                    .strataSectionHeader()
                Text("\u{2014}")
                    .foregroundStyle(.tertiary)
                Text(key)
                    .strataKeyStyle()
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(versions.count) versions")
                    .strataCountStyle()
            }
            .padding(.horizontal, StrataSpacing.md)
            .padding(.vertical, StrataSpacing.sm)

            Divider()

            if isLoading {
                SkeletonLoadingView(rows: 5, columns: 2)
            } else if let error = errorMessage {
                VStack {
                    Spacer()
                    Text(error).foregroundStyle(.red).padding()
                    Spacer()
                }
            } else if versions.isEmpty {
                EmptyStateView(
                    icon: "clock",
                    title: "No version history available"
                )
            } else {
                List(versions) { entry in
                    VStack(alignment: .leading, spacing: StrataSpacing.xs) {
                        HStack {
                            Text("v\(entry.version)")
                                .strataKeyStyle()

                            if entry.id == 0 {
                                Text("latest")
                                    .font(.caption2)
                                    .padding(.horizontal, StrataSpacing.xs)
                                    .padding(.vertical, 2)
                                    .background(.blue.opacity(0.15))
                                    .foregroundStyle(.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: StrataRadius.sm))
                            }

                            Spacer()

                            Text(entry.valueType)
                                .strataBadgeStyle()

                            Text(formatTimestamp(entry.timestamp))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }

                        Text(entry.displayValue)
                            .strataCodeStyle()
                            .foregroundStyle(.secondary)
                            .lineLimit(expandedVersion == entry.id ? nil : 3)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.snappy) {
                            expandedVersion = expandedVersion == entry.id ? nil : entry.id
                        }
                    }
                }
            }
        }
        .task {
            await loadVersions()
        }
    }

    private func loadVersions() async {
        guard let services = appState.services else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let branch = appState.selectedBranch
        let space: String? = appState.selectedSpace == "default" ? nil : appState.selectedSpace

        do {
            let history: [VersionedValue]?
            switch primitive {
            case "Kv":
                history = try await services.kvService.getVersionHistory(key: key, branch: branch, space: space)
            case "State":
                history = try await services.stateService.getVersionHistory(cell: key, branch: branch, space: space)
            case "Json":
                history = try await services.jsonService.getVersionHistory(key: key, branch: branch, space: space)
            default:
                errorMessage = "Unknown primitive: \(primitive)"
                return
            }

            guard let history else {
                versions = []
                return
            }

            versions = history.reversed().enumerated().map { index, item in
                VersionedEntry(
                    id: index,
                    version: item.version,
                    timestamp: item.timestamp,
                    displayValue: item.value.prettyJSON,
                    valueType: item.value.typeTag
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func formatTimestamp(_ micros: UInt64) -> String {
        guard micros > 0 else { return "" }
        let date = Date(timeIntervalSince1970: Double(micros) / 1_000_000.0)
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .medium
        return fmt.string(from: date)
    }
}
