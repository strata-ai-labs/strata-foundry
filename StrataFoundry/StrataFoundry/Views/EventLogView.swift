//
//  EventLogView.swift
//  StrataFoundry
//

import SwiftUI

struct EventLogView: View {
    @Environment(AppState.self) private var appState
    @State private var events: [[String: Any]] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var eventCount: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Event Log")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(eventCount) events")
                    .foregroundStyle(.secondary)
                Button {
                    Task { await loadEvents() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)

            Divider()

            if isLoading {
                Spacer()
                ProgressView("Loading events...")
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                Text(error).foregroundStyle(.red)
                Spacer()
            } else if eventCount == 0 {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "list.bullet.clipboard")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No events in log")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(events.enumerated()), id: \.offset) { _, event in
                            EventRow(event: event)
                        }
                    }
                    .padding(24)
                }
            }
        }
        .task {
            await loadEvents()
        }
    }

    private func loadEvents() async {
        guard let client = appState.client else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // Get event count
            let countJSON = try await client.executeRaw(#"{"EventLen": {}}"#)
            if let data = countJSON.data(using: .utf8),
               let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let count = root["Uint"] as? Int {
                eventCount = count
            }

            // Get recent events (last 100)
            if eventCount > 0 {
                let getJSON = try await client.executeRaw(#"{"EventGet": {"start": 0, "limit": 100}}"#)
                if let data = getJSON.data(using: .utf8),
                   let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let vv = root["VersionedValues"] as? [[String: Any]] {
                    events = vv
                }
            } else {
                events = []
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct EventRow: View {
    let event: [String: Any]

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("#\(event["version"] as? Int ?? 0)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .trailing)

            VStack(alignment: .leading, spacing: 4) {
                if let value = event["value"] as? [String: Any],
                   let data = try? JSONSerialization.data(withJSONObject: value, options: .prettyPrinted),
                   let str = String(data: data, encoding: .utf8) {
                    Text(str)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                } else {
                    Text("(unable to display)")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
