//
//  DesignSystem.swift
//  StrataFoundry
//
//  Central design tokens for consistent spacing, corner radii, and layout.
//

import SwiftUI

// MARK: - Spacing

enum StrataSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Corner Radius

enum StrataRadius {
    static let sm: CGFloat = 4
    static let md: CGFloat = 8
    static let lg: CGFloat = 12
}

// MARK: - Layout

enum StrataLayout {
    static let sidebarIdealWidth: CGFloat = 220
    static let inspectorIdealWidth: CGFloat = 320
    static let listPaneIdealWidth: CGFloat = 260
    static let sheetMinWidth: CGFloat = 440
    static let sheetWideMinWidth: CGFloat = 540
}

// MARK: - Callouts

struct StrataErrorCallout: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.callout)
            .foregroundStyle(.white)
            .padding(.horizontal, StrataSpacing.sm)
            .padding(.vertical, StrataSpacing.xs)
            .background(.red.opacity(0.85), in: Capsule())
    }
}

struct StrataSuccessCallout: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "checkmark.circle.fill")
            .font(.callout)
            .foregroundStyle(.white)
            .padding(.horizontal, StrataSpacing.sm)
            .padding(.vertical, StrataSpacing.xs)
            .background(.green.opacity(0.85), in: Capsule())
    }
}
