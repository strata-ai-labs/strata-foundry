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
            if isLoading {
                SkeletonLoadingView(rows: 4, columns: 3)
            } else if let error = errorMessage {
                VStack {
                    Spacer()
                    Text(error).foregroundStyle(.red)
                    Spacer()
                }
            } else if branches.isEmpty {
                EmptyStateView(
                    icon: "arrow.triangle.branch",
                    title: "No branches"
                )
            } else {
                List(branches) { branch in
                    HStack(spacing: StrataSpacing.sm) {
                        Image(systemName: branch.name == "default" ? "star.fill" : "arrow.triangle.branch")
                            .foregroundStyle(branch.name == "default" ? .yellow : .secondary)
                            .frame(width: 20)
                        Text(branch.name)
                            .strataKeyStyle()
                            .fontWeight(branch.name == "default" ? .semibold : .regular)
                        Spacer()
                        Text(branch.status)
                            .font(.caption)
                            .padding(.horizontal, StrataSpacing.xs)
                            .padding(.vertical, 2)
                            .background(.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(RoundedRectangle(cornerRadius: StrataRadius.sm))
                        if let parent = branch.parentId {
                            Text("from \(parent)")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Branches")
        .navigationSubtitle("\(branches.count) branches")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await loadBranches() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh")
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
