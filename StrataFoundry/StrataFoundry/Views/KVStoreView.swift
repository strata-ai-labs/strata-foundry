//
//  KVStoreView.swift
//  StrataFoundry
//

import SwiftUI

struct KVEntry: Identifiable, Hashable {
    let id: String
    let key: String
    let value: String
    let valueType: String
    let version: UInt64
}

struct KVStoreView: View {
    @Environment(AppState.self) private var appState
    @State private var entries: [KVEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var filterText = ""
    @State private var selectedEntry: KVEntry?

    // Write-related state
    @State private var showAddSheet = false
    @State private var editingEntry: KVEntry?
    @State private var showDeleteConfirm = false
    @State private var entryToDelete: KVEntry?
    @State private var historyEntry: KVEntry?

    // Form fields
    @State private var formKey = ""
    @State private var formValue = ""
    @State private var formValueType = "String"

    private var isTimeTraveling: Bool { appState.timeTravelDate != nil }

    private var filteredEntries: [KVEntry] {
        if filterText.isEmpty { return entries }
        return entries.filter { $0.key.localizedCaseInsensitiveContains(filterText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("KV Store")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(filteredEntries.count) keys")
                    .foregroundStyle(.secondary)
                TextField("Filter...", text: $filterText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Add Key")
                .disabled(isTimeTraveling)
                Button {
                    if let entry = selectedEntry {
                        entryToDelete = entry
                        showDeleteConfirm = true
                    }
                } label: {
                    Image(systemName: "trash")
                }
                .help("Delete Key")
                .disabled(isTimeTraveling || selectedEntry == nil)
                Button {
                    Task { await loadEntries() }
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
                ProgressView("Loading keys...")
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                Text(error).foregroundStyle(.red).padding()
                Spacer()
            } else if entries.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No keys in KV store")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                List(filteredEntries, selection: $selectedEntry) { entry in
                    HStack(spacing: 12) {
                        Text(entry.key)
                            .font(.system(.body, design: .monospaced))
                            .frame(minWidth: 180, alignment: .leading)
                        Text(entry.value)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                        Text(entry.valueType)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        Text("v\(entry.version)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .tag(entry)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedEntry = entry
                    }
                    .contextMenu {
                        Button("Edit") {
                            editingEntry = entry
                        }
                        .disabled(isTimeTraveling)
                        Button("Version History") {
                            historyEntry = entry
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            entryToDelete = entry
                            showDeleteConfirm = true
                        }
                        .disabled(isTimeTraveling)
                    }
                }
            }
        }
        .task(id: appState.reloadToken) {
            await loadEntries()
        }
        .sheet(item: $historyEntry) { entry in
            VersionHistoryView(primitive: "Kv", key: entry.key)
                .environment(appState)
                .frame(minWidth: 400, minHeight: 300)
        }
        .sheet(isPresented: $showAddSheet, onDismiss: clearForm) {
            kvFormSheet(isEditing: false)
        }
        .sheet(item: $editingEntry, onDismiss: clearForm) { entry in
            kvFormSheet(isEditing: true)
                .onAppear {
                    formKey = entry.key
                    formValue = entry.value
                    formValueType = entry.valueType == "?" ? "String" : entry.valueType
                    // Strip surrounding quotes for String values
                    if entry.valueType == "String" && formValue.hasPrefix("\"") && formValue.hasSuffix("\"") {
                        formValue = String(formValue.dropFirst().dropLast())
                    }
                }
        }
        .alert("Delete Key", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { entryToDelete = nil }
            Button("Delete", role: .destructive) {
                if let entry = entryToDelete {
                    Task { await deleteKey(entry.key) }
                    entryToDelete = nil
                }
            }
        } message: {
            if let entry = entryToDelete {
                Text("Delete key \"\(entry.key)\"? This cannot be undone.")
            }
        }
    }

    @ViewBuilder
    private func kvFormSheet(isEditing: Bool) -> some View {
        VStack(spacing: 16) {
            Text(isEditing ? "Edit Key" : "Add Key")
                .font(.headline)

            TextField("Key", text: $formKey)
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
                    editingEntry = nil
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button(isEditing ? "Save" : "Add") {
                    Task {
                        let valueJSON = buildStrataValue(formValue, type: formValueType)
                        await putKey(key: formKey, valueJSON: valueJSON)
                        showAddSheet = false
                        editingEntry = nil
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(formKey.isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 350)
    }

    private func clearForm() {
        formKey = ""
        formValue = ""
        formValueType = "String"
    }

    // MARK: - Write Operations

    private func putKey(key: String, valueJSON: Any) async {
        guard let client = appState.client else { return }
        do {
            var cmd: [String: Any] = [
                "key": key,
                "value": valueJSON,
                "branch": appState.selectedBranch
            ]
            if appState.selectedSpace != "default" {
                cmd["space"] = appState.selectedSpace
            }
            let wrapper: [String: Any] = ["KvPut": cmd]
            let data = try JSONSerialization.data(withJSONObject: wrapper)
            let jsonStr = String(data: data, encoding: .utf8)!
            _ = try await client.executeRaw(jsonStr)
            await loadEntries()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteKey(_ key: String) async {
        guard let client = appState.client else { return }
        do {
            var cmd: [String: Any] = [
                "key": key,
                "branch": appState.selectedBranch
            ]
            if appState.selectedSpace != "default" {
                cmd["space"] = appState.selectedSpace
            }
            let wrapper: [String: Any] = ["KvDelete": cmd]
            let data = try JSONSerialization.data(withJSONObject: wrapper)
            let jsonStr = String(data: data, encoding: .utf8)!
            _ = try await client.executeRaw(jsonStr)
            if selectedEntry?.key == key { selectedEntry = nil }
            await loadEntries()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Load

    private func loadEntries() async {
        guard let client = appState.client else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let listJSON = try await client.executeRaw("{\"KvList\": {\"branch\": \"\(appState.selectedBranch)\"\(appState.spaceFragment())\(appState.asOfFragment())}}")
            guard let data = listJSON.data(using: .utf8),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let keys = root["Keys"] as? [String] else {
                entries = []
                return
            }

            var newEntries: [KVEntry] = []
            for key in keys {
                let cmd = "{\"KvGet\": {\"key\": \"\(key)\", \"branch\": \"\(appState.selectedBranch)\"\(appState.spaceFragment())\(appState.asOfFragment())}}"
                let getJSON = try await client.executeRaw(cmd)
                if let d = getJSON.data(using: .utf8),
                   let r = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                   let v = r["MaybeVersioned"] as? [String: Any] {
                    let ver = v["version"] as? UInt64 ?? 0
                    let (display, vType) = formatStrataValue(v["value"])
                    newEntries.append(KVEntry(id: key, key: key, value: display, valueType: vType, version: ver))
                }
            }
            entries = newEntries
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func formatStrataValue(_ value: Any?) -> (String, String) {
        guard let value else { return ("null", "Null") }
        if let str = value as? String { return (str, "Null") }
        if let dict = value as? [String: Any], let (tag, inner) = dict.first {
            switch tag {
            case "String": return ("\"\(inner)\"", "String")
            case "Int": return ("\(inner)", "Int")
            case "Float": return ("\(inner)", "Float")
            case "Bool": return ("\(inner)", "Bool")
            case "Bytes":
                if let arr = inner as? [Any] { return ("[\(arr.count) bytes]", "Bytes") }
                return ("\(inner)", "Bytes")
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

/// Build a Strata tagged value from user input.
func buildStrataValue(_ input: String, type: String) -> Any {
    switch type {
    case "String":
        return ["String": input]
    case "Int":
        if let n = Int(input) { return ["Int": n] }
        return ["String": input]
    case "Float":
        if let f = Double(input) { return ["Float": f] }
        return ["String": input]
    case "Bool":
        return ["Bool": input.lowercased() == "true"]
    case "JSON":
        // Try to parse as JSON; if it already looks like a Strata value, use as-is
        if let data = input.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) {
            return obj
        }
        // Fallback: wrap as string
        return ["String": input]
    default:
        return ["String": input]
    }
}
