//
//  StrataValue.swift
//  StrataFoundry
//
//  Codable enum matching Rust's `Value` type with externally-tagged JSON format.
//  Handles: {"Int": 42}, {"String": "hi"}, "Null" (bare string for null).
//

import Foundation

/// Mirrors Rust's `strata_core::Value` enum — the canonical value type for all Strata data.
///
/// JSON format matches Rust's serde externally-tagged representation:
/// - `"Null"` (bare string)
/// - `{"Bool": true}`
/// - `{"Int": 42}`
/// - `{"Float": 3.14}`
/// - `{"String": "hello"}`
/// - `{"Bytes": [1, 2, 3]}`
/// - `{"Array": [...]}`
/// - `{"Object": {"key": ...}}`
enum StrataValue: Hashable, Sendable {
    case null
    case bool(Bool)
    case int(Int64)
    case float(Double)
    case string(String)
    case bytes([UInt8])
    case array([StrataValue])
    case object([String: StrataValue])

    // MARK: - Hashable (manual, since Dictionary doesn't auto-conform)

    static func == (lhs: StrataValue, rhs: StrataValue) -> Bool {
        switch (lhs, rhs) {
        case (.null, .null): return true
        case (.bool(let a), .bool(let b)): return a == b
        case (.int(let a), .int(let b)): return a == b
        case (.float(let a), .float(let b)): return a == b
        case (.string(let a), .string(let b)): return a == b
        case (.bytes(let a), .bytes(let b)): return a == b
        case (.array(let a), .array(let b)): return a == b
        case (.object(let a), .object(let b)): return a == b
        default: return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .null:
            hasher.combine(0)
        case .bool(let b):
            hasher.combine(1)
            hasher.combine(b)
        case .int(let i):
            hasher.combine(2)
            hasher.combine(i)
        case .float(let f):
            hasher.combine(3)
            hasher.combine(f)
        case .string(let s):
            hasher.combine(4)
            hasher.combine(s)
        case .bytes(let b):
            hasher.combine(5)
            hasher.combine(b)
        case .array(let arr):
            hasher.combine(6)
            hasher.combine(arr)
        case .object(let dict):
            hasher.combine(7)
            hasher.combine(dict.count)
            for (key, value) in dict.sorted(by: { $0.key < $1.key }) {
                hasher.combine(key)
                hasher.combine(value)
            }
        }
    }

    // MARK: - Display

    /// Human-readable display string for the value.
    var displayString: String {
        switch self {
        case .null:
            return "null"
        case .bool(let b):
            return b ? "true" : "false"
        case .int(let i):
            return "\(i)"
        case .float(let f):
            if f == f.rounded() && !f.isInfinite && !f.isNaN {
                return String(format: "%.1f", f)
            }
            return "\(f)"
        case .string(let s):
            return s
        case .bytes(let b):
            return "[\(b.count) bytes]"
        case .array(let arr):
            if arr.count <= 3 {
                let items = arr.map(\.displayString).joined(separator: ", ")
                return "[\(items)]"
            }
            return "[\(arr.count) items]"
        case .object(let dict):
            if dict.count <= 3 {
                let items = dict.sorted(by: { $0.key < $1.key })
                    .map { "\($0.key): \($0.value.displayString)" }
                    .joined(separator: ", ")
                return "{\(items)}"
            }
            return "{\(dict.count) fields}"
        }
    }

    /// Short type tag for display (e.g., "String", "Int").
    var typeTag: String {
        switch self {
        case .null: return "Null"
        case .bool: return "Bool"
        case .int: return "Int"
        case .float: return "Float"
        case .string: return "String"
        case .bytes: return "Bytes"
        case .array: return "Array"
        case .object: return "Object"
        }
    }

    /// Pretty-printed JSON string representation (for JSON document display).
    var prettyJSON: String {
        guard let data = try? JSONEncoder.strataEncoder.encode(self),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: pretty, encoding: .utf8) else {
            return displayString
        }
        return str
    }

    // MARK: - Construction from User Input

    /// Create a StrataValue from user-provided text and a type tag string.
    static func fromUserInput(_ input: String, type: String) -> StrataValue? {
        switch type {
        case "String":
            return .string(input)
        case "Int":
            guard let i = Int64(input) else { return nil }
            return .int(i)
        case "Float":
            guard let f = Double(input) else { return nil }
            return .float(f)
        case "Bool":
            let lower = input.lowercased()
            if lower == "true" || lower == "1" { return .bool(true) }
            if lower == "false" || lower == "0" { return .bool(false) }
            return nil
        case "Null":
            return .null
        case "JSON":
            return fromJSONString(input)
        default:
            return nil
        }
    }

    /// Parse a JSON string into a StrataValue, interpreting it as a raw JSON value
    /// (not the externally-tagged Strata format).
    static func fromJSONString(_ json: String) -> StrataValue? {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) else {
            return nil
        }
        return fromJSONObject(obj)
    }

    /// Convert a Foundation JSON object (from JSONSerialization) to StrataValue.
    static func fromJSONObject(_ obj: Any) -> StrataValue {
        if obj is NSNull {
            return .null
        } else if let b = obj as? Bool {
            // Must check Bool before NSNumber since Bool bridges to NSNumber
            return .bool(b)
        } else if let n = obj as? NSNumber {
            // Check if it's actually a boolean (CFBoolean)
            if CFGetTypeID(n) == CFBooleanGetTypeID() {
                return .bool(n.boolValue)
            }
            // Check if it has a decimal point by looking at objCType
            let objCType = String(cString: n.objCType)
            if objCType == "d" || objCType == "f" {
                return .float(n.doubleValue)
            }
            return .int(n.int64Value)
        } else if let s = obj as? String {
            return .string(s)
        } else if let arr = obj as? [Any] {
            return .array(arr.map { fromJSONObject($0) })
        } else if let dict = obj as? [String: Any] {
            return .object(dict.mapValues { fromJSONObject($0) })
        }
        return .null
    }
}

// MARK: - Codable (Externally-Tagged Serde Format)

extension StrataValue: Codable {
    init(from decoder: Decoder) throws {
        // Try bare string first: "Null"
        if let container = try? decoder.singleValueContainer() {
            if let str = try? container.decode(String.self), str == "Null" {
                self = .null
                return
            }
        }

        // Externally-tagged: {"Type": value}
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)

        if let key = container.allKeys.first {
            switch key.stringValue {
            case "Null":
                self = .null
            case "Bool":
                self = .bool(try container.decode(Bool.self, forKey: key))
            case "Int":
                self = .int(try container.decode(Int64.self, forKey: key))
            case "Float":
                self = .float(try container.decode(Double.self, forKey: key))
            case "String":
                self = .string(try container.decode(String.self, forKey: key))
            case "Bytes":
                self = .bytes(try container.decode([UInt8].self, forKey: key))
            case "Array":
                self = .array(try container.decode([StrataValue].self, forKey: key))
            case "Object":
                self = .object(try container.decode([String: StrataValue].self, forKey: key))
            default:
                throw DecodingError.dataCorrupted(
                    .init(codingPath: decoder.codingPath,
                          debugDescription: "Unknown StrataValue variant: \(key.stringValue)"))
            }
        } else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath,
                      debugDescription: "Empty object for StrataValue"))
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .null:
            var container = encoder.singleValueContainer()
            try container.encode("Null")
        case .bool(let b):
            var container = encoder.container(keyedBy: DynamicCodingKey.self)
            try container.encode(b, forKey: .init("Bool"))
        case .int(let i):
            var container = encoder.container(keyedBy: DynamicCodingKey.self)
            try container.encode(i, forKey: .init("Int"))
        case .float(let f):
            var container = encoder.container(keyedBy: DynamicCodingKey.self)
            try container.encode(f, forKey: .init("Float"))
        case .string(let s):
            var container = encoder.container(keyedBy: DynamicCodingKey.self)
            try container.encode(s, forKey: .init("String"))
        case .bytes(let b):
            var container = encoder.container(keyedBy: DynamicCodingKey.self)
            try container.encode(b, forKey: .init("Bytes"))
        case .array(let arr):
            var container = encoder.container(keyedBy: DynamicCodingKey.self)
            try container.encode(arr, forKey: .init("Array"))
        case .object(let dict):
            var container = encoder.container(keyedBy: DynamicCodingKey.self)
            try container.encode(dict, forKey: .init("Object"))
        }
    }
}

// MARK: - Dynamic Coding Key

/// A coding key that can represent any string, used for externally-tagged enum decoding.
struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(_ string: String) {
        self.stringValue = string
        self.intValue = nil
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

// MARK: - Encoder/Decoder Extensions

extension JSONEncoder {
    /// Shared encoder configured for Strata's JSON format.
    static let strataEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()
}

extension JSONDecoder {
    /// Shared decoder configured for Strata's JSON format.
    static let strataDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()
}
