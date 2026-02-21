//
//  BranchesView.swift
//  StrataFoundry
//

import SwiftUI

struct BranchEntry: Identifiable {
    let id: String
    let name: String
    let status: String
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
            } else {
                Table(branches) {
                    TableColumn("Branch", value: \.name)
                        .width(min: 150, ideal: 250)
                    TableColumn("Status", value: \.status)
                        .width(min: 80, ideal: 120)
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
            let json = try await client.executeRaw(#"{"BranchList": null}"#)
            guard let data = json.data(using: .utf8),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let list = root["BranchInfoList"] as? [[String: Any]] else {
                branches = []
                return
            }

            branches = list.compactMap { item in
                guard let info = item["info"] as? [String: Any],
                      let name = info["name"] as? String else { return nil }
                let status = info["status"] as? String ?? "unknown"
                return BranchEntry(id: name, name: name, status: status)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
