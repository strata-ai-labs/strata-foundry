//
//  StatsCapsule.swift
//  StrataFoundry
//
//  Reusable stats capsule component for displaying key-value statistics
//  in a compact capsule format. Used in Vector, Graph, and Database views.
//

import SwiftUI

/// A compact capsule displaying a label and value, used for stats banners.
struct StatsCapsule: View {
    let label: String
    let value: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: StrataSpacing.xxs) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .padding(.horizontal, StrataSpacing.xs)
        .padding(.vertical, StrataSpacing.xxs)
        .background(.quaternary)
        .clipShape(Capsule())
    }
}

/// A horizontal row of stats capsules, commonly used as a banner.
struct StatsBanner: View {
    let stats: [(label: String, value: String, icon: String?)]

    var body: some View {
        HStack(spacing: StrataSpacing.xs) {
            ForEach(Array(stats.enumerated()), id: \.offset) { _, stat in
                StatsCapsule(label: stat.label, value: stat.value, icon: stat.icon)
            }
        }
    }
}
