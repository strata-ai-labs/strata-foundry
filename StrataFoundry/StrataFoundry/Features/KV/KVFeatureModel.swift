import Foundation

/// Display-ready KV entry for the list.
struct KVEntryDisplay: Identifiable, Hashable {
    let id: String
    let key: String
    let displayValue: String
    let typeTag: String
    let version: UInt64

    /// The raw StrataValue for editing
    let rawValue: StrataValue
}

@Observable
final class KVFeatureModel {
    private let kvService: KVService
    private let appState: AppState

    // List state
    var entries: [KVEntryDisplay] = []
    var isLoading = false
    var errorMessage: String?
    var filterText = ""
    var selectedEntry: KVEntryDisplay?

    // Form state
    var formKey = ""
    var formValue = ""
    var formValueType = "String"

    // Sheet state
    var showAddSheet = false
    var editingEntry: KVEntryDisplay?
    var showDeleteConfirm = false
    var entryToDelete: KVEntryDisplay?
    var historyEntry: KVEntryDisplay?
    var showBatchSheet = false

    var isTimeTraveling: Bool { appState.timeTravelDate != nil }

    var filteredEntries: [KVEntryDisplay] {
        if filterText.isEmpty { return entries }
        return entries.filter { $0.key.localizedCaseInsensitiveContains(filterText) }
    }

    init(kvService: KVService, appState: AppState) {
        self.kvService = kvService
        self.appState = appState
    }

    // MARK: - Load

    func loadEntries() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let branch = appState.selectedBranch
        let space: String? = appState.selectedSpace == "default" ? nil : appState.selectedSpace
        let asOf = asOfFromDate(appState.timeTravelDate)

        do {
            let keys = try await kvService.list(branch: branch, space: space, asOf: asOf)
            var newEntries: [KVEntryDisplay] = []
            for key in keys {
                if let vv = try await kvService.get(key: key, branch: branch, space: space, asOf: asOf) {
                    newEntries.append(KVEntryDisplay(
                        id: key,
                        key: key,
                        displayValue: vv.value.displayString,
                        typeTag: vv.value.typeTag,
                        version: vv.version,
                        rawValue: vv.value
                    ))
                }
            }
            entries = newEntries
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Write Operations

    func putKey() async {
        guard let value = StrataValue.fromUserInput(formValue, type: formValueType) else {
            errorMessage = "Invalid value for type \(formValueType)"
            return
        }

        let branch = appState.selectedBranch
        let space: String? = appState.selectedSpace == "default" ? nil : appState.selectedSpace

        do {
            _ = try await kvService.put(key: formKey, value: value, branch: branch, space: space)
            showAddSheet = false
            editingEntry = nil
            clearForm()
            await loadEntries()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteKey(_ key: String) async {
        let branch = appState.selectedBranch
        let space: String? = appState.selectedSpace == "default" ? nil : appState.selectedSpace

        do {
            _ = try await kvService.delete(key: key, branch: branch, space: space)
            if selectedEntry?.key == key { selectedEntry = nil }
            entryToDelete = nil
            await loadEntries()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func batchImport(jsonText: String) async -> BatchImportOutcome {
        guard let data = jsonText.data(using: .utf8),
              let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return .failure("Invalid JSON: expected an array of {\"key\": \"...\", \"value\": {...}} objects")
        }

        // Convert untyped items to BatchKvEntry
        var batchEntries: [BatchKvEntry] = []
        for item in items {
            guard let key = item["key"] as? String,
                  let valueObj = item["value"] else {
                return .failure("Each item must have \"key\" and \"value\" fields")
            }
            let value = StrataValue.fromJSONObject(valueObj)
            batchEntries.append(BatchKvEntry(key: key, value: value))
        }

        let branch = appState.selectedBranch
        let space: String? = appState.selectedSpace == "default" ? nil : appState.selectedSpace

        do {
            _ = try await kvService.batchPut(entries: batchEntries, branch: branch, space: space)
            await loadEntries()
            return .success("Imported \(batchEntries.count) keys.")
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    // MARK: - Form Helpers

    func clearForm() {
        formKey = ""
        formValue = ""
        formValueType = "String"
    }

    func prepareEditForm(for entry: KVEntryDisplay) {
        formKey = entry.key
        formValue = entry.displayValue
        formValueType = entry.typeTag
        // Strip quotes for String values
        if entry.typeTag == "String" {
            formValue = entry.rawValue.displayString
        }
    }
}
