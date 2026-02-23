import Foundation

struct ModelDisplay: Identifiable {
    var id: String { name }
    let name: String
    let task: String
    let architecture: String
    let defaultQuant: String
    let embeddingDim: Int
    let isLocal: Bool
    let sizeBytes: Int
}

enum ModelsPaneMode: String, CaseIterable {
    case embed = "Embed"
    case configure = "Configure"
    case status = "Status"
}

@Observable
final class ModelsFeatureModel {
    private let modelService: ModelService
    private let searchService: SearchService
    private let appState: AppState

    var registryModels: [ModelDisplay] = []
    var localModels: [ModelDisplay] = []
    var selectedModel: String?
    var isLoading = false
    var errorMessage: String?
    var modelsMode: ModelsPaneMode = .embed

    // Pull
    var pullMessage: String?
    var isPulling = false

    // Embed
    var embedText = ""
    var embedResult: String?
    var embedError: String?
    var embedBatchText = ""
    var embedBatchResult: String?
    var embedBatchError: String?

    // Configure
    var configEndpoint = ""
    var configModel = ""
    var configApiKey = ""
    var configTimeout = ""
    var configMessage: String?
    var configError: String?

    // Status
    var embedStatus: String?
    var embedStatusError: String?

    init(modelService: ModelService, searchService: SearchService, appState: AppState) {
        self.modelService = modelService
        self.searchService = searchService
        self.appState = appState
    }

    func loadModels() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let registry = try await modelService.listRegistry()
            registryModels = registry.map { toDisplay($0) }

            let local = try await modelService.listLocal()
            localModels = local.map { toDisplay($0) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toDisplay(_ m: ModelInfoOutput) -> ModelDisplay {
        ModelDisplay(
            name: m.name,
            task: m.task,
            architecture: m.architecture,
            defaultQuant: m.defaultQuant,
            embeddingDim: m.embeddingDim,
            isLocal: m.isLocal,
            sizeBytes: Int(m.sizeBytes)
        )
    }

    func pullModel(_ name: String) async {
        isPulling = true
        pullMessage = nil
        defer { isPulling = false }

        do {
            let info = try await modelService.pull(name: name)
            pullMessage = "Pulled \(name) to \(info.path)"
            await loadModels()
        } catch {
            pullMessage = "Pull failed: \(error.localizedDescription)"
        }
    }

    func runEmbed() async {
        embedResult = nil
        embedError = nil
        do {
            let embedding = try await modelService.embed(text: embedText)
            let vals = embedding.prefix(20).map { String(format: "%.6f", $0) }.joined(separator: ", ")
            let suffix = embedding.count > 20 ? ", ... (\(embedding.count) dims)" : ""
            embedResult = "[\(vals)\(suffix)]"
        } catch {
            embedError = error.localizedDescription
        }
    }

    func runEmbedBatch() async {
        embedBatchResult = nil
        embedBatchError = nil
        do {
            let texts = embedBatchText.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            let embeddings = try await modelService.embedBatch(texts: texts)
            embedBatchResult = "\(embeddings.count) embeddings generated (dim=\(embeddings.first?.count ?? 0))"
        } catch {
            embedBatchError = error.localizedDescription
        }
    }

    func configureModel() async {
        configMessage = nil
        configError = nil
        do {
            let timeout: UInt64? = UInt64(configTimeout)
            try await searchService.configureModel(
                endpoint: configEndpoint,
                model: configModel,
                apiKey: configApiKey.isEmpty ? nil : configApiKey,
                timeoutMs: timeout
            )
            configMessage = "Configuration applied."
        } catch {
            configError = error.localizedDescription
        }
    }

    func loadEmbedStatus() async {
        embedStatus = nil
        embedStatusError = nil
        do {
            let status = try await modelService.embedStatus()
            // Pretty-print the status by encoding and re-formatting
            let data = try JSONEncoder.strataEncoder.encode(status)
            if let obj = try? JSONSerialization.jsonObject(with: data),
               let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let str = String(data: pretty, encoding: .utf8) {
                embedStatus = str
            } else {
                embedStatus = String(data: data, encoding: .utf8)
            }
        } catch {
            embedStatusError = error.localizedDescription
        }
    }
}
