//
//  KVStoreView.swift
//  StrataFoundry
//
//  Thin view observing KVFeatureModel — all business logic delegated to model.
//

import SwiftUI

struct KVStoreView: View {
    @Environment(AppState.self) private var appState
    @State private var model: KVFeatureModel?

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
    private var kvToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    model?.showAddSheet = true
                } label: {
                    Label("Add Key", systemImage: "plus")
                }
                Button {
                    model?.showBatchSheet = true
                } label: {
                    Label("Batch Import", systemImage: "square.and.arrow.down.on.square")
                }
            } label: {
                Label("Add Key", systemImage: "plus")
            } primaryAction: {
                model?.showAddSheet = true
            }
            .help("Add Key")
            .disabled(model?.isTimeTraveling ?? true)
        }

        ToolbarItem(placement: .automatic) {
            Button {
                Task { await model?.loadEntries() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .help("Refresh")
        }
    }

    var body: some View {
        mainContent
            .navigationTitle("KV Store")
            .navigationSubtitle(model.map { "\($0.filteredEntries.count) keys" } ?? "")
            .searchable(text: filterBinding, prompt: "Filter keys...")
            .toolbar { kvToolbar }
            .background {
                Button("") { withAnimation { model?.showInspector.toggle() } }
                    .keyboardShortcut("i", modifiers: [.command, .control])
                    .hidden()
            }
            .task(id: appState.reloadToken) {
                if model == nil, let services = appState.services {
                    model = KVFeatureModel(kvService: services.kvService, appState: appState)
                }
                await model?.loadEntries()
            }
            .sheet(item: Binding(
                get: { model?.historyEntry },
                set: { model?.historyEntry = $0 }
            )) { entry in
                VersionHistoryView(primitive: "Kv", key: entry.key)
                    .environment(appState)
                    .frame(minWidth: 400, minHeight: 300)
            }
            .sheet(isPresented: Binding(
                get: { model?.showAddSheet ?? false },
                set: { model?.showAddSheet = $0 }
            ), onDismiss: { model?.clearForm() }) {
                if let model {
                    kvFormSheet(model: model, isEditing: false)
                }
            }
            .sheet(item: Binding(
                get: { model?.editingEntry },
                set: { model?.editingEntry = $0 }
            ), onDismiss: { model?.clearForm() }) { entry in
                if let model {
                    kvFormSheet(model: model, isEditing: true)
                        .onAppear {
                            model.prepareEditForm(for: entry)
                        }
                }
            }
            .sheet(isPresented: Binding(
                get: { model?.showBatchSheet ?? false },
                set: { model?.showBatchSheet = $0 }
            )) {
                if let model {
                    BatchImportSheet(
                        title: "Batch Import (KvBatchPut)",
                        placeholder: "JSON array of {\"key\": \"...\", \"value\": {...}} objects"
                    ) { jsonText in
                        await model.batchImport(jsonText: jsonText)
                    } onDismiss: {
                        model.showBatchSheet = false
                    }
                }
            }
            .alert("Delete Key", isPresented: Binding(
                get: { model?.showDeleteConfirm ?? false },
                set: { model?.showDeleteConfirm = $0 }
            )) {
                Button("Cancel", role: .cancel) { model?.entryToDelete = nil }
                Button("Delete", role: .destructive) {
                    if let entry = model?.entryToDelete {
                        Task { await model?.deleteKey(entry.key) }
                    }
                }
            } message: {
                if let entry = model?.entryToDelete {
                    Text("Delete key \"\(entry.key)\"? This cannot be undone.")
                }
            }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(_ model: KVFeatureModel) -> some View {
        LoadingErrorEmptyView(
            isLoading: model.isLoading,
            errorMessage: model.errorMessage,
            isEmpty: model.entries.isEmpty,
            emptyIcon: "tray",
            emptyText: "No keys in KV store"
        ) {
            Table(
                model.filteredEntries,
                selection: Binding(
                    get: { model.selectedEntryId },
                    set: { model.selectedEntryId = $0 }
                ),
                sortOrder: Binding(
                    get: { model.sortOrder },
                    set: { model.sortOrder = $0 }
                )
            ) {
                TableColumn("Key", value: \.key) { entry in
                    Text(entry.key).strataKeyStyle()
                }
                .width(min: 120, ideal: 200)

                TableColumn("Value") { entry in
                    Text(entry.displayValue)
                        .strataSecondaryStyle()
                        .lineLimit(1)
                }
                .width(min: 150, ideal: 300)

                TableColumn("Type", value: \.typeTag) { entry in
                    Text(entry.typeTag).strataBadgeStyle()
                }
                .width(60)

                TableColumn("Version") { entry in
                    Text("v\(entry.version)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .width(50)
            }
            .contextMenu(forSelectionType: KVEntryDisplay.ID.self) { ids in
                if let id = ids.first, let entry = model.entries.first(where: { $0.id == id }) {
                    Button("Edit") {
                        model.editingEntry = entry
                    }
                    .disabled(model.isTimeTraveling)
                    Button("Version History") {
                        model.historyEntry = entry
                    }
                    Divider()
                    Button("Delete", role: .destructive) {
                        model.entryToDelete = entry
                        model.showDeleteConfirm = true
                    }
                    .disabled(model.isTimeTraveling)
                }
            }
            .inspector(isPresented: Binding(
                get: { model.showInspector },
                set: { model.showInspector = $0 }
            )) {
                kvInspector(model)
                    .inspectorColumnWidth(min: 280, ideal: 320, max: 400)
            }
        }
    }

    // MARK: - Inspector

    @ViewBuilder
    private func kvInspector(_ model: KVFeatureModel) -> some View {
        if let entry = model.selectedEntry {
            ScrollView {
                VStack(alignment: .leading, spacing: StrataSpacing.md) {
                    Text("Key Details")
                        .strataSectionHeader()

                    LabeledContent("Key") {
                        Text(entry.key).strataKeyStyle()
                    }
                    LabeledContent("Type") {
                        Text(entry.typeTag).strataBadgeStyle()
                    }
                    LabeledContent("Version") {
                        Text("v\(entry.version)")
                    }

                    Divider()

                    Text("Value")
                        .strataSectionHeader()
                    Text(entry.displayValue)
                        .strataCodeStyle()
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(StrataSpacing.xs)
                        .background(.quaternary.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: StrataRadius.sm))

                    Divider()

                    HStack(spacing: StrataSpacing.sm) {
                        Button {
                            model.editingEntry = entry
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .disabled(model.isTimeTraveling)

                        Button {
                            model.historyEntry = entry
                        } label: {
                            Label("History", systemImage: "clock.arrow.circlepath")
                        }
                    }
                }
                .padding(StrataSpacing.md)
            }
        } else {
            EmptyStateView(
                icon: "sidebar.trailing",
                title: "No Selection",
                subtitle: "Select a key to inspect"
            )
        }
    }

    // MARK: - Form Sheet

    @ViewBuilder
    private func kvFormSheet(model: KVFeatureModel, isEditing: Bool) -> some View {
        Form {
            Section("Key") {
                TextField("Key", text: Binding(
                    get: { model.formKey },
                    set: { model.formKey = $0 }
                ))
                .disabled(isEditing)
            }
            Section("Value") {
                StrataValueEditor(
                    valueText: Binding(
                        get: { model.formValue },
                        set: { model.formValue = $0 }
                    ),
                    valueType: Binding(
                        get: { model.formValueType },
                        set: { model.formValueType = $0 }
                    )
                )
            }
        }
        .formStyle(.grouped)
        .navigationTitle(isEditing ? "Edit Key" : "Add Key")
        .frame(minWidth: StrataLayout.sheetMinWidth)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button("Cancel") {
                    model.showAddSheet = false
                    model.editingEntry = nil
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button(isEditing ? "Save" : "Add") {
                    Task {
                        await model.putKey()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(model.formKey.isEmpty)
            }
            .padding(StrataSpacing.lg)
        }
    }
}
