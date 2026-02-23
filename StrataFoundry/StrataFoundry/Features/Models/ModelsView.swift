//
//  ModelsView.swift
//  StrataFoundry
//
//  Models & Intelligence — thin view observing ModelsFeatureModel.
//  All business logic delegated to model.
//

import SwiftUI

// MARK: - View

struct ModelsView: View {
    @Environment(AppState.self) private var appState
    @State private var model: ModelsFeatureModel?

    var body: some View {
        VStack(spacing: 0) {
            if let model {
                // MARK: Header
                HStack {
                    Text("Models & Intelligence")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(model.registryModels.count) registry, \(model.localModels.count) local")
                        .foregroundStyle(.secondary)
                    Button {
                        Task { await model.loadModels() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Refresh")
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)

                Divider()

                if model.isLoading {
                    Spacer()
                    ProgressView("Loading models...")
                    Spacer()
                } else if let error = model.errorMessage {
                    Spacer()
                    Text(error).foregroundStyle(.red).padding()
                    Spacer()
                } else {
                    HSplitView {
                        // Left pane: model list
                        modelListPane(model)
                            .frame(minWidth: 220, idealWidth: 280)

                        // Right pane: operations
                        rightPane(model)
                    }
                }
            } else {
                Spacer()
                ProgressView("Loading...")
                Spacer()
            }
        }
        .task(id: appState.reloadToken) {
            if model == nil, let services = appState.services {
                model = ModelsFeatureModel(modelService: services.modelService, searchService: services.searchService, appState: appState)
            }
            await model?.loadModels()
        }
    }

    // MARK: - Model List Pane

    @ViewBuilder
    private func modelListPane(_ model: ModelsFeatureModel) -> some View {
        List(selection: Binding(
            get: { model.selectedModel },
            set: { model.selectedModel = $0 }
        )) {
            if !model.registryModels.isEmpty {
                Section("Registry") {
                    ForEach(model.registryModels) { entry in
                        modelRow(entry, model: model)
                            .tag(entry.name)
                    }
                }
            }
            if !model.localModels.isEmpty {
                Section("Local") {
                    ForEach(model.localModels) { entry in
                        modelRow(entry, model: model)
                            .tag(entry.name)
                    }
                }
            }
            if model.registryModels.isEmpty && model.localModels.isEmpty {
                Text("No models found")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func modelRow(_ entry: ModelDisplay, model: ModelsFeatureModel) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(entry.name)
                    .font(.system(.body, design: .monospaced))
                if entry.isLocal {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }
            HStack(spacing: 8) {
                Text(entry.task)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !entry.architecture.isEmpty {
                    Text(entry.architecture)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                if entry.embeddingDim > 0 {
                    Text("dim=\(entry.embeddingDim)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .contextMenu {
            if !entry.isLocal {
                Button("Pull Model") {
                    Task { await model.pullModel(entry.name) }
                }
            }
        }
    }

    // MARK: - Right Pane

    @ViewBuilder
    private func rightPane(_ model: ModelsFeatureModel) -> some View {
        VStack(spacing: 0) {
            // Pull status
            if model.isPulling {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Pulling model...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
            if let msg = model.pullMessage {
                HStack {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.green)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }

            // Mode picker
            Picker("Mode", selection: Binding(
                get: { model.modelsMode },
                set: { model.modelsMode = $0 }
            )) {
                ForEach(ModelsPaneMode.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    switch model.modelsMode {
                    case .embed:
                        embedModeView(model)
                    case .configure:
                        configureModeView(model)
                    case .status:
                        statusModeView(model)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Embed Mode

    @ViewBuilder
    private func embedModeView(_ model: ModelsFeatureModel) -> some View {
        Text("Single Embed")
            .font(.headline)

        TextField("Text to embed", text: Binding(
            get: { model.embedText },
            set: { model.embedText = $0 }
        ), axis: .vertical)
            .textFieldStyle(.roundedBorder)
            .lineLimit(3...6)

        Button("Embed") {
            Task { await model.runEmbed() }
        }
        .disabled(model.embedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        if let error = model.embedError {
            Text(error).foregroundStyle(.red).font(.callout)
        }
        if let result = model.embedResult {
            GroupBox("Embedding") {
                Text(result)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }

        Divider()

        Text("Batch Embed")
            .font(.headline)

        Text("One text per line")
            .font(.caption)
            .foregroundStyle(.secondary)

        TextEditor(text: Binding(
            get: { model.embedBatchText },
            set: { model.embedBatchText = $0 }
        ))
            .font(.system(.body, design: .monospaced))
            .frame(minHeight: 100)
            .border(Color.secondary.opacity(0.3))

        Button("Embed Batch") {
            Task { await model.runEmbedBatch() }
        }
        .disabled(model.embedBatchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        if let error = model.embedBatchError {
            Text(error).foregroundStyle(.red).font(.callout)
        }
        if let result = model.embedBatchResult {
            GroupBox("Batch Embeddings") {
                Text(result)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Configure Mode

    @ViewBuilder
    private func configureModeView(_ model: ModelsFeatureModel) -> some View {
        Text("Configure Model")
            .font(.headline)

        TextField("Endpoint URL", text: Binding(
            get: { model.configEndpoint },
            set: { model.configEndpoint = $0 }
        ))
            .textFieldStyle(.roundedBorder)

        TextField("Model Name", text: Binding(
            get: { model.configModel },
            set: { model.configModel = $0 }
        ))
            .textFieldStyle(.roundedBorder)

        TextField("API Key", text: Binding(
            get: { model.configApiKey },
            set: { model.configApiKey = $0 }
        ))
            .textFieldStyle(.roundedBorder)

        TextField("Timeout (ms)", text: Binding(
            get: { model.configTimeout },
            set: { model.configTimeout = $0 }
        ))
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 150)

        Button("Apply Configuration") {
            Task { await model.configureModel() }
        }

        if let msg = model.configMessage {
            Text(msg).foregroundStyle(.green).font(.callout)
        }
        if let error = model.configError {
            Text(error).foregroundStyle(.red).font(.callout)
        }
    }

    // MARK: - Status Mode

    @ViewBuilder
    private func statusModeView(_ model: ModelsFeatureModel) -> some View {
        Text("Embedding Status")
            .font(.headline)

        Button("Refresh Status") {
            Task { await model.loadEmbedStatus() }
        }

        if let error = model.embedStatusError {
            Text(error).foregroundStyle(.red).font(.callout)
        }
        if let status = model.embedStatus {
            GroupBox("Status") {
                Text(status)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
