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
        Group {
            if let model {
                modelsContent(model)
            } else {
                SkeletonLoadingView()
            }
        }
        .navigationTitle("Models & Intelligence")
        .navigationSubtitle(model.map { "\($0.registryModels.count) registry, \($0.localModels.count) local" } ?? "")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Mode", selection: Binding(
                    get: { model?.modelsMode ?? .embed },
                    set: { model?.modelsMode = $0 }
                )) {
                    ForEach(ModelsPaneMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await model?.loadModels() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh")
            }
        }
        .task(id: appState.reloadToken) {
            if model == nil, let services = appState.services {
                model = ModelsFeatureModel(modelService: services.modelService, searchService: services.searchService, appState: appState)
            }
            await model?.loadModels()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func modelsContent(_ model: ModelsFeatureModel) -> some View {
        if model.isLoading {
            SkeletonLoadingView()
        } else if let error = model.errorMessage {
            VStack {
                Spacer()
                StrataErrorCallout(message: error)
                Spacer()
            }
        } else {
            HSplitView {
                modelListPane(model)
                    .frame(minWidth: 220, idealWidth: 280)
                rightPane(model)
            }
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
                    .strataKeyStyle()
                if entry.isLocal {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }
            HStack(spacing: StrataSpacing.xs) {
                Text(entry.task)
                    .strataBadgeStyle()
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
            if model.isPulling {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Pulling model...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, StrataSpacing.md)
                .padding(.vertical, StrataSpacing.xs)
            }
            if let msg = model.pullMessage {
                StrataSuccessCallout(message: msg)
                    .padding(.horizontal, StrataSpacing.md)
                    .padding(.vertical, StrataSpacing.xs)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: StrataSpacing.sm) {
                    switch model.modelsMode {
                    case .embed:
                        embedModeView(model)
                    case .configure:
                        configureModeView(model)
                    case .status:
                        statusModeView(model)
                    }
                }
                .padding(StrataSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Embed Mode

    @ViewBuilder
    private func embedModeView(_ model: ModelsFeatureModel) -> some View {
        Text("Single Embed")
            .strataSectionHeader()

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
            StrataErrorCallout(message: error)
        }
        if let result = model.embedResult {
            GroupBox("Embedding") {
                Text(result)
                    .strataCodeStyle()
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }

        Divider()

        Text("Batch Embed")
            .strataSectionHeader()

        Text("One text per line")
            .font(.caption)
            .foregroundStyle(.secondary)

        TextEditor(text: Binding(
            get: { model.embedBatchText },
            set: { model.embedBatchText = $0 }
        ))
            .font(.system(.body, design: .monospaced))
            .frame(minHeight: 100)
            .overlay(RoundedRectangle(cornerRadius: StrataRadius.md).stroke(.separator))

        Button("Embed Batch") {
            Task { await model.runEmbedBatch() }
        }
        .disabled(model.embedBatchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        if let error = model.embedBatchError {
            StrataErrorCallout(message: error)
        }
        if let result = model.embedBatchResult {
            GroupBox("Batch Embeddings") {
                Text(result)
                    .strataCodeStyle()
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Configure Mode

    @ViewBuilder
    private func configureModeView(_ model: ModelsFeatureModel) -> some View {
        Text("Configure Model")
            .strataSectionHeader()

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
            StrataSuccessCallout(message: msg)
        }
        if let error = model.configError {
            StrataErrorCallout(message: error)
        }
    }

    // MARK: - Status Mode

    @ViewBuilder
    private func statusModeView(_ model: ModelsFeatureModel) -> some View {
        Text("Embedding Status")
            .strataSectionHeader()

        Button("Refresh Status") {
            Task { await model.loadEmbedStatus() }
        }

        if let error = model.embedStatusError {
            StrataErrorCallout(message: error)
        }
        if let status = model.embedStatus {
            GroupBox("Status") {
                Text(status)
                    .strataCodeStyle()
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
