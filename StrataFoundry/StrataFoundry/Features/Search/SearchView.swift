//
//  SearchView.swift
//  StrataFoundry
//
//  Full-text / hybrid search across all primitives.
//  Thin view observing SearchFeatureModel — all business logic delegated to model.
//

import SwiftUI

struct SearchView: View {
    @Environment(AppState.self) private var appState
    @State private var model: SearchFeatureModel?

    var body: some View {
        VStack(spacing: 0) {
            if let model {
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
                        TextField("Search query...", text: Binding(
                            get: { model.query },
                            set: { model.query = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body))

                        // Options row
                        HStack(spacing: 16) {
                            HStack {
                                Text("k")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("10", text: Binding(
                                    get: { model.k },
                                    set: { model.k = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            }

                            Picker("Mode", selection: Binding(
                                get: { model.mode },
                                set: { model.mode = $0 }
                            )) {
                                Text("Keyword").tag("keyword")
                                Text("Hybrid").tag("hybrid")
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 200)

                            Toggle("Expand", isOn: Binding(
                                get: { model.expandResults },
                                set: { model.expandResults = $0 }
                            ))
                            .toggleStyle(.checkbox)
                            Toggle("Rerank", isOn: Binding(
                                get: { model.rerankResults },
                                set: { model.rerankResults = $0 }
                            ))
                            .toggleStyle(.checkbox)
                        }

                        // Primitives filter
                        HStack(spacing: 8) {
                            Text("Primitives:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ForEach(model.allPrimitives, id: \.self) { prim in
                                Toggle(prim, isOn: Binding(
                                    get: { model.selectedPrimitives.contains(prim) },
                                    set: { isOn in
                                        if isOn { model.selectedPrimitives.insert(prim) }
                                        else { model.selectedPrimitives.remove(prim) }
                                    }
                                ))
                                .toggleStyle(.checkbox)
                            }
                        }

                        // Time range
                        HStack {
                            Toggle("Time Range", isOn: Binding(
                                get: { model.useTimeRange },
                                set: { model.useTimeRange = $0 }
                            ))
                            .toggleStyle(.checkbox)
                            if model.useTimeRange {
                                DatePicker("From", selection: Binding(
                                    get: { model.startDate },
                                    set: { model.startDate = $0 }
                                ), displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                                Text("to")
                                    .foregroundStyle(.secondary)
                                DatePicker("To", selection: Binding(
                                    get: { model.endDate },
                                    set: { model.endDate = $0 }
                                ), displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                            }
                        }

                        // Search button
                        HStack {
                            Button("Search") {
                                Task { await model.performSearch() }
                            }
                            .disabled(model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isSearching)

                            if model.isSearching {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }

                        if let error = model.errorMessage {
                            Text(error)
                                .foregroundStyle(.red)
                                .font(.callout)
                        }

                        // Results
                        if !model.results.isEmpty {
                            Divider()

                            Text("\(model.results.count) results")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ForEach(model.results) { hit in
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
                        } else if !model.isSearching && model.errorMessage == nil && !model.query.isEmpty {
                            // Show empty state only after a search has been attempted
                        }
                    }
                    .padding(24)
                }
            } else {
                Spacer()
                ProgressView("Loading...")
                Spacer()
            }
        }
        .task(id: appState.reloadToken) {
            if model == nil, let services = appState.services {
                model = SearchFeatureModel(searchService: services.searchService, appState: appState)
            }
            model?.reset()
        }
    }
}
