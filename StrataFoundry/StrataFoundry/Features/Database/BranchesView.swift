//
//  BranchesView.swift
//  StrataFoundry
//
//  Thin view using BranchService — no raw JSON.
//

import SwiftUI

struct BranchEntry: Identifiable {
    let id: String
    let name: String
    let status: String
    let parentId: String?
}

struct BranchesView: View {
    @Environment(AppState.self) private var appState
    @State private var branches: [BranchEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Branches")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(branches.count) branches")
                    .foregroundStyle(.secondary)
                Button {
                    Task { await loadBranches() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)

            Divider()

            if isLoading {
                Spacer()
                ProgressView("Loading branches...")
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                Text(error).foregroundStyle(.red)
                Spacer()
            } else if branches.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No branches")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                List(branches) { branch in
                    HStack(spacing: 12) {
                        Image(systemName: branch.name == "default" ? "star.fill" : "arrow.triangle.branch")
                            .foregroundStyle(branch.name == "default" ? .yellow : .secondary)
                            .frame(width: 20)
                        Text(branch.name)
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(branch.name == "default" ? .semibold : .regular)
                        Spacer()
                        Text(branch.status)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        if let parent = branch.parentId {
                            Text("from \(parent)")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .task {
            await loadBranches()
        }
    }

    private func loadBranches() async {
        guard let services = appState.services else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let list = try await services.branchService.list()
            branches = list.map { item in
                BranchEntry(
                    id: item.info.id.value,
                    name: item.info.id.value,
                    status: item.info.status.rawValue,
                    parentId: item.info.parentId?.value
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
