//
//  JsonStoreView.swift
//  StrataFoundry
//

import SwiftUI

struct JsonStoreView: View {
    @Environment(AppState.self) private var appState
    @State private var keys: [String] = []
    @State private var selectedKey: String?
    @State private var documentJSON: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showHistory = false

    // Write-related state
    @State private var showAddSheet = false
    @State private var showEditSheet = false
    @State private var showDeleteConfirm = false
    @State private var formKey = ""
    @State private var formJSON = ""

    private var isTimeTraveling: Bool { appState.timeTravelDate != nil }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("JSON Store")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(keys.count) documents")
                    .foregroundStyle(.secondary)
                Button {
                    formKey = ""
                    formJSON = ""
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Add Document")
                .disabled(isTimeTraveling)
                Button {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                }
                .help("Delete Document")
                .disabled(isTimeTraveling || selectedKey == nil)
                Button {
                    Task { await loadKeys() }
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
                ProgressView("Loading...")
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                Text(error).foregroundStyle(.red)
                Spacer()
            } else if keys.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No JSON documents")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                HSplitView {
                    List(keys, id: \.self, selection: $selectedKey) { key in
                        Text(key)
                            .font(.system(.body, design: .monospaced))
                    }
                    .frame(minWidth: 150, idealWidth: 200)

                    VStack(spacing: 0) {
                        if selectedKey != nil {
                            HStack {
                                Spacer()
                                Button {
                                    formKey = selectedKey ?? ""
                                    formJSON = documentJSON
                                    showEditSheet = true
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .buttonStyle(.borderless)
                                .disabled(isTimeTraveling)
                                Button {
                                    showHistory.toggle()
                                } label: {
                                    Label(showHistory ? "Document" : "History",
                                          systemImage: showHistory ? "doc.text" : "clock.arrow.circlepath")
                                }
                                .buttonStyle(.borderless)
                                .padding(8)
                            }
                            Divider()
                        }

                        if showHistory, let key = selectedKey {
                            VersionHistoryView(primitive: "Json", key: key)
                        } else {
                            ScrollView {
                                if documentJSON.isEmpty {
                                    Text("Select a document")
                                        .foregroundStyle(.secondary)
                                        .padding()
                                } else {
                                    Text(documentJSON)
                                        .font(.system(.body, design: .monospaced))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding()
                                        .textSelection(.enabled)
                                }
                            }
                        }
                    }
                }
            }
        }
        .task(id: appState.reloadToken) {
            await loadKeys()
        }
        .onChange(of: selectedKey) { _, newKey in
            showHistory = false
            if let key = newKey {
                Task { await loadDocument(key: key) }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            jsonFormSheet(isEditing: false)
        }
        .sheet(isPresented: $showEditSheet) {
            jsonFormSheet(isEditing: true)
        }
        .alert("Delete Document", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let key = selectedKey {
                    Task { await deleteDocument(key) }
                }
            }
        } message: {
            if let key = selectedKey {
                Text("Delete document \"\(key)\"? This cannot be undone.")
            }
        }
    }

    @ViewBuilder
    private func jsonFormSheet(isEditing: Bool) -> some View {
        VStack(spacing: 16) {
            Text(isEditing ? "Edit Document" : "Add Document")
                .font(.headline)

            TextField("Key", text: $formKey)
                .textFieldStyle(.roundedBorder)
                .disabled(isEditing)

            Text("Value (Strata Value JSON)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextEditor(text: $formJSON)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 200)
                .border(Color.secondary.opacity(0.3))

            HStack {
                Button("Cancel") {
                    showAddSheet = false
                    showEditSheet = false
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button(isEditing ? "Save" : "Add") {
                    Task {
                        await setDocument(key: formKey, jsonText: formJSON)
                        showAddSheet = false
                        showEditSheet = false
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(formKey.isEmpty || formJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 450, minHeight: 350)
    }

    // MARK: - Write Operations

    private func setDocument(key: String, jsonText: String) async {
        guard let client = appState.client else { return }
        do {
            // Parse the user-provided JSON into a Strata Value
            let value: Any
            if let data = jsonText.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data) {
                value = obj
            } else {
                value = ["String": jsonText]
            }

            var cmd: [String: Any] = [
                "key": key,
                "path": "$",
                "value": value,
                "branch": appState.selectedBranch
            ]
            if appState.selectedSpace != "default" {
                cmd["space"] = appState.selectedSpace
            }
            let wrapper: [String: Any] = ["JsonSet": cmd]
            let data = try JSONSerialization.data(withJSONObject: wrapper)
            let jsonStr = String(data: data, encoding: .utf8)!
            _ = try await client.executeRaw(jsonStr)
            await loadKeys()
            if selectedKey == key {
                await loadDocument(key: key)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteDocument(_ key: String) async {
        guard let client = appState.client else { return }
        do {
            var cmd: [String: Any] = [
                "key": key,
                "path": "$",
                "branch": appState.selectedBranch
            ]
            if appState.selectedSpace != "default" {
                cmd["space"] = appState.selectedSpace
            }
            let wrapper: [String: Any] = ["JsonDelete": cmd]
            let data = try JSONSerialization.data(withJSONObject: wrapper)
            let jsonStr = String(data: data, encoding: .utf8)!
            _ = try await client.executeRaw(jsonStr)
            if selectedKey == key {
                selectedKey = nil
                documentJSON = ""
            }
            await loadKeys()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Load

    private func loadKeys() async {
        guard let client = appState.client else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let json = try await client.executeRaw("{\"JsonList\": {\"limit\": 1000, \"branch\": \"\(appState.selectedBranch)\"\(appState.spaceFragment())\(appState.asOfFragment())}}")
            if let data = json.data(using: .utf8),
               let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let result = root["JsonListResult"] as? [String: Any],
               let keyList = result["keys"] as? [String] {
                keys = keyList
            } else {
                keys = []
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadDocument(key: String) async {
        guard let client = appState.client else { return }
        do {
            let cmd = "{\"JsonGet\": {\"key\": \"\(key)\", \"branch\": \"\(appState.selectedBranch)\"\(appState.spaceFragment())\(appState.asOfFragment())}}"
            let json = try await client.executeRaw(cmd)

            // Pretty print
            if let data = json.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data),
               let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
               let str = String(data: pretty, encoding: .utf8) {
                documentJSON = str
            } else {
                documentJSON = json
            }
        } catch {
            documentJSON = "Error: \(error.localizedDescription)"
        }
    }
}
