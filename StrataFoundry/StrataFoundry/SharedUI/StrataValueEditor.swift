//
//  StrataValueEditor.swift
//  StrataFoundry
//
//  Reusable value type picker + editor, extracted from KV/State form sheets.
//  Handles String, Int, Float, Bool, Null, and raw JSON input.
//

import SwiftUI

/// A reusable editor for entering Strata values with a type picker.
///
/// Used in KV, State, and JSON form sheets where the user picks a value type
/// and enters a corresponding value.
struct StrataValueEditor: View {
    @Binding var valueText: String
    @Binding var valueType: String

    var label: String = "Value"

    static let allTypes = ["String", "Int", "Float", "Bool", "Null", "JSON"]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker(label, selection: $valueType) {
                ForEach(Self.allTypes, id: \.self) { type in
                    Text(type).tag(type)
                }
            }
            .pickerStyle(.segmented)

            switch valueType {
            case "Null":
                Text("null")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            case "Bool":
                Picker("Boolean", selection: $valueText) {
                    Text("true").tag("true")
                    Text("false").tag("false")
                }
                .pickerStyle(.segmented)
            case "JSON":
                TextEditor(text: $valueText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            default:
                TextField(placeholderForType(valueType), text: $valueText)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private func placeholderForType(_ type: String) -> String {
        switch type {
        case "Int": return "e.g. 42"
        case "Float": return "e.g. 3.14"
        case "String": return "Enter text..."
        default: return "Enter value..."
        }
    }

    /// Build a StrataValue from the current editor state, or nil if invalid.
    func buildValue() -> StrataValue? {
        StrataValue.fromUserInput(valueText, type: valueType)
    }
}
