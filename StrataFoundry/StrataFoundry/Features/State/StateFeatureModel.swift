import Foundation

struct StateCellDisplay: Identifiable, Hashable {
    let id: String
    let name: String
    let displayValue: String
    let typeTag: String
    let version: UInt64
    let rawValue: StrataValue
}

@Observable
final class StateFeatureModel {
    private let stateService: StateService
    private let appState: AppState

    var cells: [StateCellDisplay] = []
    var isLoading = false
    var errorMessage: String?
    var selectedCellId: StateCellDisplay.ID?
    var showInspector = false
    var sortOrder: [KeyPathComparator<StateCellDisplay>] = [.init(\.name, order: .forward)]

    var selectedCell: StateCellDisplay? {
        get { cells.first(where: { $0.id == selectedCellId }) }
        set { selectedCellId = newValue?.id }
    }

    // Form
    var formCell = ""
    var formValue = ""
    var formValueType = "String"

    // Sheets
    var showAddSheet = false
    var editingCell: StateCellDisplay?
    var showDeleteConfirm = false
    var cellToDelete: StateCellDisplay?
    var historyCell: StateCellDisplay?
    var showBatchSheet = false

    var isTimeTraveling: Bool { appState.timeTravelDate != nil }

    var sortedCells: [StateCellDisplay] {
        cells.sorted(using: sortOrder)
    }

    init(stateService: StateService, appState: AppState) {
        self.stateService = stateService
        self.appState = appState
    }

    func loadCells() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let branch = appState.selectedBranch
        let space: String? = appState.selectedSpace == "default" ? nil : appState.selectedSpace
        let asOf = asOfFromDate(appState.timeTravelDate)

        do {
            let names = try await stateService.list(branch: branch, space: space, asOf: asOf)
            var newCells: [StateCellDisplay] = []
            for name in names {
                if let vv = try await stateService.get(cell: name, branch: branch, space: space, asOf: asOf) {
                    newCells.append(StateCellDisplay(
                        id: name, name: name,
                        displayValue: vv.value.displayString,
                        typeTag: vv.value.typeTag,
                        version: vv.version,
                        rawValue: vv.value
                    ))
                }
            }
            cells = newCells
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setCell() async {
        guard let value = StrataValue.fromUserInput(formValue, type: formValueType) else {
            errorMessage = "Invalid value for type \(formValueType)"
            return
        }
        let branch = appState.selectedBranch
        let space: String? = appState.selectedSpace == "default" ? nil : appState.selectedSpace

        do {
            _ = try await stateService.set(cell: formCell, value: value, branch: branch, space: space)
            showAddSheet = false
            editingCell = nil
            clearForm()
            await loadCells()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteCell(_ name: String) async {
        let branch = appState.selectedBranch
        let space: String? = appState.selectedSpace == "default" ? nil : appState.selectedSpace

        do {
            _ = try await stateService.delete(cell: name, branch: branch, space: space)
            if selectedCell?.name == name { selectedCell = nil }
            cellToDelete = nil
            await loadCells()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func batchImport(jsonText: String) async -> BatchImportOutcome {
        guard let data = jsonText.data(using: .utf8),
              let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return .failure("Invalid JSON: expected an array of {\"cell\": \"...\", \"value\": {...}} objects")
        }

        var batchEntries: [BatchStateEntry] = []
        for item in items {
            guard let cell = item["cell"] as? String,
                  let valueObj = item["value"] else {
                return .failure("Each item must have \"cell\" and \"value\" fields")
            }
            let value = StrataValue.fromJSONObject(valueObj)
            batchEntries.append(BatchStateEntry(cell: cell, value: value))
        }

        let branch = appState.selectedBranch
        let space: String? = appState.selectedSpace == "default" ? nil : appState.selectedSpace

        do {
            _ = try await stateService.batchSet(entries: batchEntries, branch: branch, space: space)
            await loadCells()
            return .success("Imported \(batchEntries.count) cells.")
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    func clearForm() {
        formCell = ""
        formValue = ""
        formValueType = "String"
    }

    func prepareEditForm(for cell: StateCellDisplay) {
        formCell = cell.name
        formValue = cell.displayValue
        formValueType = cell.typeTag
        if cell.typeTag == "String" {
            formValue = cell.rawValue.displayString
        }
    }
}
