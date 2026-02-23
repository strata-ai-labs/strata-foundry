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

    // MARK: - Toolbar

    @ViewBuilder
    private func toolbar(_ model: KVFeatureModel) -> some View {
        HStack {
            Text("KV Store")
                .font(.title2)
                .fontWeight(.semibold)
            Spacer()
            Text("\(model.filteredEntries.count) keys")
                .foregroundStyle(.secondary)
            TextField("Filter...", text: Binding(
                get: { model.filterText },
                set: { model.filterText = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 200)
            Button {
                model.showAddSheet = true
            } label: {
                Image(systemName: "plus")
            }
            .help("Add Key")
            .disabled(model.isTimeTraveling)
            Button {
                model.showBatchSheet = true
            } label: {
                Image(systemName: "square.and.arrow.down.on.square")
            }
            .help("Batch Import")
            .disabled(model.isTimeTraveling)
            Button {
                if let entry = model.selectedEntry {
                    model.entryToDelete = entry
                    model.showDeleteConfirm = true
                }
            } label: {
                Image(systemName: "trash")
            }
            .help("Delete Key")
            .disabled(model.isTimeTraveling || model.selectedEntry == nil)
            Button {
                Task { await model.loadEntries() }
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
    private func content(_ model: KVFeatureModel) -> some View {
        LoadingErrorEmptyView(
            isLoading: model.isLoading,
            errorMessage: model.errorMessage,
            isEmpty: model.entries.isEmpty,
            emptyIcon: "tray",
            emptyText: "No keys in KV store"
        ) {
            List(model.filteredEntries, selection: Binding(
                get: { model.selectedEntry },
                set: { model.selectedEntry = $0 }
            )) { entry in
                HStack(spacing: 12) {
                    Text(entry.key)
                        .font(.system(.body, design: .monospaced))
                        .frame(minWidth: 180, alignment: .leading)
                    Text(entry.displayValue)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Text(entry.typeTag)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    Text("v\(entry.version)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .tag(entry)
                .contentShape(Rectangle())
                .onTapGesture {
                    model.selectedEntry = entry
                }
                .contextMenu {
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
        }
    }

    // MARK: - Form Sheet

    @ViewBuilder
    private func kvFormSheet(model: KVFeatureModel, isEditing: Bool) -> some View {
        VStack(spacing: 16) {
            Text(isEditing ? "Edit Key" : "Add Key")
                .font(.headline)

            TextField("Key", text: Binding(
                get: { model.formKey },
                set: { model.formKey = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .disabled(isEditing)

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
                .disabled(model.formKey.isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 350)
    }
}
