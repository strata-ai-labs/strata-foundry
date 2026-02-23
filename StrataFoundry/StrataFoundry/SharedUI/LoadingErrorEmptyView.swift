//
//  LoadingErrorEmptyView.swift
//  StrataFoundry
//
//  Generic loading/error/empty state view that replaces the duplicated
//  pattern found in 11+ views across the app.
//

import SwiftUI

/// A generic container that shows loading, error, empty, or content states.
///
/// Usage:
/// ```swift
/// LoadingErrorEmptyView(
///     isLoading: model.isLoading,
///     errorMessage: model.errorMessage,
///     isEmpty: model.items.isEmpty,
///     emptyIcon: "tray",
///     emptyText: "No items yet"
/// ) {
///     List(model.items) { item in ... }
/// }
/// ```
struct LoadingErrorEmptyView<Content: View>: View {
    let isLoading: Bool
    let errorMessage: String?
    let isEmpty: Bool
    var emptyIcon: String = "tray"
    var emptyText: String = "No items"
    var emptySubtext: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        if isLoading {
            Spacer()
            ProgressView("Loading...")
            Spacer()
        } else if let error = errorMessage {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                    .foregroundStyle(.red)
                Text(error)
                    .foregroundStyle(.red)
                    .font(.callout)
                    .multilineTextAlignment(.center)
            }
            .padding()
            Spacer()
        } else if isEmpty {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: emptyIcon)
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text(emptyText)
                    .foregroundStyle(.secondary)
                if let sub = emptySubtext {
                    Text(sub)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
        } else {
            content()
        }
    }
}
