//
//  EventLogView.swift
//  StrataFoundry
//

import SwiftUI

struct EventEntry: Identifiable {
    let id: Int
    let sequence: Int
    let eventType: String
    let summary: String
    let timestamp: UInt64
}

struct EventLogView: View {
    @Environment(AppState.self) private var appState
    @State private var events: [EventEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var eventCount: Int = 0

    // Write-related state
    @State private var showAppendSheet = false
    @State private var formEventType = ""
    @State private var formPayload = ""

    @State private var showBatchSheet = false
    @State private var batchJSON = ""
    @State private var batchError: String?
    @State private var batchSuccess: String?

    private var isTimeTraveling: Bool { appState.timeTravelDate != nil }

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
                    showAppendSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Append Event")
                .disabled(isTimeTraveling)
                Button {
                    batchJSON = ""
                    batchError = nil
                    batchSuccess = nil
                    showBatchSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.down.on.square")
                }
                .help("Batch Append")
                .disabled(isTimeTraveling)
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
            } else if events.isEmpty {
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
                List(events) { event in
                    HStack(alignment: .top, spacing: 12) {
                        Text("#\(event.sequence)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .frame(width: 30, alignment: .trailing)

                        Text(event.eventType)
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.medium)
                            .frame(width: 100, alignment: .leading)

                        Text(event.summary)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
        }
        .task(id: appState.reloadToken) {
            await loadEvents()
        }
        .sheet(isPresented: $showAppendSheet, onDismiss: clearForm) {
            VStack(spacing: 16) {
                Text("Append Event")
                    .font(.headline)

                TextField("Event Type", text: $formEventType)
                    .textFieldStyle(.roundedBorder)

                Text("Payload (Strata Value JSON)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                TextEditor(text: $formPayload)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 100)
                    .border(Color.secondary.opacity(0.3))

                HStack {
                    Button("Cancel") {
                        showAppendSheet = false
                    }
                    .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Append") {
                        Task {
                            await appendEvent()
                            showAppendSheet = false
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(formEventType.isEmpty)
                }
            }
            .padding(20)
            .frame(minWidth: 400)
        }
        .sheet(isPresented: $showBatchSheet) {
            VStack(spacing: 16) {
                Text("Batch Append Events (EventBatchAppend)")
                    .font(.headline)

                Text("JSON array of {\"event_type\": \"...\", \"payload\": {...}} objects")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                TextEditor(text: $batchJSON)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 150)
                    .border(Color.secondary.opacity(0.3))

                if let err = batchError {
                    Text(err)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
                if let success = batchSuccess {
                    Text(success)
                        .foregroundStyle(.green)
                        .font(.caption)
                }

                HStack {
                    Button("Cancel") {
                        showBatchSheet = false
                    }
                    .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Import") {
                        Task { await batchAppend() }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(batchJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(20)
            .frame(minWidth: 500)
        }
    }

    private func clearForm() {
        formEventType = ""
        formPayload = ""
    }

    // MARK: - Write Operations

    private func appendEvent() async {
        guard let client = appState.client else { return }
        do {
            // Parse payload or default to empty string value
            let payload: Any
            if formPayload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                payload = ["String": ""]
            } else if let data = formPayload.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: data) {
                payload = obj
            } else {
                payload = ["String": formPayload]
            }

            var cmd: [String: Any] = [
                "event_type": formEventType,
                "payload": payload,
                "branch": appState.selectedBranch
            ]
            if appState.selectedSpace != "default" {
                cmd["space"] = appState.selectedSpace
            }
            let wrapper: [String: Any] = ["EventAppend": cmd]
            let data = try JSONSerialization.data(withJSONObject: wrapper)
            let jsonStr = String(data: data, encoding: .utf8)!
            _ = try await client.executeRaw(jsonStr)
            await loadEvents()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Batch Append

    private func batchAppend() async {
        guard let client = appState.client else { return }
        batchError = nil
        batchSuccess = nil
        do {
            guard let data = batchJSON.data(using: .utf8),
                  let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                batchError = "Invalid JSON: expected an array of {\"event_type\": \"...\", \"payload\": {...}} objects"
                return
            }
            var cmd: [String: Any] = [
                "events": items,
                "branch": appState.selectedBranch
            ]
            if appState.selectedSpace != "default" {
                cmd["space"] = appState.selectedSpace
            }
            let wrapper: [String: Any] = ["EventBatchAppend": cmd]
            let wrapperData = try JSONSerialization.data(withJSONObject: wrapper)
            let jsonStr = String(data: wrapperData, encoding: .utf8)!
            _ = try await client.executeRaw(jsonStr)
            batchSuccess = "Appended \(items.count) events."
            await loadEvents()
        } catch {
            batchError = error.localizedDescription
        }
    }

    // MARK: - Load

    private func loadEvents() async {
        guard let client = appState.client else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // Get event count
            let countJSON = try await client.executeRaw("{\"EventLen\": {\"branch\": \"\(appState.selectedBranch)\"\(appState.spaceFragment())\(appState.asOfFragment())}}")
            if let data = countJSON.data(using: .utf8),
               let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let count = root["Uint"] as? Int {
                eventCount = count
            }

            // Fetch events individually by sequence number (0-indexed)
            var fetched: [EventEntry] = []
            let limit = min(eventCount, 200)
            for seq in 0..<limit {
                let cmd = "{\"EventGet\": {\"sequence\": \(seq), \"branch\": \"\(appState.selectedBranch)\"\(appState.spaceFragment())\(appState.asOfFragment())}}"
                let getJSON = try await client.executeRaw(cmd)
                if let data = getJSON.data(using: .utf8),
                   let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let versioned = root["MaybeVersioned"] as? [String: Any] {
                    let ts = versioned["timestamp"] as? UInt64 ?? 0
                    let (eventType, summary) = parseEventValue(versioned["value"])
                    fetched.append(EventEntry(
                        id: seq, sequence: seq,
                        eventType: eventType, summary: summary,
                        timestamp: ts
                    ))
                }
            }
            events = fetched
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Extract event_type (the EventAppend type tag stored alongside the payload)
    /// and a one-line summary from the event value.
    private func parseEventValue(_ value: Any?) -> (String, String) {
        // The event value is a Strata Value — typically {"Object": {fields...}}
        // The event_type was passed to EventAppend but is not stored inside the value;
        // it's only retrievable via EventGetByType. So we summarize the payload instead.
        guard let value else { return ("?", "") }

        if let dict = value as? [String: Any], let obj = dict["Object"] as? [String: Any] {
            // Try to extract an "action" or "tool" field as the type hint
            let typeHint: String
            if let action = (obj["action"] as? [String: Any])?["String"] as? String {
                typeHint = action
            } else if let tool = (obj["tool"] as? [String: Any])?["String"] as? String {
                typeHint = tool
            } else if let msg = (obj["message"] as? [String: Any])?["String"] as? String {
                typeHint = String(msg.prefix(40))
            } else {
                typeHint = "\(obj.count) fields"
            }

            // Build a compact summary of all string fields
            let parts = obj.compactMap { (k, v) -> String? in
                if let inner = v as? [String: Any], let s = inner["String"] as? String {
                    return "\(k)=\(s)"
                }
                if let inner = v as? [String: Any], let n = inner["Int"] as? Int {
                    return "\(k)=\(n)"
                }
                return nil
            }
            return (typeHint, parts.joined(separator: ", "))
        }

        return ("?", "\(value)")
    }
}
