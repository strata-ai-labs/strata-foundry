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

    // MARK: - Toolbar

    @ViewBuilder
    private func toolbar(_ model: StateFeatureModel) -> some View {
        HStack {
            Text("State Cells")
                .font(.title2)
                .fontWeight(.semibold)
            Spacer()
            Text("\(model.cells.count) cells")
                .foregroundStyle(.secondary)
            Button {
                model.showAddSheet = true
            } label: {
                Image(systemName: "plus")
            }
            .help("Add Cell")
            .disabled(model.isTimeTraveling)
            Button {
                model.showBatchSheet = true
            } label: {
                Image(systemName: "square.and.arrow.down.on.square")
            }
            .help("Batch Import")
            .disabled(model.isTimeTraveling)
            Button {
                if let cell = model.selectedCell {
                    model.cellToDelete = cell
                    model.showDeleteConfirm = true
                }
            } label: {
                Image(systemName: "trash")
            }
            .help("Delete Cell")
            .disabled(model.isTimeTraveling || model.selectedCell == nil)
            Button {
                Task { await model.loadCells() }
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
    private func content(_ model: StateFeatureModel) -> some View {
        LoadingErrorEmptyView(
            isLoading: model.isLoading,
            errorMessage: model.errorMessage,
            isEmpty: model.cells.isEmpty,
            emptyIcon: "memorychip",
            emptyText: "No state cells"
        ) {
            List(model.cells, selection: Binding(
                get: { model.selectedCell },
                set: { model.selectedCell = $0 }
            )) { cell in
                HStack(spacing: 12) {
                    Text(cell.name)
                        .font(.system(.body, design: .monospaced))
                        .frame(minWidth: 180, alignment: .leading)
                    Text(cell.displayValue)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Text(cell.typeTag)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    Text("v\(cell.version)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .tag(cell)
                .contentShape(Rectangle())
                .onTapGesture {
                    model.selectedCell = cell
                }
                .contextMenu {
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
        }
    }

    // MARK: - Form Sheet

    @ViewBuilder
    private func cellFormSheet(model: StateFeatureModel, isEditing: Bool) -> some View {
        VStack(spacing: 16) {
            Text(isEditing ? "Edit Cell" : "Add Cell")
                .font(.headline)

            TextField("Cell Name", text: Binding(
                get: { model.formCell },
                set: { model.formCell = $0 }
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
                .disabled(model.formCell.isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 350)
    }
}
