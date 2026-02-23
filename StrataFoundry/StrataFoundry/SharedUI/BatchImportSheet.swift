//
//  BatchImportSheet.swift
//  StrataFoundry
//
//  Generic batch import sheet extracted from the identical pattern
//  used in KV, State, Event, JSON, and Vector views.
//

import SwiftUI

/// Result type for batch import actions (avoids Result's Error constraint on Failure).
enum BatchImportOutcome {
    case success(String)
    case failure(String)
}

/// A reusable sheet for batch importing data via JSON text input.
///
/// The caller provides:
/// - A title and placeholder text describing the expected JSON format
/// - An async action closure that receives the JSON string
struct BatchImportSheet: View {
    let title: String
    var placeholder: String = "Paste JSON array here..."
    let action: (String) async -> BatchImportOutcome
    let onDismiss: () -> Void

    @State private var jsonText = ""
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var isImporting = false

    var body: some View {
        Form {
            Section("JSON Data") {
                TextEditor(text: $jsonText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 200)
                    .overlay(alignment: .topLeading) {
                        if jsonText.isEmpty {
                            Text(placeholder)
                                .foregroundStyle(.tertiary)
                                .font(.system(.body, design: .monospaced))
                                .padding(StrataSpacing.xs)
                                .allowsHitTesting(false)
                        }
                    }
            }

            if let error = errorMessage {
                StrataErrorCallout(message: error)
            }

            if let success = successMessage {
                StrataSuccessCallout(message: success)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(title)
        .frame(minWidth: StrataLayout.sheetWideMinWidth, minHeight: 350)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button("Cancel") {
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Import") {
                    Task {
                        isImporting = true
                        errorMessage = nil
                        successMessage = nil
                        let result = await action(jsonText)
                        switch result {
                        case .success(let msg):
                            successMessage = msg
                        case .failure(let msg):
                            errorMessage = msg
                        }
                        isImporting = false
                    }
                }
                .disabled(jsonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isImporting)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(StrataSpacing.lg)
        }
    }
}
