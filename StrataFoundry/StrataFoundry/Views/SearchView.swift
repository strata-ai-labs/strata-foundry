//
//  SearchView.swift
//  StrataFoundry
//
//  Full-text / hybrid search across all primitives.
//

import SwiftUI

// MARK: - Model

struct SearchHit: Identifiable {
    let id: UUID
    let entity: String
    let primitive: String
    let score: Double
    let rank: Int
    let snippet: String
}

// MARK: - View

struct SearchView: View {
    @Environment(AppState.self) private var appState

    // Search form
    @State private var query = ""
    @State private var k = "10"
    @State private var mode = "hybrid"
    @State private var selectedPrimitives: Set<String> = []
    @State private var useTimeRange = false
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var expandResults = false
    @State private var rerankResults = false

    // Results
    @State private var results: [SearchHit] = []
    @State private var isSearching = false
    @State private var errorMessage: String?

    private let allPrimitives = ["kv", "json", "event", "state", "vector"]

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Header
            HStack {
                Text("Search")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Query
                    TextField("Search query...", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body))

                    // Options row
                    HStack(spacing: 16) {
                        HStack {
                            Text("k")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("10", text: $k)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                        }

                        Picker("Mode", selection: $mode) {
                            Text("Keyword").tag("keyword")
                            Text("Hybrid").tag("hybrid")
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 200)

                        Toggle("Expand", isOn: $expandResults)
                            .toggleStyle(.checkbox)
                        Toggle("Rerank", isOn: $rerankResults)
                            .toggleStyle(.checkbox)
                    }

                    // Primitives filter
                    HStack(spacing: 8) {
                        Text("Primitives:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(allPrimitives, id: \.self) { prim in
                            Toggle(prim, isOn: Binding(
                                get: { selectedPrimitives.contains(prim) },
                                set: { isOn in
                                    if isOn { selectedPrimitives.insert(prim) }
                                    else { selectedPrimitives.remove(prim) }
                                }
                            ))
                            .toggleStyle(.checkbox)
                        }
                    }

                    // Time range
                    HStack {
                        Toggle("Time Range", isOn: $useTimeRange)
                            .toggleStyle(.checkbox)
                        if useTimeRange {
                            DatePicker("From", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                            Text("to")
                                .foregroundStyle(.secondary)
                            DatePicker("To", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                        }
                    }

                    // Search button
                    HStack {
                        Button("Search") {
                            Task { await performSearch() }
                        }
                        .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching)

                        if isSearching {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }

                    if let error = errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.callout)
                    }

                    // Results
                    if !results.isEmpty {
                        Divider()

                        Text("\(results.count) results")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(results) { hit in
                            GroupBox {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(hit.entity)
                                            .font(.system(.body, design: .monospaced))
                                            .fontWeight(.medium)
                                        Spacer()
                                        Text(hit.primitive)
                                            .font(.caption)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(.quaternary)
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                        Text("#\(hit.rank)")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                        Text(String(format: "%.4f", hit.score))
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                    }
                                    if !hit.snippet.isEmpty {
                                        Text(hit.snippet)
                                            .font(.callout)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(3)
                                    }
                                }
                            }
                        }
                    } else if !isSearching && errorMessage == nil && !query.isEmpty {
                        // Show empty state only after a search has been attempted
                    }
                }
                .padding(24)
            }
        }
        .task(id: appState.reloadToken) {
            // Reset on branch/space change
            results = []
            errorMessage = nil
        }
    }

    // MARK: - Search

    private func performSearch() async {
        guard let client = appState.client else { return }
        results = []
        errorMessage = nil
        isSearching = true
        defer { isSearching = false }

        do {
            var searchParams: [String: Any] = [
                "query": query,
                "k": Int(k) ?? 10,
                "mode": mode
            ]

            if !selectedPrimitives.isEmpty {
                searchParams["primitives"] = Array(selectedPrimitives)
            }

            if expandResults {
                searchParams["expand"] = true
            }
            if rerankResults {
                searchParams["rerank"] = true
            }

            if useTimeRange {
                let startMicros = Int64(startDate.timeIntervalSince1970 * 1_000_000)
                let endMicros = Int64(endDate.timeIntervalSince1970 * 1_000_000)
                searchParams["time_range"] = ["start": startMicros, "end": endMicros]
            }

            var cmd: [String: Any] = [
                "branch": appState.selectedBranch,
                "search": searchParams
            ]
            if appState.selectedSpace != "default" {
                cmd["space"] = appState.selectedSpace
            }
            if let date = appState.timeTravelDate {
                cmd["as_of"] = Int64(date.timeIntervalSince1970 * 1_000_000)
            }

            let wrapper: [String: Any] = ["Search": cmd]
            let data = try JSONSerialization.data(withJSONObject: wrapper)
            let jsonStr = String(data: data, encoding: .utf8)!
            let json = try await client.executeRaw(jsonStr)

            guard let respData = json.data(using: .utf8),
                  let root = try? JSONSerialization.jsonObject(with: respData) as? [String: Any],
                  let hits = root["SearchResults"] as? [[String: Any]] else {
                errorMessage = "No results found"
                return
            }

            results = hits.enumerated().compactMap { (index, hit) in
                let entity = hit["entity"] as? String ?? "unknown"
                let primitive = hit["primitive"] as? String ?? "unknown"
                let score = hit["score"] as? Double ?? 0.0
                let rank = hit["rank"] as? Int ?? (index + 1)
                let snippet = hit["snippet"] as? String ?? ""
                return SearchHit(id: UUID(), entity: entity, primitive: primitive, score: score, rank: rank, snippet: snippet)
            }

            if results.isEmpty {
                errorMessage = "No results found"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
