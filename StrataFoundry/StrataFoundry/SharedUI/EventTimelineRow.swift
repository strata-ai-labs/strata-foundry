//
//  EventTimelineRow.swift
//  StrataFoundry
//
//  Timeline row with colored dot and connector lines, plus container.
//

import SwiftUI

struct EventTimelineRow: View {
    let event: EventEntryDisplay
    let color: Color
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: StrataSpacing.sm) {
            // Timeline column: dot + connector
            VStack(spacing: 0) {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                    .padding(.top, 6)

                if !isLast {
                    Rectangle()
                        .fill(color.opacity(0.3))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 10)

            // Content card
            VStack(alignment: .leading, spacing: StrataSpacing.xxs) {
                HStack {
                    Text(event.eventType)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, StrataSpacing.xs)
                        .padding(.vertical, 2)
                        .background(color, in: Capsule())

                    Spacer()

                    Text("#\(event.sequence)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }

                if !event.summary.isEmpty {
                    Text(event.summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                if event.timestamp > 0 {
                    Text(formatTimelineTimestamp(event.timestamp))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(StrataSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: StrataRadius.md))
        }
    }

    private func formatTimelineTimestamp(_ micros: UInt64) -> String {
        let date = Date(timeIntervalSince1970: Double(micros) / 1_000_000.0)
        let fmt = DateFormatter()
        fmt.dateStyle = .short
        fmt.timeStyle = .medium
        return fmt.string(from: date)
    }
}

// MARK: - Container

struct EventTimeline: View {
    let events: [EventEntryDisplay]
    @Binding var selectedEventId: Int?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: StrataSpacing.xs) {
                ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                    EventTimelineRow(
                        event: event,
                        color: EventTimeline.colorForEventType(event.eventType),
                        isLast: index == events.count - 1
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedEventId = event.id
                    }
                    .background(
                        RoundedRectangle(cornerRadius: StrataRadius.md)
                            .stroke(selectedEventId == event.id ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
                }
            }
            .padding(StrataSpacing.md)
        }
    }

    // Deterministic color from event type string hash
    static func colorForEventType(_ type: String) -> Color {
        let palette: [Color] = [
            .blue, .purple, .orange, .green, .pink, .cyan, .indigo, .mint, .teal, .red
        ]
        let hash = abs(type.hashValue)
        return palette[hash % palette.count]
    }
}
