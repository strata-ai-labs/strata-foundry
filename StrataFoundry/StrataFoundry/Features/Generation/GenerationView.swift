//
//  GenerationView.swift
//  StrataFoundry
//
//  Text generation — generate, tokenize, detokenize, unload.
//  Thin view observing GenerationFeatureModel — all business logic delegated to model.
//

import SwiftUI

// MARK: - View

struct GenerationView: View {
    @Environment(AppState.self) private var appState
    @State private var model: GenerationFeatureModel?

    var body: some View {
        Group {
            if let model {
                generationContent(model)
            } else {
                SkeletonLoadingView()
            }
        }
        .navigationTitle("Generation")
        .toolbar {
            // Intentionally empty — generation doesn't need toolbar actions
        }
        .task(id: appState.reloadToken) {
            if model == nil, let services = appState.services {
                model = GenerationFeatureModel(generationService: services.generationService, appState: appState)
            }
            model?.resetState()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func generationContent(_ model: GenerationFeatureModel) -> some View {
        VStack(spacing: 0) {
            Picker("Mode", selection: Binding(
                get: { model.generationMode },
                set: { model.generationMode = $0 }
            )) {
                ForEach(GenerationPaneMode.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, StrataSpacing.lg)
            .padding(.vertical, StrataSpacing.xs)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: StrataSpacing.sm) {
                    switch model.generationMode {
                    case .generate:
                        generateModeView(model)
                    case .tokenize:
                        tokenizeModeView(model)
                    case .detokenize:
                        detokenizeModeView(model)
                    case .unload:
                        unloadModeView(model)
                    }
                }
                .padding(StrataSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Generate Mode

    @ViewBuilder
    private func generateModeView(_ model: GenerationFeatureModel) -> some View {
        TextField("Model (optional — uses default)", text: Binding(
            get: { model.genModel },
            set: { model.genModel = $0 }
        ))
        .textFieldStyle(.roundedBorder)

        Text("Prompt")
            .font(.caption)
            .foregroundStyle(.secondary)
        TextEditor(text: Binding(
            get: { model.genPrompt },
            set: { model.genPrompt = $0 }
        ))
        .font(.system(.body, design: .monospaced))
        .frame(minHeight: 120)
        .overlay(RoundedRectangle(cornerRadius: StrataRadius.md).stroke(.separator))

        // Sampling params
        HStack(spacing: StrataSpacing.md) {
            HStack {
                Text("Max Tokens")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("256", text: Binding(
                    get: { model.genMaxTokens },
                    set: { model.genMaxTokens = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 70)
            }
            HStack {
                Text("Temperature")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("0.7", text: Binding(
                    get: { model.genTemperature },
                    set: { model.genTemperature = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 70)
            }
            HStack {
                Text("Top-K")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("", text: Binding(
                    get: { model.genTopK },
                    set: { model.genTopK = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
            }
            HStack {
                Text("Top-P")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("", text: Binding(
                    get: { model.genTopP },
                    set: { model.genTopP = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
            }
        }

        HStack {
            Text("Seed")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("(optional)", text: Binding(
                get: { model.genSeed },
                set: { model.genSeed = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .frame(width: 100)
        }

        HStack {
            Button("Generate") {
                Task { await model.runGenerate() }
            }
            .disabled(model.genPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isGenerating)

            if model.isGenerating {
                ProgressView()
                    .controlSize(.small)
            }
        }

        if let error = model.genError {
            Text(error).foregroundStyle(.red).font(.callout)
        }

        if let result = model.genResult {
            GroupBox("Generated Text") {
                Text(result)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        if let meta = model.genMeta {
            Text(meta)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Tokenize Mode

    @ViewBuilder
    private func tokenizeModeView(_ model: GenerationFeatureModel) -> some View {
        TextField("Model (optional)", text: Binding(
            get: { model.tokModel },
            set: { model.tokModel = $0 }
        ))
        .textFieldStyle(.roundedBorder)

        Text("Text to tokenize")
            .font(.caption)
            .foregroundStyle(.secondary)
        TextEditor(text: Binding(
            get: { model.tokText },
            set: { model.tokText = $0 }
        ))
        .font(.system(.body, design: .monospaced))
        .frame(minHeight: 80)
        .overlay(RoundedRectangle(cornerRadius: StrataRadius.md).stroke(.separator))

        Button("Tokenize") {
            Task { await model.runTokenize() }
        }
        .disabled(model.tokText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        if let error = model.tokError {
            Text(error).foregroundStyle(.red).font(.callout)
        }

        if let result = model.tokResult {
            GroupBox("Token IDs") {
                Text(result)
                    .strataCodeStyle()
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Detokenize Mode

    @ViewBuilder
    private func detokenizeModeView(_ model: GenerationFeatureModel) -> some View {
        TextField("Model (optional)", text: Binding(
            get: { model.detokModel },
            set: { model.detokModel = $0 }
        ))
        .textFieldStyle(.roundedBorder)

        Text("Token IDs (JSON array of integers)")
            .font(.caption)
            .foregroundStyle(.secondary)
        TextEditor(text: Binding(
            get: { model.detokIds },
            set: { model.detokIds = $0 }
        ))
        .font(.system(.body, design: .monospaced))
        .frame(minHeight: 80)
        .overlay(RoundedRectangle(cornerRadius: StrataRadius.md).stroke(.separator))

        Button("Detokenize") {
            Task { await model.runDetokenize() }
        }
        .disabled(model.detokIds.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        if let error = model.detokError {
            Text(error).foregroundStyle(.red).font(.callout)
        }

        if let result = model.detokResult {
            GroupBox("Decoded Text") {
                Text(result)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Unload Mode

    @ViewBuilder
    private func unloadModeView(_ model: GenerationFeatureModel) -> some View {
        Text("Unload a loaded generation model from memory.")
            .strataSecondaryStyle()

        TextField("Model name", text: Binding(
            get: { model.unloadModel },
            set: { model.unloadModel = $0 }
        ))
        .textFieldStyle(.roundedBorder)

        Button("Unload Model") {
            Task { await model.runUnload() }
        }
        .disabled(model.unloadModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        if let error = model.unloadError {
            Text(error).foregroundStyle(.red).font(.callout)
        }
        if let result = model.unloadResult {
            Text(result).foregroundStyle(.green).font(.callout)
        }
    }
}
