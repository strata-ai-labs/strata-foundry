//
//  DashboardCard.swift
//  StrataFoundry
//
//  Stat display card with icon, large number, and label.
//

import SwiftUI

struct DashboardCard: View {
    let title: String
    let value: String
    let icon: String
    let iconColor: Color
    let subtitle: String?

    init(title: String, value: String, icon: String, iconColor: Color = .blue, subtitle: String? = nil) {
        self.title = title
        self.value = value
        self.icon = icon
        self.iconColor = iconColor
        self.subtitle = subtitle
    }

    var body: some View {
        HStack(spacing: StrataSpacing.sm) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(iconColor, in: RoundedRectangle(cornerRadius: StrataRadius.md))

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2.monospacedDigit())
                    .fontWeight(.semibold)
                    .contentTransition(.numericText())

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(StrataSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: StrataRadius.md))
    }
}
