import Foundation

struct EventEntryDisplay: Identifiable {
    let id: Int
    let sequence: Int
    let eventType: String
    let summary: String
    let timestamp: UInt64
}

@Observable
final class EventFeatureModel {
    private let eventService: EventService
    private let appState: AppState

    var events: [EventEntryDisplay] = []
    var isLoading = false
    var errorMessage: String?
    var eventCount: Int = 0

    // Append form
    var formEventType = ""
    var formPayload = ""
    var showAppendSheet = false

    // Batch
    var showBatchSheet = false

    var isTimeTraveling: Bool { appState.timeTravelDate != nil }

    init(eventService: EventService, appState: AppState) {
        self.eventService = eventService
        self.appState = appState
    }

    func loadEvents() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let branch = appState.selectedBranch
        let space: String? = appState.selectedSpace == "default" ? nil : appState.selectedSpace
        let asOf = asOfFromDate(appState.timeTravelDate)

        do {
            let count = try await eventService.len(branch: branch, space: space)
            eventCount = Int(count)

            var fetched: [EventEntryDisplay] = []
            let limit = min(eventCount, 200)
            for seq in 0..<limit {
                if let vv = try await eventService.get(sequence: UInt64(seq), branch: branch, space: space, asOf: asOf) {
                    let (eventType, summary) = parseEventValue(vv.value)
                    fetched.append(EventEntryDisplay(
                        id: seq, sequence: seq,
                        eventType: eventType, summary: summary,
                        timestamp: vv.timestamp
                    ))
                }
            }
            events = fetched
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func appendEvent() async {
        let payload: StrataValue
        let trimmed = formPayload.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            payload = .string("")
        } else if let parsed = StrataValue.fromJSONString(trimmed) {
            payload = parsed
        } else {
            payload = .string(formPayload)
        }

        let branch = appState.selectedBranch
        let space: String? = appState.selectedSpace == "default" ? nil : appState.selectedSpace

        do {
            _ = try await eventService.append(eventType: formEventType, payload: payload, branch: branch, space: space)
            showAppendSheet = false
            clearForm()
            await loadEvents()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func batchImport(jsonText: String) async -> BatchImportOutcome {
        guard let data = jsonText.data(using: .utf8),
              let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return .failure("Invalid JSON: expected an array of {\"event_type\": \"...\", \"payload\": {...}} objects")
        }

        var batchEntries: [BatchEventEntry] = []
        for item in items {
            guard let eventType = item["event_type"] as? String else {
                return .failure("Each item must have an \"event_type\" field")
            }
            let payloadObj = item["payload"] ?? NSNull()
            let payload = StrataValue.fromJSONObject(payloadObj)
            batchEntries.append(BatchEventEntry(eventType: eventType, payload: payload))
        }

        let branch = appState.selectedBranch
        let space: String? = appState.selectedSpace == "default" ? nil : appState.selectedSpace

        do {
            _ = try await eventService.batchAppend(entries: batchEntries, branch: branch, space: space)
            await loadEvents()
            return .success("Appended \(batchEntries.count) events.")
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    func clearForm() {
        formEventType = ""
        formPayload = ""
    }

    // MARK: - Helpers

    private func parseEventValue(_ value: StrataValue) -> (String, String) {
        guard case .object(let fields) = value else {
            return ("?", value.displayString)
        }

        // Try to extract a type hint from common field names
        let typeHint: String
        if case .string(let action) = fields["action"] {
            typeHint = action
        } else if case .string(let tool) = fields["tool"] {
            typeHint = tool
        } else if case .string(let msg) = fields["message"] {
            typeHint = String(msg.prefix(40))
        } else {
            typeHint = "\(fields.count) fields"
        }

        // Build compact summary of string/int fields
        let parts = fields.sorted(by: { $0.key < $1.key }).compactMap { (k, v) -> String? in
            switch v {
            case .string(let s): return "\(k)=\(s)"
            case .int(let n): return "\(k)=\(n)"
            default: return nil
            }
        }
        return (typeHint, parts.joined(separator: ", "))
    }
}
