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
                }
            }
        }
        .task(id: appState.reloadToken) {
            await loadEntries()
        }
        .sheet(item: $selectedEntry) { entry in
            VersionHistoryView(primitive: "Kv", key: entry.key)
                .environment(appState)
                .frame(minWidth: 400, minHeight: 300)
        }
    }

    private func loadEntries() async {
        guard let client = appState.client else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let listJSON = try await client.executeRaw("{\"KvList\": {\"branch\": \"\(appState.selectedBranch)\"\(appState.asOfFragment())}}")
            guard let data = listJSON.data(using: .utf8),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let keys = root["Keys"] as? [String] else {
                entries = []
                return
            }

            var newEntries: [KVEntry] = []
            for key in keys {
                let cmd = "{\"KvGet\": {\"key\": \"\(key)\", \"branch\": \"\(appState.selectedBranch)\"\(appState.asOfFragment())}}"
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
