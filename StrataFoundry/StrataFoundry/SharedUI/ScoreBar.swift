//
//  ScoreBar.swift
//  StrataFoundry
//
//  Horizontal score visualization bar with color by range.
//

import SwiftUI

struct ScoreBar: View {
    let score: Double
    let maxScore: Double
    let compact: Bool

    @State private var animatedScore: Double = 0

    init(score: Double, maxScore: Double = 1.0, compact: Bool = false) {
        self.score = score
        self.maxScore = maxScore
        self.compact = compact
    }

    var body: some View {
        HStack(spacing: compact ? StrataSpacing.xxs : StrataSpacing.xs) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: compact ? 2 : 3)
                        .fill(.quaternary)

                    RoundedRectangle(cornerRadius: compact ? 2 : 3)
                        .fill(barColor)
                        .frame(width: max(0, geo.size.width * fraction))
                }
            }
            .frame(height: compact ? 6 : 10)
            .frame(maxWidth: compact ? 80 : .infinity)

            Text(String(format: "%.4f", score))
                .font(.system(compact ? .caption2 : .caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .fixedSize()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                animatedScore = score
            }
        }
        .onChange(of: score) { _, newValue in
            withAnimation(.easeOut(duration: 0.3)) {
                animatedScore = newValue
            }
        }
    }

    private var fraction: Double {
        guard maxScore > 0 else { return 0 }
        return min(1.0, max(0, animatedScore / maxScore))
    }

    private var barColor: Color {
        let normalized = min(1.0, max(0, score / max(maxScore, 0.001)))
        if normalized >= 0.8 { return .green }
        if normalized >= 0.6 { return .cyan }
        if normalized >= 0.4 { return .blue }
        if normalized >= 0.2 { return .orange }
        return .red
    }
}
