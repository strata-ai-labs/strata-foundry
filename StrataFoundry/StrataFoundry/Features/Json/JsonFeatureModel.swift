import Foundation

@Observable
final class JsonFeatureModel {
    private let jsonService: JsonService
    private let appState: AppState

    var keys: [String] = []
    var selectedKey: String?
    var documentJSON: String = ""
    var isLoading = false
    var errorMessage: String?
    var showHistory = false

    // Write state
    var showAddSheet = false
    var showEditSheet = false
    var showDeleteConfirm = false
    var formKey = ""
    var formJSON = ""
    var showBatchSheet = false

    var isTimeTraveling: Bool { appState.timeTravelDate != nil }

    init(jsonService: JsonService, appState: AppState) {
        self.jsonService = jsonService
        self.appState = appState
    }

    func loadKeys() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let branch = appState.selectedBranch
        let space: String? = appState.selectedSpace == "default" ? nil : appState.selectedSpace
        let asOf = asOfFromDate(appState.timeTravelDate)

        do {
            let result = try await jsonService.list(branch: branch, space: space, limit: 1000, asOf: asOf)
            keys = result.keys
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadDocument(key: String) async {
        let branch = appState.selectedBranch
        let space: String? = appState.selectedSpace == "default" ? nil : appState.selectedSpace
        let asOf = asOfFromDate(appState.timeTravelDate)

        do {
            if let vv = try await jsonService.get(key: key, branch: branch, space: space, asOf: asOf) {
                documentJSON = vv.value.prettyJSON
            } else {
                documentJSON = ""
            }
        } catch {
            documentJSON = "Error: \(error.localizedDescription)"
        }
    }

    func setDocument() async {
        guard let value = StrataValue.fromJSONString(formJSON) ?? (formJSON.isEmpty ? nil : .some(.string(formJSON))) else {
            errorMessage = "Invalid JSON"
            return
        }

        let branch = appState.selectedBranch
        let space: String? = appState.selectedSpace == "default" ? nil : appState.selectedSpace

        do {
            _ = try await jsonService.set(key: formKey, value: value, branch: branch, space: space)
            showAddSheet = false
            showEditSheet = false
            await loadKeys()
            if selectedKey == formKey {
                await loadDocument(key: formKey)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteDocument(_ key: String) async {
        let branch = appState.selectedBranch
        let space: String? = appState.selectedSpace == "default" ? nil : appState.selectedSpace

        do {
            _ = try await jsonService.delete(key: key, branch: branch, space: space)
            if selectedKey == key {
                selectedKey = nil
                documentJSON = ""
            }
            await loadKeys()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func batchImport(jsonText: String) async -> Result<String, String> {
        guard let data = jsonText.data(using: .utf8),
              let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return .failure("Invalid JSON: expected an array of {\"key\": \"...\", \"path\": \"$\", \"value\": {...}} objects")
        }

        var batchEntries: [BatchJsonEntry] = []
        for item in items {
            guard let key = item["key"] as? String,
                  let valueObj = item["value"] else {
                return .failure("Each item must have \"key\" and \"value\" fields")
            }
            let path = item["path"] as? String ?? "$"
            let value = StrataValue.fromJSONObject(valueObj)
            batchEntries.append(BatchJsonEntry(key: key, path: path, value: value))
        }

        let branch = appState.selectedBranch
        let space: String? = appState.selectedSpace == "default" ? nil : appState.selectedSpace

        do {
            _ = try await jsonService.batchSet(entries: batchEntries, branch: branch, space: space)
            await loadKeys()
            return .success("Imported \(batchEntries.count) documents.")
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    func onSelectKey(_ key: String?) {
        showHistory = false
        selectedKey = key
        if let key {
            Task { await loadDocument(key: key) }
        }
    }

    func prepareEditForm() {
        formKey = selectedKey ?? ""
        formJSON = documentJSON
    }

    func prepareAddForm() {
        formKey = ""
        formJSON = ""
    }
}
