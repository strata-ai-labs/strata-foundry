//
//  SkeletonLoadingView.swift
//  StrataFoundry
//
//  Shimmer loading placeholder with animated opacity pulse.
//

import SwiftUI

struct SkeletonLoadingView: View {
    var rows: Int = 8
    var columns: Int = 3
    @State private var isAnimating = false

    var body: some View {
        VStack(alignment: .leading, spacing: StrataSpacing.sm) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: StrataSpacing.md) {
                    ForEach(0..<columns, id: \.self) { col in
                        RoundedRectangle(cornerRadius: StrataRadius.sm)
                            .fill(.quaternary)
                            .frame(height: 16)
                            .frame(maxWidth: columnWidth(col))
                    }
                }
            }
        }
        .padding(StrataSpacing.lg)
        .opacity(isAnimating ? 0.4 : 1.0)
        .animation(
            .easeInOut(duration: 0.8)
            .repeatForever(autoreverses: true),
            value: isAnimating
        )
        .onAppear { isAnimating = true }
    }

    private func columnWidth(_ index: Int) -> CGFloat {
        switch index {
        case 0: return 180
        case 1: return .infinity
        default: return 80
        }
    }
}
