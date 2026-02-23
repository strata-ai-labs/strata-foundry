//
//  JSONTreeView.swift
//  StrataFoundry
//
//  Collapsible tree view for StrataValue with color-coded types.
//

import SwiftUI

struct JSONTreeView: View {
    let value: StrataValue
    let rootLabel: String?
    let initialExpandDepth: Int

    @State private var expandedPaths: Set<String> = []
    @State private var didInit = false

    init(value: StrataValue, rootLabel: String? = nil, initialExpandDepth: Int = 2) {
        self.value = value
        self.rootLabel = rootLabel
        self.initialExpandDepth = initialExpandDepth
    }

    var body: some View {
        let rows = buildFlatRows(value: value, key: rootLabel, path: "$", depth: 0)

        VStack(alignment: .leading, spacing: 0) {
            ForEach(rows) { row in
                if row.isContainer {
                    containerButton(row: row)
                } else {
                    leafView(row: row)
                }
            }
        }
        .onAppear {
            guard !didInit else { return }
            didInit = true
            expandedPaths = collectExpandedPaths(value: value, path: "$", depth: 0, maxDepth: initialExpandDepth)
        }
    }

    // MARK: - Flat Row Model

    private struct TreeRow: Identifiable {
        let id: String // path
        let key: String?
        let depth: Int
        let isContainer: Bool
        let summary: String
        let leafValue: StrataValue?
    }

    // MARK: - Build Rows

    private func buildFlatRows(value: StrataValue, key: String?, path: String, depth: Int) -> [TreeRow] {
        switch value {
        case .object(let fields):
            var rows: [TreeRow] = []
            rows.append(TreeRow(id: path, key: key, depth: depth, isContainer: true, summary: "{\(fields.count) fields}", leafValue: nil))
            if expandedPaths.contains(path) {
                for (childKey, childValue) in fields.sorted(by: { $0.key < $1.key }) {
                    rows.append(contentsOf: buildFlatRows(value: childValue, key: childKey, path: "\(path).\(childKey)", depth: depth + 1))
                }
            }
            return rows
        case .array(let items):
            var rows: [TreeRow] = []
            rows.append(TreeRow(id: path, key: key, depth: depth, isContainer: true, summary: "[\(items.count) items]", leafValue: nil))
            if expandedPaths.contains(path) {
                for (index, item) in items.enumerated() {
                    rows.append(contentsOf: buildFlatRows(value: item, key: "[\(index)]", path: "\(path)[\(index)]", depth: depth + 1))
                }
            }
            return rows
        default:
            return [TreeRow(id: path, key: key, depth: depth, isContainer: false, summary: "", leafValue: value)]
        }
    }

    // MARK: - Container Button

    @ViewBuilder
    private func containerButton(row: TreeRow) -> some View {
        let isExpanded = expandedPaths.contains(row.id)

        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if isExpanded {
                    expandedPaths.remove(row.id)
                } else {
                    expandedPaths.insert(row.id)
                }
            }
        } label: {
            HStack(spacing: StrataSpacing.xxs) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(width: 10)

                if let key = row.key {
                    Text(key)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                }

                Text(row.summary)
                    .foregroundStyle(.secondary)
            }
            .font(.system(.callout, design: .monospaced))
            .padding(.leading, CGFloat(row.depth) * 16)
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Leaf View

    @ViewBuilder
    private func leafView(row: TreeRow) -> some View {
        let val = row.leafValue ?? .null

        HStack(spacing: StrataSpacing.xxs) {
            Color.clear.frame(width: 10)

            if let key = row.key {
                Text(key)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                Text(":")
                    .foregroundStyle(.tertiary)
            }

            Text(leafDisplayString(val))
                .foregroundStyle(colorForValue(val))
        }
        .font(.system(.callout, design: .monospaced))
        .padding(.leading, CGFloat(row.depth) * 16)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    // MARK: - Helpers

    private func leafDisplayString(_ value: StrataValue) -> String {
        switch value {
        case .null: return "null"
        case .bool(let b): return b ? "true" : "false"
        case .int(let n): return "\(n)"
        case .float(let f): return String(format: "%g", f)
        case .string(let s): return "\"\(s)\""
        case .bytes(let b): return "<\(b.count) bytes>"
        case .array, .object: return ""
        }
    }

    private func colorForValue(_ value: StrataValue) -> Color {
        switch value {
        case .string: return .green
        case .int, .float: return .blue
        case .bool: return .orange
        case .null: return .secondary
        case .bytes: return .pink
        case .array, .object: return .primary
        }
    }

    private func collectExpandedPaths(value: StrataValue, path: String, depth: Int, maxDepth: Int) -> Set<String> {
        guard depth < maxDepth else { return [] }
        var paths: Set<String> = []
        switch value {
        case .object(let fields):
            paths.insert(path)
            for (key, child) in fields {
                paths.formUnion(collectExpandedPaths(value: child, path: "\(path).\(key)", depth: depth + 1, maxDepth: maxDepth))
            }
        case .array(let items):
            paths.insert(path)
            for (index, child) in items.enumerated() {
                paths.formUnion(collectExpandedPaths(value: child, path: "\(path)[\(index)]", depth: depth + 1, maxDepth: maxDepth))
            }
        default:
            break
        }
        return paths
    }
}
