//
//  KVStoreView.swift
//  StrataFoundry
//
//  Table view of KV store contents.
//

import SwiftUI

struct KVEntry: Identifiable {
    let id: String  // the key
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

    private var filteredEntries: [KVEntry] {
        if filterText.isEmpty {
            return entries
        }
        return entries.filter { $0.key.localizedCaseInsensitiveContains(filterText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("KV Store")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                TextField("Filter keys...", text: $filterText)
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

            // Content
            if isLoading {
                Spacer()
                ProgressView("Loading keys...")
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                Text(error)
                    .foregroundStyle(.red)
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
                Table(filteredEntries) {
                    TableColumn("Key", value: \.key)
                        .width(min: 120, ideal: 200)
                    TableColumn("Value", value: \.value)
                        .width(min: 200, ideal: 400)
                    TableColumn("Type", value: \.valueType)
                        .width(min: 60, ideal: 80)
                    TableColumn("Version") { entry in
                        Text("\(entry.version)")
                    }
                    .width(min: 60, ideal: 80)
                }
            }
        }
        .task {
            await loadEntries()
        }
    }

    private func loadEntries() async {
        guard let client = appState.client else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // Step 1: List all keys
            let listJSON = try await client.executeRaw(#"{"KvList": {}}"#)
            guard let keys = parseKeys(from: listJSON) else {
                entries = []
                return
            }

            // Step 2: Get each key's value
            var newEntries: [KVEntry] = []
            for key in keys {
                let getCmd = try jsonString(["KvGet": ["key": key]])
                let getJSON = try await client.executeRaw(getCmd)
                if let entry = parseKVEntry(key: key, from: getJSON) {
                    newEntries.append(entry)
                }
            }

            entries = newEntries
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - JSON Parsing Helpers

    private func parseKeys(from json: String) -> [String]? {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let keys = root["Keys"] as? [String] else {
            return nil
        }
        return keys
    }

    private func parseKVEntry(key: String, from json: String) -> KVEntry? {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let versioned = root["MaybeVersioned"] as? [String: Any] else {
            return nil
        }
        let version = versioned["version"] as? UInt64 ?? 0
        let rawValue = versioned["value"]
        let (display, valueType) = formatStrataValue(rawValue)

        return KVEntry(
            id: key,
            key: key,
            value: display,
            valueType: valueType,
            version: version
        )
    }

    private func formatStrataValue(_ value: Any?) -> (String, String) {
        guard let value else { return ("null", "Null") }

        // Strata values are externally tagged: {"String": "hello"}, {"Int": 42}, etc.
        if let str = value as? String {
            // "Null" comes as a plain string
            return (str, "Null")
        }

        if let dict = value as? [String: Any], let (tag, inner) = dict.first {
            switch tag {
            case "String":
                return ("\"\(inner)\"", "String")
            case "Int":
                return ("\(inner)", "Int")
            case "Float":
                return ("\(inner)", "Float")
            case "Bool":
                return ("\(inner)", "Bool")
            case "Bytes":
                if let arr = inner as? [Any] {
                    return ("[\(arr.count) bytes]", "Bytes")
                }
                return ("\(inner)", "Bytes")
            case "Array":
                if let arr = inner as? [Any] {
                    return ("[\(arr.count) items]", "Array")
                }
                return ("\(inner)", "Array")
            case "Object":
                if let obj = inner as? [String: Any] {
                    return ("{\(obj.count) keys}", "Object")
                }
                return ("\(inner)", "Object")
            default:
                return ("\(inner)", tag)
            }
        }

        return ("\(value)", "?")
    }

    private func jsonString(_ obj: Any) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: obj)
        return String(data: data, encoding: .utf8)!
    }
}
