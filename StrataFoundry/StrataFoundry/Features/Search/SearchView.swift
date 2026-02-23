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
        Group {
            if let model {
                searchContent(model)
            } else {
                SkeletonLoadingView()
            }
        }
        .navigationTitle("Search")
        .searchable(
            text: Binding(
                get: { model?.query ?? "" },
                set: { model?.query = $0 }
            ),
            prompt: "Search query..."
        )
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await model?.performSearch() }
                } label: {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .help("Search")
                .disabled(model?.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true || model?.isSearching ?? false)
            }
        }
        .task(id: appState.reloadToken) {
            if model == nil, let services = appState.services {
                model = SearchFeatureModel(searchService: services.searchService, appState: appState)
            }
            model?.reset()
        }
    }

    // MARK: - Search Content

    @ViewBuilder
    private func searchContent(_ model: SearchFeatureModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: StrataSpacing.md) {
                // Options row
                HStack(spacing: StrataSpacing.md) {
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
                HStack(spacing: StrataSpacing.xs) {
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

                if model.isSearching {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Searching...")
                            .strataSecondaryStyle()
                    }
                }

                if let error = model.errorMessage {
                    StrataErrorCallout(message: error)
                }

                // Results
                if !model.results.isEmpty {
                    Divider()

                    Text("\(model.results.count) results")
                        .strataCountStyle()

                    ForEach(model.results) { hit in
                        HStack {
                            VStack(alignment: .leading, spacing: StrataSpacing.xxs) {
                                HStack {
                                    Text(hit.entity)
                                        .strataKeyStyle()
                                    Spacer()
                                    Text(hit.primitive)
                                        .strataBadgeStyle()
                                    Text("#\(hit.rank)")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                    Text(String(format: "%.4f", hit.score))
                                        .strataCodeStyle()
                                        .foregroundStyle(.secondary)
                                }
                                if !hit.snippet.isEmpty {
                                    Text(hit.snippet)
                                        .strataSecondaryStyle()
                                        .lineLimit(3)
                                }
                            }
                        }
                        .padding(StrataSpacing.sm)
                        .background(.quaternary.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: StrataRadius.md))
                    }
                }
            }
            .padding(StrataSpacing.lg)
        }
    }
}
