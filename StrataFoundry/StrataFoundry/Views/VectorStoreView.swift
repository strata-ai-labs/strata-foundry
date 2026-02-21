//
//  VectorStoreView.swift
//  StrataFoundry
//

import SwiftUI

struct CollectionEntry: Identifiable {
    let id: String
    let name: String
    let dimension: Int
    let count: Int
    let metric: String
}

struct VectorStoreView: View {
    @Environment(AppState.self) private var appState
    @State private var collections: [CollectionEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Vector Store")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    Task { await loadCollections() }
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
                ProgressView("Loading collections...")
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                Text(error).foregroundStyle(.red)
                Spacer()
            } else if collections.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "arrow.trianglehead.branch")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No vector collections")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                Table(collections) {
                    TableColumn("Collection", value: \.name)
                        .width(min: 150, ideal: 250)
                    TableColumn("Dimension") { c in Text("\(c.dimension)") }
                        .width(min: 80, ideal: 100)
                    TableColumn("Vectors") { c in Text("\(c.count)") }
                        .width(min: 80, ideal: 100)
                    TableColumn("Metric", value: \.metric)
                        .width(min: 80, ideal: 100)
                }
            }
        }
        .task {
            await loadCollections()
        }
    }

    private func loadCollections() async {
        guard let client = appState.client else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let json = try await client.executeRaw(#"{"VectorListCollections": {}}"#)
            guard let data = json.data(using: .utf8),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let list = root["VectorCollectionList"] as? [[String: Any]] else {
                collections = []
                return
            }

            collections = list.compactMap { item in
                guard let name = item["name"] as? String else { return nil }
                return CollectionEntry(
                    id: name,
                    name: name,
                    dimension: item["dimension"] as? Int ?? 0,
                    count: item["count"] as? Int ?? 0,
                    metric: item["metric"] as? String ?? "unknown"
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
