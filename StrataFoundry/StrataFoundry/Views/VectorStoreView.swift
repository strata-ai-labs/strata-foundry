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
    @State private var selectedCollection: String?

    // Write-related state
    @State private var showCreateSheet = false
    @State private var showDeleteConfirm = false
    @State private var formName = ""
    @State private var formDimension = "384"
    @State private var formMetric = "Cosine"

    private var isTimeTraveling: Bool { appState.timeTravelDate != nil }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Vector Store")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(collections.count) collections")
                    .foregroundStyle(.secondary)
                Button {
                    formName = ""
                    formDimension = "384"
                    formMetric = "Cosine"
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Create Collection")
                .disabled(isTimeTraveling)
                Button {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                }
                .help("Drop Collection")
                .disabled(isTimeTraveling || selectedCollection == nil)
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
                Table(collections, selection: $selectedCollection) {
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
        .task(id: appState.reloadToken) {
            await loadCollections()
        }
        .sheet(isPresented: $showCreateSheet) {
            VStack(spacing: 16) {
                Text("Create Collection")
                    .font(.headline)

                TextField("Collection Name", text: $formName)
                    .textFieldStyle(.roundedBorder)

                TextField("Dimension", text: $formDimension)
                    .textFieldStyle(.roundedBorder)

                Picker("Distance Metric", selection: $formMetric) {
                    Text("Cosine").tag("Cosine")
                    Text("Euclidean").tag("Euclidean")
                    Text("DotProduct").tag("DotProduct")
                }
                .pickerStyle(.segmented)

                HStack {
                    Button("Cancel") {
                        showCreateSheet = false
                    }
                    .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Create") {
                        Task {
                            await createCollection()
                            showCreateSheet = false
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(formName.isEmpty || Int(formDimension) == nil)
                }
            }
            .padding(20)
            .frame(minWidth: 350)
        }
        .alert("Drop Collection", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Drop", role: .destructive) {
                if let name = selectedCollection {
                    Task { await dropCollection(name) }
                }
            }
        } message: {
            if let name = selectedCollection {
                Text("Drop collection \"\(name)\"? All vectors will be deleted.")
            }
        }
    }

    // MARK: - Write Operations

    private func createCollection() async {
        guard let client = appState.client else { return }
        guard let dim = Int(formDimension) else { return }
        do {
            var cmd: [String: Any] = [
                "collection": formName,
                "dimension": dim,
                "metric": formMetric,
                "branch": appState.selectedBranch
            ]
            if appState.selectedSpace != "default" {
                cmd["space"] = appState.selectedSpace
            }
            let wrapper: [String: Any] = ["VectorCreateCollection": cmd]
            let data = try JSONSerialization.data(withJSONObject: wrapper)
            let jsonStr = String(data: data, encoding: .utf8)!
            _ = try await client.executeRaw(jsonStr)
            await loadCollections()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func dropCollection(_ name: String) async {
        guard let client = appState.client else { return }
        do {
            var cmd: [String: Any] = [
                "collection": name,
                "branch": appState.selectedBranch
            ]
            if appState.selectedSpace != "default" {
                cmd["space"] = appState.selectedSpace
            }
            let wrapper: [String: Any] = ["VectorDeleteCollection": cmd]
            let data = try JSONSerialization.data(withJSONObject: wrapper)
            let jsonStr = String(data: data, encoding: .utf8)!
            _ = try await client.executeRaw(jsonStr)
            if selectedCollection == name { selectedCollection = nil }
            await loadCollections()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Load

    private func loadCollections() async {
        guard let client = appState.client else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let json = try await client.executeRaw("{\"VectorListCollections\": {\"branch\": \"\(appState.selectedBranch)\"\(appState.spaceFragment())\(appState.asOfFragment())}}")
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
