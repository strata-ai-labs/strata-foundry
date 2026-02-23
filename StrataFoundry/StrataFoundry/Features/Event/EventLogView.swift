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

    private var filterBinding: Binding<String> {
        Binding(
            get: { model?.filterText ?? "" },
            set: { model?.filterText = $0 }
        )
    }

    @ViewBuilder
    private var mainContent: some View {
        if let model {
            content(model)
        } else {
            SkeletonLoadingView()
        }
    }

    @ToolbarContentBuilder
    private var eventToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    model?.showAppendSheet = true
                } label: {
                    Label("Append Event", systemImage: "plus")
                }
                Button {
                    model?.showBatchSheet = true
                } label: {
                    Label("Batch Append", systemImage: "square.and.arrow.down.on.square")
                }
            } label: {
                Label("Append Event", systemImage: "plus")
            } primaryAction: {
                model?.showAppendSheet = true
            }
            .help("Append Event")
            .disabled(model?.isTimeTraveling ?? true)
        }

        ToolbarItem(placement: .automatic) {
            Button {
                Task { await model?.loadEvents() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .help("Refresh")
        }
    }

    var body: some View {
        mainContent
            .navigationTitle("Event Log")
            .navigationSubtitle(model.map { "\($0.eventCount) events" } ?? "")
            .searchable(text: filterBinding, prompt: "Filter by event type...")
            .toolbar { eventToolbar }
            .background {
                Button("") { withAnimation { model?.showInspector.toggle() } }
                    .keyboardShortcut("i", modifiers: [.command, .control])
                    .hidden()
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
            Table(
                model.filteredEvents,
                selection: Binding(
                    get: { model.selectedEventId },
                    set: { model.selectedEventId = $0 }
                )
            ) {
                TableColumn("Seq") { event in
                    Text("#\(event.sequence)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                .width(40)

                TableColumn("Type") { event in
                    Text(event.eventType)
                        .strataKeyStyle()
                }
                .width(min: 80, ideal: 120)

                TableColumn("Summary") { event in
                    Text(event.summary)
                        .strataSecondaryStyle()
                        .lineLimit(2)
                }
                .width(min: 200, ideal: 400)

                TableColumn("Timestamp") { event in
                    Text(event.timestamp > 0 ? formatTimestampShort(event.timestamp) : "")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .width(min: 100, ideal: 140)
            }
            .inspector(isPresented: Binding(
                get: { model.showInspector },
                set: { model.showInspector = $0 }
            )) {
                eventInspector(model)
                    .inspectorColumnWidth(min: 280, ideal: 320, max: 400)
            }
        }
    }

    // MARK: - Inspector

    @ViewBuilder
    private func eventInspector(_ model: EventFeatureModel) -> some View {
        if let event = model.selectedEvent {
            ScrollView {
                VStack(alignment: .leading, spacing: StrataSpacing.md) {
                    Text("Event Details")
                        .strataSectionHeader()

                    LabeledContent("Sequence") {
                        Text("#\(event.sequence)").strataKeyStyle()
                    }
                    LabeledContent("Type") {
                        Text(event.eventType).strataBadgeStyle()
                    }
                    if event.timestamp > 0 {
                        LabeledContent("Timestamp") {
                            Text(formatTimestampShort(event.timestamp))
                        }
                    }

                    Divider()

                    Text("Summary")
                        .strataSectionHeader()
                    Text(event.summary)
                        .strataCodeStyle()
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(StrataSpacing.xs)
                        .background(.quaternary.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: StrataRadius.sm))
                }
                .padding(StrataSpacing.md)
            }
        } else {
            EmptyStateView(
                icon: "sidebar.trailing",
                title: "No Selection",
                subtitle: "Select an event to inspect"
            )
        }
    }

    // MARK: - Append Form Sheet

    @ViewBuilder
    private func appendFormSheet(model: EventFeatureModel) -> some View {
        Form {
            Section("Event") {
                TextField("Event Type", text: Binding(
                    get: { model.formEventType },
                    set: { model.formEventType = $0 }
                ))
            }
            Section("Payload (Strata Value JSON)") {
                TextEditor(text: Binding(
                    get: { model.formPayload },
                    set: { model.formPayload = $0 }
                ))
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 100)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Append Event")
        .frame(minWidth: StrataLayout.sheetMinWidth)
        .safeAreaInset(edge: .bottom) {
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
                .buttonStyle(.borderedProminent)
                .disabled(model.formEventType.isEmpty)
            }
            .padding(StrataSpacing.lg)
        }
    }

    // MARK: - Helpers

    private func formatTimestampShort(_ micros: UInt64) -> String {
        let date = Date(timeIntervalSince1970: Double(micros) / 1_000_000.0)
        let fmt = DateFormatter()
        fmt.dateStyle = .short
        fmt.timeStyle = .medium
        return fmt.string(from: date)
    }
}
