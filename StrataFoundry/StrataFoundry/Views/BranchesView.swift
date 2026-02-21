//
//  BranchesView.swift
//  StrataFoundry
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
        guard let client = appState.client else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let json = try await client.executeRaw(#"{"BranchList": {}}"#)
            guard let data = json.data(using: .utf8),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let list = root["BranchInfoList"] as? [[String: Any]] else {
                branches = []
                return
            }

            branches = list.compactMap { item in
                guard let info = item["info"] as? [String: Any],
                      let branchId = info["id"] as? String else { return nil }
                let status = info["status"] as? String ?? "unknown"
                let parentId = info["parent_id"] as? String
                return BranchEntry(id: branchId, name: branchId, status: status, parentId: parentId)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
