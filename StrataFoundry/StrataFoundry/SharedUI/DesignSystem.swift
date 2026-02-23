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
}
