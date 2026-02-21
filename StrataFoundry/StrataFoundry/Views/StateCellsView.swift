//
//  StateCellsView.swift
//  StrataFoundry
//

import SwiftUI

struct StateCellEntry: Identifiable {
    let id: String  // cell name
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

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("State Cells")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
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
                Table(cells) {
                    TableColumn("Cell", value: \.name)
                        .width(min: 120, ideal: 200)
                    TableColumn("Value", value: \.value)
                        .width(min: 200, ideal: 400)
                    TableColumn("Type", value: \.valueType)
                        .width(min: 60, ideal: 80)
                    TableColumn("Version") { cell in
                        Text("\(cell.version)")
                    }
                    .width(min: 60, ideal: 80)
                }
            }
        }
        .task {
            await loadCells()
        }
    }

    private func loadCells() async {
        guard let client = appState.client else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let listJSON = try await client.executeRaw(#"{"StateList": {}}"#)
            guard let data = listJSON.data(using: .utf8),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let keys = root["Keys"] as? [String] else {
                cells = []
                return
            }

            var newCells: [StateCellEntry] = []
            for name in keys {
                let cmdData = try JSONSerialization.data(withJSONObject: ["StateGet": ["cell": name]])
                let cmdStr = String(data: cmdData, encoding: .utf8)!
                let getJSON = try await client.executeRaw(cmdStr)

                if let getData = getJSON.data(using: .utf8),
                   let getRoot = try? JSONSerialization.jsonObject(with: getData) as? [String: Any],
                   let versioned = getRoot["MaybeVersioned"] as? [String: Any] {
                    let version = versioned["version"] as? UInt64 ?? 0
                    let (display, valueType) = formatValue(versioned["value"])
                    newCells.append(StateCellEntry(
                        id: name, name: name, value: display,
                        valueType: valueType, version: version
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
