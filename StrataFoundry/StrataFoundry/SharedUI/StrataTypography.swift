//
//  StrataTypography.swift
//  StrataFoundry
//
//  View extensions for consistent typographic styles across the app.
//

import SwiftUI

extension View {
    /// Monospaced medium weight for data keys (e.g. KV keys, cell names).
    func strataKeyStyle() -> some View {
        self
            .font(.system(.body, design: .monospaced))
            .fontWeight(.medium)
    }

    /// Monospaced callout for JSON/code display only.
    func strataCodeStyle() -> some View {
        self
            .font(.system(.callout, design: .monospaced))
    }

    /// Callout + secondary color for descriptions and values.
    func strataSecondaryStyle() -> some View {
        self
            .font(.callout)
            .foregroundStyle(.secondary)
    }

    /// Caption2 + quaternary background pill for type tags.
    func strataBadgeStyle() -> some View {
        self
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, StrataSpacing.xs)
            .padding(.vertical, StrataSpacing.xxs)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: StrataRadius.sm))
    }

    /// Callout + secondary for count labels.
    func strataCountStyle() -> some View {
        self
            .font(.callout)
            .foregroundStyle(.secondary)
    }

    /// Headline weight for section headers.
    func strataSectionHeader() -> some View {
        self
            .font(.headline)
    }
}
