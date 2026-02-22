//
//  VersionHistoryView.swift
//  StrataFoundry
//
//  Reusable view that fetches and displays version history for a key.
//

import SwiftUI

struct VersionedEntry: Identifiable {
    let id: Int
    let version: UInt64
    let timestamp: UInt64
    let displayValue: String
    let valueType: String
}

struct VersionHistoryView: View {
    @Environment(AppState.self) private var appState

    let primitive: String  // "Kv", "State", or "Json"
    let key: String

    @State private var versions: [VersionedEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var expandedVersion: Int?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.secondary)
                Text("Version History")
                    .font(.headline)
                Text("—")
                    .foregroundStyle(.tertiary)
                Text(key)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(versions.count) versions")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if isLoading {
                Spacer()
                ProgressView("Loading history...")
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                Text(error).foregroundStyle(.red).padding()
                Spacer()
            } else if versions.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No version history available")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                List(versions) { entry in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("v\(entry.version)")
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.semibold)

                            if entry.id == 0 {
                                Text("latest")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.blue.opacity(0.15))
                                    .foregroundStyle(.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }

                            Spacer()

                            Text(entry.valueType)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.quaternary)
                                .clipShape(RoundedRectangle(cornerRadius: 4))

                            Text(formatTimestamp(entry.timestamp))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }

                        Text(entry.displayValue)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(expandedVersion == entry.id ? nil : 3)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation {
                            expandedVersion = expandedVersion == entry.id ? nil : entry.id
                        }
                    }
                }
            }
        }
        .task {
            await loadVersions()
        }
    }

    private func loadVersions() async {
        guard let client = appState.client else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let commandName: String
        let keyField: String
        switch primitive {
        case "Kv":
            commandName = "KvGetv"
            keyField = "key"
        case "State":
            commandName = "StateGetv"
            keyField = "cell"
        case "Json":
            commandName = "JsonGetv"
            keyField = "key"
        default:
            errorMessage = "Unknown primitive: \(primitive)"
            return
        }
        var innerCmd: [String: Any] = [
            keyField: key,
            "branch": appState.selectedBranch
        ]
        if appState.selectedSpace != "default" {
            innerCmd["space"] = appState.selectedSpace
        }
        let wrapper = [commandName: innerCmd]
        guard let cmdData = try? JSONSerialization.data(withJSONObject: wrapper),
              let cmd = String(data: cmdData, encoding: .utf8) else {
            errorMessage = "Failed to build command"
            return
        }

        do {
            let json = try await client.executeRaw(cmd)
            guard let data = json.data(using: .utf8),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let historyArray = root["VersionHistory"] as? [[String: Any]] else {
                // Could be null (no history) or a different format
                if let data = json.data(using: .utf8),
                   let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   root["VersionHistory"] is NSNull {
                    versions = []
                    return
                }
                versions = []
                return
            }

            var entries: [VersionedEntry] = []
            for (index, item) in historyArray.reversed().enumerated() {
                let ver = item["version"] as? UInt64
                    ?? (item["version"] as? Int).map(UInt64.init) ?? 0
                let ts = item["timestamp"] as? UInt64
                    ?? (item["timestamp"] as? Int).map(UInt64.init) ?? 0
                let (display, vType) = formatValue(item["value"])
                entries.append(VersionedEntry(
                    id: index,
                    version: ver,
                    timestamp: ts,
                    displayValue: display,
                    valueType: vType
                ))
            }
            versions = entries
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func formatValue(_ value: Any?) -> (String, String) {
        guard let value else { return ("null", "Null") }
        if let str = value as? String { return (str, "String") }
        if let num = value as? Int { return ("\(num)", "Int") }
        if let num = value as? Double { return ("\(num)", "Float") }
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
                if let obj = inner as? [String: Any] {
                    if let data = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
                       let str = String(data: data, encoding: .utf8) {
                        return (str, "Object")
                    }
                    return ("{\(obj.count) keys}", "Object")
                }
                return ("\(inner)", "Object")
            default: return ("\(inner)", tag)
            }
        }
        // For Json primitive, value may be raw JSON
        if let dict = value as? [String: Any],
           let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
           let str = String(data: data, encoding: .utf8) {
            return (str, "JSON")
        }
        return ("\(value)", "?")
    }

    private func formatTimestamp(_ micros: UInt64) -> String {
        guard micros > 0 else { return "" }
        let date = Date(timeIntervalSince1970: Double(micros) / 1_000_000.0)
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .medium
        return fmt.string(from: date)
    }
}
