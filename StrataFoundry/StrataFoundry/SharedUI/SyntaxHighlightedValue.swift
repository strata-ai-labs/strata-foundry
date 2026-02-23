//
//  SyntaxHighlightedValue.swift
//  StrataFoundry
//
//  Compact inline colored value for table columns.
//

import SwiftUI

struct SyntaxHighlightedValue: View {
    let value: StrataValue
    let maxLength: Int

    init(value: StrataValue, maxLength: Int = 60) {
        self.value = value
        self.maxLength = maxLength
    }

    var body: some View {
        Text(attributedString)
            .lineLimit(1)
    }

    private var attributedString: AttributedString {
        var result = AttributedString(displayText)
        result.foregroundColor = displayColor
        result.font = .system(.body, design: .monospaced)
        return result
    }

    private var displayText: String {
        switch value {
        case .null:
            return "null"
        case .bool(let b):
            return b ? "true" : "false"
        case .int(let n):
            return "\(n)"
        case .float(let f):
            return String(format: "%g", f)
        case .string(let s):
            let truncated = s.count > maxLength ? String(s.prefix(maxLength)) + "..." : s
            return "\"\(truncated)\""
        case .bytes(let b):
            return "<\(b.count) bytes>"
        case .array(let items):
            return arrayPreview(items)
        case .object(let fields):
            return objectPreview(fields)
        }
    }

    private var displayColor: Color {
        switch value {
        case .string: return .green
        case .int, .float: return .blue
        case .bool: return .orange
        case .null: return .secondary
        case .bytes: return .pink
        case .array, .object: return .secondary
        }
    }

    private func arrayPreview(_ items: [StrataValue]) -> String {
        if items.isEmpty { return "[]" }
        let previews = items.prefix(3).map { shortValue($0) }
        let joined = previews.joined(separator: ", ")
        if items.count > 3 {
            return "[\(joined), ...] (\(items.count) items)"
        }
        return "[\(joined)]"
    }

    private func objectPreview(_ fields: [String: StrataValue]) -> String {
        if fields.isEmpty { return "{}" }
        let keys = fields.keys.sorted().prefix(3)
        let previews = keys.map { $0 }
        let joined = previews.joined(separator: ", ")
        if fields.count > 3 {
            return "{\(joined), ...} (\(fields.count) fields)"
        }
        return "{\(joined)}"
    }

    private func shortValue(_ value: StrataValue) -> String {
        switch value {
        case .null: return "null"
        case .bool(let b): return b ? "true" : "false"
        case .int(let n): return "\(n)"
        case .float(let f): return String(format: "%g", f)
        case .string(let s):
            let truncated = s.count > 20 ? String(s.prefix(20)) + "..." : s
            return "\"\(truncated)\""
        case .bytes(let b): return "<\(b.count)B>"
        case .array(let a): return "[\(a.count)]"
        case .object(let o): return "{\(o.count)}"
        }
    }
}
