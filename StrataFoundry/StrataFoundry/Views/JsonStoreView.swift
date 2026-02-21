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
    }

    private func loadKeys() async {
        guard let client = appState.client else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let json = try await client.executeRaw("{\"JsonList\": {\"limit\": 1000, \"branch\": \"\(appState.selectedBranch)\"\(appState.asOfFragment())}}")
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
            let cmd = "{\"JsonGet\": {\"key\": \"\(key)\", \"branch\": \"\(appState.selectedBranch)\"\(appState.asOfFragment())}}"
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
