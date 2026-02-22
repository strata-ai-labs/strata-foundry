//
//  ModelsView.swift
//  StrataFoundry
//
//  Models & Intelligence — registry, local models, embedding, configuration.
//

import SwiftUI

// MARK: - Model Structs

struct ModelEntry: Identifiable {
    var id: String { name }
    let name: String
    let task: String
    let architecture: String
    let defaultQuant: String
    let embeddingDim: Int
    let isLocal: Bool
    let sizeBytes: Int
}

enum ModelsMode: String, CaseIterable {
    case embed = "Embed"
    case configure = "Configure"
    case status = "Status"
}

// MARK: - View

struct ModelsView: View {
    @Environment(AppState.self) private var appState

    @State private var registryModels: [ModelEntry] = []
    @State private var localModels: [ModelEntry] = []
    @State private var selectedModel: String?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var modelsMode: ModelsMode = .embed

    // Pull
    @State private var pullMessage: String?
    @State private var isPulling = false

    // Embed
    @State private var embedText = ""
    @State private var embedResult: String?
    @State private var embedError: String?
    @State private var embedBatchText = ""
    @State private var embedBatchResult: String?
    @State private var embedBatchError: String?

    // Configure
    @State private var configEndpoint = ""
    @State private var configModel = ""
    @State private var configApiKey = ""
    @State private var configTimeout = ""
    @State private var configMessage: String?
    @State private var configError: String?

    // Status
    @State private var embedStatus: String?
    @State private var embedStatusError: String?

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Header
            HStack {
                Text("Models & Intelligence")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(registryModels.count) registry, \(localModels.count) local")
                    .foregroundStyle(.secondary)
                Button {
                    Task { await loadModels() }
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
                ProgressView("Loading models...")
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                Text(error).foregroundStyle(.red).padding()
                Spacer()
            } else {
                HSplitView {
                    // Left pane: model list
                    modelListPane
                        .frame(minWidth: 220, idealWidth: 280)

                    // Right pane: operations
                    rightPane
                }
            }
        }
        .task(id: appState.reloadToken) {
            await loadModels()
        }
    }

    // MARK: - Model List Pane

    @ViewBuilder
    private var modelListPane: some View {
        List(selection: $selectedModel) {
            if !registryModels.isEmpty {
                Section("Registry") {
                    ForEach(registryModels) { model in
                        modelRow(model)
                            .tag(model.name)
                    }
                }
            }
            if !localModels.isEmpty {
                Section("Local") {
                    ForEach(localModels) { model in
                        modelRow(model)
                            .tag(model.name)
                    }
                }
            }
            if registryModels.isEmpty && localModels.isEmpty {
                Text("No models found")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func modelRow(_ model: ModelEntry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(model.name)
                    .font(.system(.body, design: .monospaced))
                if model.isLocal {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }
            HStack(spacing: 8) {
                Text(model.task)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !model.architecture.isEmpty {
                    Text(model.architecture)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                if model.embeddingDim > 0 {
                    Text("dim=\(model.embeddingDim)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .contextMenu {
            if !model.isLocal {
                Button("Pull Model") {
                    Task { await pullModel(model.name) }
                }
            }
        }
    }

    // MARK: - Right Pane

    @ViewBuilder
    private var rightPane: some View {
        VStack(spacing: 0) {
            // Pull status
            if isPulling {
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
            if let msg = pullMessage {
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
            Picker("Mode", selection: $modelsMode) {
                ForEach(ModelsMode.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    switch modelsMode {
                    case .embed:
                        embedModeView()
                    case .configure:
                        configureModeView()
                    case .status:
                        statusModeView()
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Embed Mode

    @ViewBuilder
    private func embedModeView() -> some View {
        Text("Single Embed")
            .font(.headline)

        TextField("Text to embed", text: $embedText, axis: .vertical)
            .textFieldStyle(.roundedBorder)
            .lineLimit(3...6)

        Button("Embed") {
            Task { await runEmbed() }
        }
        .disabled(embedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        if let error = embedError {
            Text(error).foregroundStyle(.red).font(.callout)
        }
        if let result = embedResult {
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

        TextEditor(text: $embedBatchText)
            .font(.system(.body, design: .monospaced))
            .frame(minHeight: 100)
            .border(Color.secondary.opacity(0.3))

        Button("Embed Batch") {
            Task { await runEmbedBatch() }
        }
        .disabled(embedBatchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        if let error = embedBatchError {
            Text(error).foregroundStyle(.red).font(.callout)
        }
        if let result = embedBatchResult {
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
    private func configureModeView() -> some View {
        Text("Configure Model")
            .font(.headline)

        TextField("Endpoint URL", text: $configEndpoint)
            .textFieldStyle(.roundedBorder)

        TextField("Model Name", text: $configModel)
            .textFieldStyle(.roundedBorder)

        TextField("API Key", text: $configApiKey)
            .textFieldStyle(.roundedBorder)

        TextField("Timeout (ms)", text: $configTimeout)
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 150)

        Button("Apply Configuration") {
            Task { await configureModel() }
        }

        if let msg = configMessage {
            Text(msg).foregroundStyle(.green).font(.callout)
        }
        if let error = configError {
            Text(error).foregroundStyle(.red).font(.callout)
        }
    }

    // MARK: - Status Mode

    @ViewBuilder
    private func statusModeView() -> some View {
        Text("Embedding Status")
            .font(.headline)

        Button("Refresh Status") {
            Task { await loadEmbedStatus() }
        }

        if let error = embedStatusError {
            Text(error).foregroundStyle(.red).font(.callout)
        }
        if let status = embedStatus {
            GroupBox("Status") {
                Text(status)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - API Operations

    private func loadModels() async {
        guard let client = appState.client else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // Load registry models
            let registryJSON = try await client.executeRaw("{\"ModelsList\": {}}")
            registryModels = parseModelList(registryJSON)

            // Load local models
            let localJSON = try await client.executeRaw("{\"ModelsLocal\": {}}")
            localModels = parseModelList(localJSON)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func parseModelList(_ json: String) -> [ModelEntry] {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = root["ModelsList"] as? [[String: Any]] else {
            return []
        }
        return list.compactMap { item in
            guard let name = item["name"] as? String else { return nil }
            return ModelEntry(
                name: name,
                task: item["task"] as? String ?? "",
                architecture: item["architecture"] as? String ?? "",
                defaultQuant: item["default_quant"] as? String ?? "",
                embeddingDim: item["embedding_dim"] as? Int ?? 0,
                isLocal: item["is_local"] as? Bool ?? false,
                sizeBytes: item["size_bytes"] as? Int ?? 0
            )
        }
    }

    private func pullModel(_ name: String) async {
        guard let client = appState.client else { return }
        isPulling = true
        pullMessage = nil
        defer { isPulling = false }

        do {
            let wrapper: [String: Any] = ["ModelsPull": ["model": name]]
            let data = try JSONSerialization.data(withJSONObject: wrapper)
            let jsonStr = String(data: data, encoding: .utf8)!
            let json = try await client.executeRaw(jsonStr)

            if let respData = json.data(using: .utf8),
               let root = try? JSONSerialization.jsonObject(with: respData) as? [String: Any],
               let pulled = root["ModelsPulled"] as? [String: Any] {
                let path = pulled["path"] as? String ?? ""
                pullMessage = "Pulled \(name) to \(path)"
            } else {
                pullMessage = "Model \(name) pulled."
            }
            await loadModels()
        } catch {
            pullMessage = "Pull failed: \(error.localizedDescription)"
        }
    }

    private func runEmbed() async {
        guard let client = appState.client else { return }
        embedResult = nil
        embedError = nil
        do {
            let wrapper: [String: Any] = ["Embed": ["text": embedText]]
            let data = try JSONSerialization.data(withJSONObject: wrapper)
            let jsonStr = String(data: data, encoding: .utf8)!
            let json = try await client.executeRaw(jsonStr)

            if let respData = json.data(using: .utf8),
               let root = try? JSONSerialization.jsonObject(with: respData) as? [String: Any],
               let embedding = root["Embedding"] as? [Any] {
                let vals = embedding.prefix(20).map { "\($0)" }.joined(separator: ", ")
                let suffix = embedding.count > 20 ? ", ... (\(embedding.count) dims)" : ""
                embedResult = "[\(vals)\(suffix)]"
            } else {
                embedError = "Unexpected response"
            }
        } catch {
            embedError = error.localizedDescription
        }
    }

    private func runEmbedBatch() async {
        guard let client = appState.client else { return }
        embedBatchResult = nil
        embedBatchError = nil
        do {
            let texts = embedBatchText.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            let wrapper: [String: Any] = ["EmbedBatch": ["texts": texts]]
            let data = try JSONSerialization.data(withJSONObject: wrapper)
            let jsonStr = String(data: data, encoding: .utf8)!
            let json = try await client.executeRaw(jsonStr)

            if let respData = json.data(using: .utf8),
               let root = try? JSONSerialization.jsonObject(with: respData) as? [String: Any],
               let embeddings = root["Embeddings"] as? [[Any]] {
                embedBatchResult = "\(embeddings.count) embeddings generated (dim=\(embeddings.first?.count ?? 0))"
            } else {
                embedBatchError = "Unexpected response"
            }
        } catch {
            embedBatchError = error.localizedDescription
        }
    }

    private func configureModel() async {
        guard let client = appState.client else { return }
        configMessage = nil
        configError = nil
        do {
            var cmd: [String: Any] = [:]
            if !configEndpoint.isEmpty { cmd["endpoint"] = configEndpoint }
            if !configModel.isEmpty { cmd["model"] = configModel }
            if !configApiKey.isEmpty { cmd["api_key"] = configApiKey }
            if let timeout = Int(configTimeout) { cmd["timeout_ms"] = timeout }

            let wrapper: [String: Any] = ["ConfigureModel": cmd]
            let data = try JSONSerialization.data(withJSONObject: wrapper)
            let jsonStr = String(data: data, encoding: .utf8)!
            _ = try await client.executeRaw(jsonStr)
            configMessage = "Configuration applied."
        } catch {
            configError = error.localizedDescription
        }
    }

    private func loadEmbedStatus() async {
        guard let client = appState.client else { return }
        embedStatus = nil
        embedStatusError = nil
        do {
            let json = try await client.executeRaw("{\"EmbedStatus\": {}}")
            if let respData = json.data(using: .utf8),
               let root = try? JSONSerialization.jsonObject(with: respData) as? [String: Any],
               let status = root["EmbedStatus"] as? [String: Any] {
                let prettyData = try JSONSerialization.data(withJSONObject: status, options: [.prettyPrinted, .sortedKeys])
                embedStatus = String(data: prettyData, encoding: .utf8)
            } else {
                embedStatusError = "No status available"
            }
        } catch {
            embedStatusError = error.localizedDescription
        }
    }
}
