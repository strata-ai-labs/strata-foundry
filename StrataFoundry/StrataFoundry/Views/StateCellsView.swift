//
//  StateCellsView.swift
//  StrataFoundry
//

import SwiftUI

struct StateCellEntry: Identifiable, Hashable {
    let id: String
    let name: String
    let value: String
    let valueType: String
    let version: UInt64
}

struct StateCellsView: View {
    @Environment(AppState.self) private var appState
    @State private var cells: [StateCellEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedCell: StateCellEntry?

    // Write-related state
    @State private var showAddSheet = false
    @State private var editingCell: StateCellEntry?
    @State private var showDeleteConfirm = false
    @State private var cellToDelete: StateCellEntry?
    @State private var historyCell: StateCellEntry?
    @State private var showBatchSheet = false
    @State private var batchJSON = ""
    @State private var batchError: String?
    @State private var batchSuccess: String?

    // Form fields
    @State private var formCell = ""
    @State private var formValue = ""
    @State private var formValueType = "String"

    private var isTimeTraveling: Bool { appState.timeTravelDate != nil }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("State Cells")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(cells.count) cells")
                    .foregroundStyle(.secondary)
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Add Cell")
                .disabled(isTimeTraveling)
                Button {
                    batchJSON = ""
                    batchError = nil
                    batchSuccess = nil
                    showBatchSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.down.on.square")
                }
                .help("Batch Import")
                .disabled(isTimeTraveling)
                Button {
                    if let cell = selectedCell {
                        cellToDelete = cell
                        showDeleteConfirm = true
                    }
                } label: {
                    Image(systemName: "trash")
                }
                .help("Delete Cell")
                .disabled(isTimeTraveling || selectedCell == nil)
                Button {
                    Task { await loadCells() }
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
                ProgressView("Loading state cells...")
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                Text(error).foregroundStyle(.red)
                Spacer()
            } else if cells.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "memorychip")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No state cells")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                List(cells, selection: $selectedCell) { cell in
                    HStack(spacing: 12) {
                        Text(cell.name)
                            .font(.system(.body, design: .monospaced))
                            .frame(minWidth: 180, alignment: .leading)
                        Text(cell.value)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                        Text(cell.valueType)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        Text("v\(cell.version)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .tag(cell)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedCell = cell
                    }
                    .contextMenu {
                        Button("Edit") {
                            editingCell = cell
                        }
                        .disabled(isTimeTraveling)
                        Button("Version History") {
                            historyCell = cell
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            cellToDelete = cell
                            showDeleteConfirm = true
                        }
                        .disabled(isTimeTraveling)
                    }
                }
            }
        }
        .task(id: appState.reloadToken) {
            await loadCells()
        }
        .sheet(item: $historyCell) { cell in
            VersionHistoryView(primitive: "State", key: cell.name)
                .environment(appState)
                .frame(minWidth: 400, minHeight: 300)
        }
        .sheet(isPresented: $showAddSheet, onDismiss: clearForm) {
            cellFormSheet(isEditing: false)
        }
        .sheet(item: $editingCell, onDismiss: clearForm) { cell in
            cellFormSheet(isEditing: true)
                .onAppear {
                    formCell = cell.name
                    formValue = cell.value
                    formValueType = cell.valueType == "?" ? "String" : cell.valueType
                    if cell.valueType == "String" && formValue.hasPrefix("\"") && formValue.hasSuffix("\"") {
                        formValue = String(formValue.dropFirst().dropLast())
                    }
                }
        }
        .sheet(isPresented: $showBatchSheet) {
            VStack(spacing: 16) {
                Text("Batch Import (StateBatchSet)")
                    .font(.headline)
                Text("JSON array of {\"cell\": \"...\", \"value\": {...}} objects")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $batchJSON)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 150)
                    .border(Color.secondary.opacity(0.3))
                if let err = batchError {
                    Text(err)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
                if let success = batchSuccess {
                    Text(success)
                        .foregroundStyle(.green)
                        .font(.caption)
                }
                HStack {
                    Button("Cancel") {
                        showBatchSheet = false
                    }
                    .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Import") {
                        Task { await batchSet() }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(batchJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(20)
            .frame(minWidth: 450, minHeight: 300)
        }
        .alert("Delete Cell", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { cellToDelete = nil }
            Button("Delete", role: .destructive) {
                if let cell = cellToDelete {
                    Task { await deleteCell(cell.name) }
                    cellToDelete = nil
                }
            }
        } message: {
            if let cell = cellToDelete {
                Text("Delete cell \"\(cell.name)\"? This cannot be undone.")
            }
        }
    }

    @ViewBuilder
    private func cellFormSheet(isEditing: Bool) -> some View {
        VStack(spacing: 16) {
            Text(isEditing ? "Edit Cell" : "Add Cell")
                .font(.headline)

            TextField("Cell Name", text: $formCell)
                .textFieldStyle(.roundedBorder)
                .disabled(isEditing)

            Picker("Value Type", selection: $formValueType) {
                Text("String").tag("String")
                Text("Int").tag("Int")
                Text("Float").tag("Float")
                Text("Bool").tag("Bool")
                Text("JSON").tag("JSON")
            }
            .pickerStyle(.segmented)

            if formValueType == "JSON" {
                TextEditor(text: $formValue)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 100)
                    .border(Color.secondary.opacity(0.3))
            } else if formValueType == "Bool" {
                Picker("Value", selection: $formValue) {
                    Text("true").tag("true")
                    Text("false").tag("false")
                }
                .pickerStyle(.segmented)
                .onAppear {
                    if formValue != "true" && formValue != "false" {
                        formValue = "true"
                    }
                }
            } else {
                TextField("Value", text: $formValue)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button("Cancel") {
                    showAddSheet = false
                    editingCell = nil
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button(isEditing ? "Save" : "Add") {
                    Task {
                        let valueJSON = buildStrataValue(formValue, type: formValueType)
                        await setCell(name: formCell, valueJSON: valueJSON)
                        showAddSheet = false
                        editingCell = nil
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(formCell.isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 350)
    }

    private func clearForm() {
        formCell = ""
        formValue = ""
        formValueType = "String"
    }

    // MARK: - Write Operations

    private func setCell(name: String, valueJSON: Any) async {
        guard let client = appState.client else { return }
        do {
            var cmd: [String: Any] = [
                "cell": name,
                "value": valueJSON,
                "branch": appState.selectedBranch
            ]
            if appState.selectedSpace != "default" {
                cmd["space"] = appState.selectedSpace
            }
            let wrapper: [String: Any] = ["StateSet": cmd]
            let data = try JSONSerialization.data(withJSONObject: wrapper)
            let jsonStr = String(data: data, encoding: .utf8)!
            _ = try await client.executeRaw(jsonStr)
            await loadCells()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteCell(_ name: String) async {
        guard let client = appState.client else { return }
        do {
            var cmd: [String: Any] = [
                "cell": name,
                "branch": appState.selectedBranch
            ]
            if appState.selectedSpace != "default" {
                cmd["space"] = appState.selectedSpace
            }
            let wrapper: [String: Any] = ["StateDelete": cmd]
            let data = try JSONSerialization.data(withJSONObject: wrapper)
            let jsonStr = String(data: data, encoding: .utf8)!
            _ = try await client.executeRaw(jsonStr)
            if selectedCell?.name == name { selectedCell = nil }
            await loadCells()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func batchSet() async {
        guard let client = appState.client else { return }
        batchError = nil
        batchSuccess = nil
        do {
            guard let data = batchJSON.data(using: .utf8),
                  let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                batchError = "Invalid JSON: expected an array of {\"cell\": \"...\", \"value\": {...}} objects"
                return
            }
            var cmd: [String: Any] = [
                "items": items,
                "branch": appState.selectedBranch
            ]
            if appState.selectedSpace != "default" {
                cmd["space"] = appState.selectedSpace
            }
            let wrapper: [String: Any] = ["StateBatchSet": cmd]
            let wrapperData = try JSONSerialization.data(withJSONObject: wrapper)
            let jsonStr = String(data: wrapperData, encoding: .utf8)!
            _ = try await client.executeRaw(jsonStr)
            batchSuccess = "Imported \(items.count) cells."
            await loadCells()
        } catch {
            batchError = error.localizedDescription
        }
    }

    // MARK: - Load

    private func loadCells() async {
        guard let client = appState.client else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let listJSON = try await client.executeRaw("{\"StateList\": {\"branch\": \"\(appState.selectedBranch)\"\(appState.spaceFragment())\(appState.asOfFragment())}}")
            guard let data = listJSON.data(using: .utf8),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let keys = root["Keys"] as? [String] else {
                cells = []
                return
            }

            var newCells: [StateCellEntry] = []
            for name in keys {
                var getCmd: [String: Any] = [
                    "cell": name,
                    "branch": appState.selectedBranch
                ]
                if appState.selectedSpace != "default" {
                    getCmd["space"] = appState.selectedSpace
                }
                if let date = appState.timeTravelDate {
                    getCmd["as_of"] = Int64(date.timeIntervalSince1970 * 1_000_000)
                }
                let wrapper = ["StateGet": getCmd]
                let cmdData = try JSONSerialization.data(withJSONObject: wrapper)
                let cmd = String(data: cmdData, encoding: .utf8)!
                let getJSON = try await client.executeRaw(cmd)
                if let d = getJSON.data(using: .utf8),
                   let r = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                   let v = r["MaybeVersioned"] as? [String: Any] {
                    let ver = v["version"] as? UInt64 ?? 0
                    let (display, vType) = formatValue(v["value"])
                    newCells.append(StateCellEntry(
                        id: name, name: name, value: display,
                        valueType: vType, version: ver
                    ))
                }
            }
            cells = newCells
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func formatValue(_ value: Any?) -> (String, String) {
        guard let value else { return ("null", "Null") }
        if let str = value as? String { return (str, "Null") }
        if let dict = value as? [String: Any], let (tag, inner) = dict.first {
            switch tag {
            case "String": return ("\"\(inner)\"", "String")
            case "Int", "Float", "Bool": return ("\(inner)", tag)
            case "Array":
                if let arr = inner as? [Any] { return ("[\(arr.count) items]", "Array") }
                return ("\(inner)", "Array")
            case "Object":
                if let obj = inner as? [String: Any] { return ("{\(obj.count) keys}", "Object") }
                return ("\(inner)", "Object")
            default: return ("\(inner)", tag)
            }
        }
        return ("\(value)", "?")
    }
}
