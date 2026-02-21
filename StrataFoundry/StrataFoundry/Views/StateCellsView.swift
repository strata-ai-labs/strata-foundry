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
                }
            }
        }
        .task(id: appState.reloadToken) {
            await loadCells()
        }
        .sheet(item: $selectedCell) { cell in
            VersionHistoryView(primitive: "State", key: cell.name)
                .environment(appState)
                .frame(minWidth: 400, minHeight: 300)
        }
    }

    private func loadCells() async {
        guard let client = appState.client else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let listJSON = try await client.executeRaw("{\"StateList\": {\"branch\": \"\(appState.selectedBranch)\"\(appState.asOfFragment())}}")
            guard let data = listJSON.data(using: .utf8),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let keys = root["Keys"] as? [String] else {
                cells = []
                return
            }

            var newCells: [StateCellEntry] = []
            for name in keys {
                let cmd = "{\"StateGet\": {\"cell\": \"\(name)\", \"branch\": \"\(appState.selectedBranch)\"\(appState.asOfFragment())}}"
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
