//
//  JsonStoreView.swift
//  StrataFoundry
//
//  Thin view observing JsonFeatureModel — all business logic delegated to model.
//

import SwiftUI

struct JsonStoreView: View {
    @Environment(AppState.self) private var appState
    @State private var model: JsonFeatureModel?

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
                model = JsonFeatureModel(jsonService: services.jsonService, appState: appState)
            }
            await model?.loadKeys()
        }
        .onChange(of: model?.selectedKey) { _, newKey in
            model?.onSelectKey(newKey)
        }
        .sheet(isPresented: Binding(
            get: { model?.showAddSheet ?? false },
            set: { model?.showAddSheet = $0 }
        )) {
            if let model {
                jsonFormSheet(model: model, isEditing: false)
            }
        }
        .sheet(isPresented: Binding(
            get: { model?.showEditSheet ?? false },
            set: { model?.showEditSheet = $0 }
        )) {
            if let model {
                jsonFormSheet(model: model, isEditing: true)
            }
        }
        .sheet(isPresented: Binding(
            get: { model?.showBatchSheet ?? false },
            set: { model?.showBatchSheet = $0 }
        )) {
            if let model {
                BatchImportSheet(
                    title: "Batch Import (JsonBatchSet)",
                    placeholder: "JSON array of {\"key\": \"...\", \"path\": \"$\", \"value\": {...}} objects"
                ) { jsonText in
                    await model.batchImport(jsonText: jsonText)
                } onDismiss: {
                    model.showBatchSheet = false
                }
            }
        }
        .alert("Delete Document", isPresented: Binding(
            get: { model?.showDeleteConfirm ?? false },
            set: { model?.showDeleteConfirm = $0 }
        )) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let key = model?.selectedKey {
                    Task { await model?.deleteDocument(key) }
                }
            }
        } message: {
            if let key = model?.selectedKey {
                Text("Delete document \"\(key)\"? This cannot be undone.")
            }
        }
    }

    // MARK: - Toolbar

    @ViewBuilder
    private func toolbar(_ model: JsonFeatureModel) -> some View {
        HStack {
            Text("JSON Store")
                .font(.title2)
                .fontWeight(.semibold)
            Spacer()
            Text("\(model.keys.count) documents")
                .foregroundStyle(.secondary)
            Button {
                model.prepareAddForm()
                model.showAddSheet = true
            } label: {
                Image(systemName: "plus")
            }
            .help("Add Document")
            .disabled(model.isTimeTraveling)
            Button {
                model.showBatchSheet = true
            } label: {
                Image(systemName: "square.and.arrow.down.on.square")
            }
            .help("Batch Import")
            .disabled(model.isTimeTraveling)
            Button {
                model.showDeleteConfirm = true
            } label: {
                Image(systemName: "trash")
            }
            .help("Delete Document")
            .disabled(model.isTimeTraveling || model.selectedKey == nil)
            Button {
                Task { await model.loadKeys() }
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
    private func content(_ model: JsonFeatureModel) -> some View {
        LoadingErrorEmptyView(
            isLoading: model.isLoading,
            errorMessage: model.errorMessage,
            isEmpty: model.keys.isEmpty,
            emptyIcon: "doc.text",
            emptyText: "No JSON documents"
        ) {
            HSplitView {
                List(model.keys, id: \.self, selection: Binding(
                    get: { model.selectedKey },
                    set: { model.selectedKey = $0 }
                )) { key in
                    Text(key)
                        .font(.system(.body, design: .monospaced))
                }
                .frame(minWidth: 150, idealWidth: 200)

                VStack(spacing: 0) {
                    if model.selectedKey != nil {
                        HStack {
                            Spacer()
                            Button {
                                model.prepareEditForm()
                                model.showEditSheet = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .buttonStyle(.borderless)
                            .disabled(model.isTimeTraveling)
                            Button {
                                model.showHistory.toggle()
                            } label: {
                                Label(model.showHistory ? "Document" : "History",
                                      systemImage: model.showHistory ? "doc.text" : "clock.arrow.circlepath")
                            }
                            .buttonStyle(.borderless)
                            .padding(8)
                        }
                        Divider()
                    }

                    if model.showHistory, let key = model.selectedKey {
                        VersionHistoryView(primitive: "Json", key: key)
                    } else {
                        ScrollView {
                            if model.documentJSON.isEmpty {
                                Text("Select a document")
                                    .foregroundStyle(.secondary)
                                    .padding()
                            } else {
                                Text(model.documentJSON)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Form Sheet

    @ViewBuilder
    private func jsonFormSheet(model: JsonFeatureModel, isEditing: Bool) -> some View {
        VStack(spacing: 16) {
            Text(isEditing ? "Edit Document" : "Add Document")
                .font(.headline)

            TextField("Key", text: Binding(
                get: { model.formKey },
                set: { model.formKey = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .disabled(isEditing)

            Text("Value (Strata Value JSON)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextEditor(text: Binding(
                get: { model.formJSON },
                set: { model.formJSON = $0 }
            ))
            .font(.system(.body, design: .monospaced))
            .frame(minHeight: 200)
            .border(Color.secondary.opacity(0.3))

            HStack {
                Button("Cancel") {
                    model.showAddSheet = false
                    model.showEditSheet = false
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button(isEditing ? "Save" : "Add") {
                    Task {
                        await model.setDocument()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(model.formKey.isEmpty || model.formJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 450, minHeight: 350)
    }
}
