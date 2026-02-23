//
//  StateCellsView.swift
//  StrataFoundry
//
//  Thin view observing StateFeatureModel — all business logic delegated to model.
//

import SwiftUI

struct StateCellsView: View {
    @Environment(AppState.self) private var appState
    @State private var model: StateFeatureModel?

    @ToolbarContentBuilder
    private var stateToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    model?.showAddSheet = true
                } label: {
                    Label("Add Cell", systemImage: "plus")
                }
                Button {
                    model?.showBatchSheet = true
                } label: {
                    Label("Batch Import", systemImage: "square.and.arrow.down.on.square")
                }
            } label: {
                Label("Add Cell", systemImage: "plus")
            } primaryAction: {
                model?.showAddSheet = true
            }
            .help("Add Cell")
            .disabled(model?.isTimeTraveling ?? true)
        }

        ToolbarItem(placement: .automatic) {
            Button {
                Task { await model?.loadCells() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .help("Refresh")
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if let model {
            content(model)
        } else {
            SkeletonLoadingView()
        }
    }

    var body: some View {
        mainContent
            .navigationTitle("State Cells")
            .navigationSubtitle(model.map { "\($0.cells.count) cells" } ?? "")
            .toolbar { stateToolbar }
            .background {
                Button("") { withAnimation { model?.showInspector.toggle() } }
                    .keyboardShortcut("i", modifiers: [.command, .control])
                    .hidden()
            }
            .task(id: appState.reloadToken) {
                if model == nil, let services = appState.services {
                    model = StateFeatureModel(stateService: services.stateService, appState: appState)
                }
                await model?.loadCells()
            }
            .sheet(item: Binding(
                get: { model?.historyCell },
                set: { model?.historyCell = $0 }
            )) { cell in
                VersionHistoryView(primitive: "State", key: cell.name)
                    .environment(appState)
                    .frame(minWidth: 400, minHeight: 300)
            }
            .sheet(isPresented: Binding(
                get: { model?.showAddSheet ?? false },
                set: { model?.showAddSheet = $0 }
            ), onDismiss: { model?.clearForm() }) {
                if let model {
                    cellFormSheet(model: model, isEditing: false)
                }
            }
            .sheet(item: Binding(
                get: { model?.editingCell },
                set: { model?.editingCell = $0 }
            ), onDismiss: { model?.clearForm() }) { cell in
                if let model {
                    cellFormSheet(model: model, isEditing: true)
                        .onAppear {
                            model.prepareEditForm(for: cell)
                        }
                }
            }
            .sheet(isPresented: Binding(
                get: { model?.showBatchSheet ?? false },
                set: { model?.showBatchSheet = $0 }
            )) {
                if let model {
                    BatchImportSheet(
                        title: "Batch Import (StateBatchSet)",
                        placeholder: "JSON array of {\"cell\": \"...\", \"value\": {...}} objects"
                    ) { jsonText in
                        await model.batchImport(jsonText: jsonText)
                    } onDismiss: {
                        model.showBatchSheet = false
                    }
                }
            }
            .alert("Delete Cell", isPresented: Binding(
                get: { model?.showDeleteConfirm ?? false },
                set: { model?.showDeleteConfirm = $0 }
            )) {
                Button("Cancel", role: .cancel) { model?.cellToDelete = nil }
                Button("Delete", role: .destructive) {
                    if let cell = model?.cellToDelete {
                        Task { await model?.deleteCell(cell.name) }
                    }
                }
            } message: {
                if let cell = model?.cellToDelete {
                    Text("Delete cell \"\(cell.name)\"? This cannot be undone.")
                }
            }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(_ model: StateFeatureModel) -> some View {
        LoadingErrorEmptyView(
            isLoading: model.isLoading,
            errorMessage: model.errorMessage,
            isEmpty: model.cells.isEmpty,
            emptyIcon: "memorychip",
            emptyText: "No state cells"
        ) {
            Table(
                model.sortedCells,
                selection: Binding(
                    get: { model.selectedCellId },
                    set: { model.selectedCellId = $0 }
                ),
                sortOrder: Binding(
                    get: { model.sortOrder },
                    set: { model.sortOrder = $0 }
                )
            ) {
                TableColumn("Name", value: \.name) { cell in
                    Text(cell.name).strataKeyStyle()
                }
                .width(min: 120, ideal: 200)

                TableColumn("Value") { cell in
                    Text(cell.displayValue)
                        .strataSecondaryStyle()
                        .lineLimit(1)
                }
                .width(min: 150, ideal: 300)

                TableColumn("Type", value: \.typeTag) { cell in
                    Text(cell.typeTag).strataBadgeStyle()
                }
                .width(60)

                TableColumn("Version") { cell in
                    Text("v\(cell.version)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .width(50)
            }
            .contextMenu(forSelectionType: StateCellDisplay.ID.self) { ids in
                if let id = ids.first, let cell = model.cells.first(where: { $0.id == id }) {
                    Button("Edit") {
                        model.editingCell = cell
                    }
                    .disabled(model.isTimeTraveling)
                    Button("Version History") {
                        model.historyCell = cell
                    }
                    Divider()
                    Button("Delete", role: .destructive) {
                        model.cellToDelete = cell
                        model.showDeleteConfirm = true
                    }
                    .disabled(model.isTimeTraveling)
                }
            }
            .inspector(isPresented: Binding(
                get: { model.showInspector },
                set: { model.showInspector = $0 }
            )) {
                stateInspector(model)
                    .inspectorColumnWidth(min: 280, ideal: 320, max: 400)
            }
        }
    }

    // MARK: - Inspector

    @ViewBuilder
    private func stateInspector(_ model: StateFeatureModel) -> some View {
        if let cell = model.selectedCell {
            ScrollView {
                VStack(alignment: .leading, spacing: StrataSpacing.md) {
                    Text("Cell Details")
                        .strataSectionHeader()

                    LabeledContent("Name") {
                        Text(cell.name).strataKeyStyle()
                    }
                    LabeledContent("Type") {
                        Text(cell.typeTag).strataBadgeStyle()
                    }
                    LabeledContent("Version") {
                        Text("v\(cell.version)")
                    }

                    Divider()

                    Text("Value")
                        .strataSectionHeader()
                    Text(cell.displayValue)
                        .strataCodeStyle()
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(StrataSpacing.xs)
                        .background(.quaternary.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: StrataRadius.sm))

                    Divider()

                    HStack(spacing: StrataSpacing.sm) {
                        Button {
                            model.editingCell = cell
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .disabled(model.isTimeTraveling)

                        Button {
                            model.historyCell = cell
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
                subtitle: "Select a cell to inspect"
            )
        }
    }

    // MARK: - Form Sheet

    @ViewBuilder
    private func cellFormSheet(model: StateFeatureModel, isEditing: Bool) -> some View {
        Form {
            Section("Cell") {
                TextField("Cell Name", text: Binding(
                    get: { model.formCell },
                    set: { model.formCell = $0 }
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
        .navigationTitle(isEditing ? "Edit Cell" : "Add Cell")
        .frame(minWidth: StrataLayout.sheetMinWidth)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button("Cancel") {
                    model.showAddSheet = false
                    model.editingCell = nil
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button(isEditing ? "Save" : "Add") {
                    Task {
                        await model.setCell()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(model.formCell.isEmpty)
            }
            .padding(StrataSpacing.lg)
        }
    }
}
