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
    private var jsonToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    model?.prepareAddForm()
                    model?.showAddSheet = true
                } label: {
                    Label("Add Document", systemImage: "plus")
                }
                Button {
                    model?.showBatchSheet = true
                } label: {
                    Label("Batch Import", systemImage: "square.and.arrow.down.on.square")
                }
            } label: {
                Label("Add Document", systemImage: "plus")
            } primaryAction: {
                model?.prepareAddForm()
                model?.showAddSheet = true
            }
            .help("Add Document")
            .disabled(model?.isTimeTraveling ?? true)
        }

        ToolbarItem(placement: .automatic) {
            Button {
                Task { await model?.loadKeys() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .help("Refresh")
        }
    }

    var body: some View {
        mainContent
            .navigationTitle("JSON Store")
            .navigationSubtitle(model.map { "\($0.keys.count) documents" } ?? "")
            .searchable(text: filterBinding, prompt: "Filter documents...")
            .toolbar { jsonToolbar }
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
                List(model.filteredKeys, id: \.self, selection: Binding(
                    get: { model.selectedKey },
                    set: { model.selectedKey = $0 }
                )) { key in
                    Text(key)
                        .strataKeyStyle()
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
                            .padding(StrataSpacing.xs)
                        }
                        Divider()
                    }

                    if model.showHistory, let key = model.selectedKey {
                        VersionHistoryView(primitive: "Json", key: key)
                    } else {
                        ScrollView {
                            if model.documentJSON.isEmpty {
                                EmptyStateView(
                                    icon: "doc.text",
                                    title: "Select a document"
                                )
                            } else {
                                Text(model.documentJSON)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .textSelection(.enabled)
                                    .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
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
        Form {
            Section("Document") {
                TextField("Key", text: Binding(
                    get: { model.formKey },
                    set: { model.formKey = $0 }
                ))
                .disabled(isEditing)
            }
            Section("Value (Strata Value JSON)") {
                TextEditor(text: Binding(
                    get: { model.formJSON },
                    set: { model.formJSON = $0 }
                ))
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 200)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(isEditing ? "Edit Document" : "Add Document")
        .frame(minWidth: StrataLayout.sheetMinWidth, minHeight: 350)
        .safeAreaInset(edge: .bottom) {
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
                .buttonStyle(.borderedProminent)
                .disabled(model.formKey.isEmpty || model.formJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(StrataSpacing.lg)
        }
    }
}
