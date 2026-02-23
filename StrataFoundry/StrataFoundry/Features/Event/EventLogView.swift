//
//  EventLogView.swift
//  StrataFoundry
//
//  Thin view observing EventFeatureModel — all business logic delegated to model.
//

import SwiftUI

struct EventLogView: View {
    @Environment(AppState.self) private var appState
    @State private var model: EventFeatureModel?

    var body: some View {
        VStack(spacing: 0) {
            if let model {
                toolbar(model)
                Divider()
                content(model)
            } else {
                Spacer()
                ProgressView("Loading...")
                Spacer()
            }
        }
        .task(id: appState.reloadToken) {
            if model == nil, let services = appState.services {
                model = EventFeatureModel(eventService: services.eventService, appState: appState)
            }
            await model?.loadEvents()
        }
        .sheet(isPresented: Binding(
            get: { model?.showAppendSheet ?? false },
            set: { model?.showAppendSheet = $0 }
        ), onDismiss: { model?.clearForm() }) {
            if let model {
                appendFormSheet(model: model)
            }
        }
        .sheet(isPresented: Binding(
            get: { model?.showBatchSheet ?? false },
            set: { model?.showBatchSheet = $0 }
        )) {
            if let model {
                BatchImportSheet(
                    title: "Batch Append Events (EventBatchAppend)",
                    placeholder: "JSON array of {\"event_type\": \"...\", \"payload\": {...}} objects"
                ) { jsonText in
                    await model.batchImport(jsonText: jsonText)
                } onDismiss: {
                    model.showBatchSheet = false
                }
            }
        }
    }

    // MARK: - Toolbar

    @ViewBuilder
    private func toolbar(_ model: EventFeatureModel) -> some View {
        HStack {
            Text("Event Log")
                .font(.title2)
                .fontWeight(.semibold)
            Spacer()
            Text("\(model.eventCount) events")
                .foregroundStyle(.secondary)
            Button {
                model.showAppendSheet = true
            } label: {
                Image(systemName: "plus")
            }
            .help("Append Event")
            .disabled(model.isTimeTraveling)
            Button {
                model.showBatchSheet = true
            } label: {
                Image(systemName: "square.and.arrow.down.on.square")
            }
            .help("Batch Append")
            .disabled(model.isTimeTraveling)
            Button {
                Task { await model.loadEvents() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    // MARK: - Content

    @ViewBuilder
    private func content(_ model: EventFeatureModel) -> some View {
        LoadingErrorEmptyView(
            isLoading: model.isLoading,
            errorMessage: model.errorMessage,
            isEmpty: model.events.isEmpty,
            emptyIcon: "list.bullet.clipboard",
            emptyText: "No events in log"
        ) {
            List(model.events) { event in
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

    // MARK: - Append Form Sheet

    @ViewBuilder
    private func appendFormSheet(model: EventFeatureModel) -> some View {
        VStack(spacing: 16) {
            Text("Append Event")
                .font(.headline)

            TextField("Event Type", text: Binding(
                get: { model.formEventType },
                set: { model.formEventType = $0 }
            ))
            .textFieldStyle(.roundedBorder)

            Text("Payload (Strata Value JSON)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextEditor(text: Binding(
                get: { model.formPayload },
                set: { model.formPayload = $0 }
            ))
            .font(.system(.body, design: .monospaced))
            .frame(minHeight: 100)
            .border(Color.secondary.opacity(0.3))

            HStack {
                Button("Cancel") {
                    model.showAppendSheet = false
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Append") {
                    Task {
                        await model.appendEvent()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(model.formEventType.isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 400)
    }
}
