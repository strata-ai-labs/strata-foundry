import Foundation

enum GenerationPaneMode: String, CaseIterable {
    case generate = "Generate"
    case tokenize = "Tokenize"
    case detokenize = "Detokenize"
    case unload = "Unload"
}

@Observable
final class GenerationFeatureModel {
    private let generationService: GenerationService
    private let appState: AppState

    var generationMode: GenerationPaneMode = .generate

    // Generate
    var genModel = ""
    var genPrompt = ""
    var genMaxTokens = "256"
    var genTemperature = "0.7"
    var genTopK = ""
    var genTopP = ""
    var genSeed = ""
    var genResult: String?
    var genMeta: String?
    var genError: String?
    var isGenerating = false

    // Tokenize
    var tokModel = ""
    var tokText = ""
    var tokResult: String?
    var tokError: String?

    // Detokenize
    var detokModel = ""
    var detokIds = ""
    var detokResult: String?
    var detokError: String?

    // Unload
    var unloadModel = ""
    var unloadResult: String?
    var unloadError: String?

    init(generationService: GenerationService, appState: AppState) {
        self.generationService = generationService
        self.appState = appState
    }

    func runGenerate() async {
        genResult = nil
        genMeta = nil
        genError = nil
        isGenerating = true
        defer { isGenerating = false }

        do {
            let result = try await generationService.generate(
                model: genModel,
                prompt: genPrompt,
                maxTokens: Int(genMaxTokens),
                temperature: Float(genTemperature),
                topK: Int(genTopK),
                topP: Float(genTopP),
                seed: UInt64(genSeed)
            )
            genResult = result.text
            genMeta = "Model: \(result.model) | Stop: \(result.stopReason) | Prompt tokens: \(result.promptTokens) | Completion tokens: \(result.completionTokens)"
        } catch {
            genError = error.localizedDescription
        }
    }

    func runTokenize() async {
        tokResult = nil
        tokError = nil
        do {
            let result = try await generationService.tokenize(
                model: tokModel,
                text: tokText
            )
            let idsStr = result.ids.map { "\($0)" }.joined(separator: ", ")
            tokResult = "[\(idsStr)]\n\nCount: \(result.count)\(result.model.isEmpty ? "" : " | Model: \(result.model)")"
        } catch {
            tokError = error.localizedDescription
        }
    }

    func runDetokenize() async {
        detokResult = nil
        detokError = nil
        guard let data = detokIds.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [Any] else {
            detokError = "Invalid token IDs: must be a JSON array of integers"
            return
        }
        let ids = arr.compactMap { elem -> UInt32? in
            if let n = elem as? NSNumber { return UInt32(n.intValue) }
            return nil
        }
        guard ids.count == arr.count else {
            detokError = "Token IDs must all be integers"
            return
        }
        do {
            let text = try await generationService.detokenize(
                model: detokModel,
                ids: ids
            )
            detokResult = text
        } catch {
            detokError = error.localizedDescription
        }
    }

    func runUnload() async {
        unloadResult = nil
        unloadError = nil
        do {
            let success = try await generationService.unload(model: unloadModel)
            unloadResult = success ? "Model \"\(unloadModel)\" unloaded." : "Model was not loaded."
        } catch {
            unloadError = error.localizedDescription
        }
    }

    func resetState() {
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
