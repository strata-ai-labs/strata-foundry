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
        Group {
            if isLoading {
                SkeletonLoadingView()
            } else if let error = errorMessage {
                VStack(spacing: StrataSpacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.red)
                    Text("Something went wrong")
                        .font(.headline)
                    Text(error)
                        .foregroundStyle(.secondary)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if isEmpty {
                EmptyStateView(
                    icon: emptyIcon,
                    title: emptyText,
                    subtitle: emptySubtext
                )
            } else {
                content()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isLoading)
        .animation(.easeInOut(duration: 0.25), value: errorMessage == nil)
        .animation(.easeInOut(duration: 0.25), value: isEmpty)
    }
}
