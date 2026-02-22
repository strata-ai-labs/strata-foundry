//
//  GenerationView.swift
//  StrataFoundry
//
//  Text generation — generate, tokenize, detokenize, unload.
//

import SwiftUI

// MARK: - Mode

enum GenerationMode: String, CaseIterable {
    case generate = "Generate"
    case tokenize = "Tokenize"
    case detokenize = "Detokenize"
    case unload = "Unload"
}

// MARK: - View

struct GenerationView: View {
    @Environment(AppState.self) private var appState

    @State private var generationMode: GenerationMode = .generate

    // Generate
    @State private var genModel = ""
    @State private var genPrompt = ""
    @State private var genMaxTokens = "256"
    @State private var genTemperature = "0.7"
    @State private var genTopK = ""
    @State private var genTopP = ""
    @State private var genSeed = ""
    @State private var genResult: String?
    @State private var genMeta: String?
    @State private var genError: String?
    @State private var isGenerating = false

    // Tokenize
    @State private var tokModel = ""
    @State private var tokText = ""
    @State private var tokResult: String?
    @State private var tokError: String?

    // Detokenize
    @State private var detokModel = ""
    @State private var detokIds = ""
    @State private var detokResult: String?
    @State private var detokError: String?

    // Unload
    @State private var unloadModel = ""
    @State private var unloadResult: String?
    @State private var unloadError: String?

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Header
            HStack {
                Text("Generation")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)

            Divider()

            // Mode picker
            Picker("Mode", selection: $generationMode) {
                ForEach(GenerationMode.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    switch generationMode {
                    case .generate:
                        generateModeView()
                    case .tokenize:
                        tokenizeModeView()
                    case .detokenize:
                        detokenizeModeView()
                    case .unload:
                        unloadModeView()
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .task(id: appState.reloadToken) {
            // Reset state on branch/space change
            genResult = nil
            genMeta = nil
            genError = nil
            tokResult = nil
            tokError = nil
            detokResult = nil
            detokError = nil
            unloadResult = nil
            unloadError = nil
        }
    }

    // MARK: - Generate Mode

    @ViewBuilder
    private func generateModeView() -> some View {
        TextField("Model (optional — uses default)", text: $genModel)
            .textFieldStyle(.roundedBorder)

        Text("Prompt")
            .font(.caption)
            .foregroundStyle(.secondary)
        TextEditor(text: $genPrompt)
            .font(.system(.body, design: .monospaced))
            .frame(minHeight: 120)
            .border(Color.secondary.opacity(0.3))

        // Sampling params
        HStack(spacing: 16) {
            HStack {
                Text("Max Tokens")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("256", text: $genMaxTokens)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
            }
            HStack {
                Text("Temperature")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("0.7", text: $genTemperature)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
            }
            HStack {
                Text("Top-K")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("", text: $genTopK)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
            }
            HStack {
                Text("Top-P")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("", text: $genTopP)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
            }
        }

        HStack {
            Text("Seed")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("(optional)", text: $genSeed)
                .textFieldStyle(.roundedBorder)
                .frame(width: 100)
        }

        HStack {
            Button("Generate") {
                Task { await runGenerate() }
            }
            .disabled(genPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)

            if isGenerating {
                ProgressView()
                    .controlSize(.small)
            }
        }

        if let error = genError {
            Text(error).foregroundStyle(.red).font(.callout)
        }

        if let result = genResult {
            GroupBox("Generated Text") {
                Text(result)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        if let meta = genMeta {
            Text(meta)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Tokenize Mode

    @ViewBuilder
    private func tokenizeModeView() -> some View {
        TextField("Model (optional)", text: $tokModel)
            .textFieldStyle(.roundedBorder)

        Text("Text to tokenize")
            .font(.caption)
            .foregroundStyle(.secondary)
        TextEditor(text: $tokText)
            .font(.system(.body, design: .monospaced))
            .frame(minHeight: 80)
            .border(Color.secondary.opacity(0.3))

        Button("Tokenize") {
            Task { await runTokenize() }
        }
        .disabled(tokText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        if let error = tokError {
            Text(error).foregroundStyle(.red).font(.callout)
        }

        if let result = tokResult {
            GroupBox("Token IDs") {
                Text(result)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Detokenize Mode

    @ViewBuilder
    private func detokenizeModeView() -> some View {
        TextField("Model (optional)", text: $detokModel)
            .textFieldStyle(.roundedBorder)

        Text("Token IDs (JSON array of integers)")
            .font(.caption)
            .foregroundStyle(.secondary)
        TextEditor(text: $detokIds)
            .font(.system(.body, design: .monospaced))
            .frame(minHeight: 80)
            .border(Color.secondary.opacity(0.3))

        Button("Detokenize") {
            Task { await runDetokenize() }
        }
        .disabled(detokIds.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        if let error = detokError {
            Text(error).foregroundStyle(.red).font(.callout)
        }

        if let result = detokResult {
            GroupBox("Decoded Text") {
                Text(result)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Unload Mode

    @ViewBuilder
    private func unloadModeView() -> some View {
        Text("Unload a loaded generation model from memory.")
            .font(.callout)
            .foregroundStyle(.secondary)

        TextField("Model name", text: $unloadModel)
            .textFieldStyle(.roundedBorder)

        Button("Unload Model") {
            Task { await runUnload() }
        }
        .disabled(unloadModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        if let error = unloadError {
            Text(error).foregroundStyle(.red).font(.callout)
        }
        if let result = unloadResult {
            Text(result).foregroundStyle(.green).font(.callout)
        }
    }

    // MARK: - API Operations

    private func runGenerate() async {
        guard let client = appState.client else { return }
        genResult = nil
        genMeta = nil
        genError = nil
        isGenerating = true
        defer { isGenerating = false }

        do {
            var cmd: [String: Any] = [
                "prompt": genPrompt
            ]
            if !genModel.isEmpty { cmd["model"] = genModel }
            if let maxTok = Int(genMaxTokens) { cmd["max_tokens"] = maxTok }
            if let temp = Double(genTemperature) { cmd["temperature"] = temp }
            if let topK = Int(genTopK) { cmd["top_k"] = topK }
            if let topP = Double(genTopP) { cmd["top_p"] = topP }
            if let seed = Int(genSeed) { cmd["seed"] = seed }

            let wrapper: [String: Any] = ["Generate": cmd]
            let data = try JSONSerialization.data(withJSONObject: wrapper)
            let jsonStr = String(data: data, encoding: .utf8)!
            let json = try await client.executeRaw(jsonStr)

            if let respData = json.data(using: .utf8),
               let root = try? JSONSerialization.jsonObject(with: respData) as? [String: Any],
               let gen = root["Generated"] as? [String: Any] {
                genResult = gen["text"] as? String ?? ""
                let stopReason = gen["stop_reason"] as? String ?? ""
                let promptTokens = gen["prompt_tokens"] as? Int ?? 0
                let completionTokens = gen["completion_tokens"] as? Int ?? 0
                let model = gen["model"] as? String ?? ""
                genMeta = "Model: \(model) | Stop: \(stopReason) | Prompt tokens: \(promptTokens) | Completion tokens: \(completionTokens)"
            } else {
                genError = "Unexpected response"
            }
        } catch {
            genError = error.localizedDescription
        }
    }

    private func runTokenize() async {
        guard let client = appState.client else { return }
        tokResult = nil
        tokError = nil
        do {
            var cmd: [String: Any] = ["text": tokText]
            if !tokModel.isEmpty { cmd["model"] = tokModel }

            let wrapper: [String: Any] = ["Tokenize": cmd]
            let data = try JSONSerialization.data(withJSONObject: wrapper)
            let jsonStr = String(data: data, encoding: .utf8)!
            let json = try await client.executeRaw(jsonStr)

            if let respData = json.data(using: .utf8),
               let root = try? JSONSerialization.jsonObject(with: respData) as? [String: Any],
               let tokenIds = root["TokenIds"] as? [String: Any] {
                let ids = tokenIds["ids"] as? [Any] ?? []
                let count = tokenIds["count"] as? Int ?? ids.count
                let model = tokenIds["model"] as? String ?? ""
                let idsStr = ids.map { "\($0)" }.joined(separator: ", ")
                tokResult = "[\(idsStr)]\n\nCount: \(count)\(model.isEmpty ? "" : " | Model: \(model)")"
            } else {
                tokError = "Unexpected response"
            }
        } catch {
            tokError = error.localizedDescription
        }
    }

    private func runDetokenize() async {
        guard let client = appState.client else { return }
        detokResult = nil
        detokError = nil
        do {
            guard let idsData = detokIds.data(using: .utf8),
                  let ids = try? JSONSerialization.jsonObject(with: idsData) as? [Any] else {
                detokError = "Invalid token IDs: must be a JSON array of integers"
                return
            }

            var cmd: [String: Any] = ["ids": ids]
            if !detokModel.isEmpty { cmd["model"] = detokModel }

            let wrapper: [String: Any] = ["Detokenize": cmd]
            let data = try JSONSerialization.data(withJSONObject: wrapper)
            let jsonStr = String(data: data, encoding: .utf8)!
            let json = try await client.executeRaw(jsonStr)

            if let respData = json.data(using: .utf8),
               let root = try? JSONSerialization.jsonObject(with: respData) as? [String: Any] {
                if let text = root["Text"] as? String {
                    detokResult = text
                } else {
                    detokError = "Unexpected response"
                }
            }
        } catch {
            detokError = error.localizedDescription
        }
    }

    private func runUnload() async {
        guard let client = appState.client else { return }
        unloadResult = nil
        unloadError = nil
        do {
            let wrapper: [String: Any] = ["GenerateUnload": ["model": unloadModel]]
            let data = try JSONSerialization.data(withJSONObject: wrapper)
            let jsonStr = String(data: data, encoding: .utf8)!
            let json = try await client.executeRaw(jsonStr)

            if let respData = json.data(using: .utf8),
               let root = try? JSONSerialization.jsonObject(with: respData) as? [String: Any],
               let success = root["Bool"] as? Bool {
                unloadResult = success ? "Model \"\(unloadModel)\" unloaded." : "Model was not loaded."
            } else {
                unloadResult = "Unload command sent."
            }
        } catch {
            unloadError = error.localizedDescription
        }
    }
}
