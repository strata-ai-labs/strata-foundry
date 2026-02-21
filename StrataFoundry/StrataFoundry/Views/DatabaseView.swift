//
//  DatabaseView.swift
//  StrataFoundry
//
//  Main view after opening a database. Sidebar + content area.
//

import SwiftUI
import UniformTypeIdentifiers

enum Primitive: String, CaseIterable, Identifiable, Hashable {
    case kv = "KV Store"
    case state = "State Cells"
    case events = "Event Log"
    case json = "JSON Store"
    case vectors = "Vector Store"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .kv: return "key"
        case .state: return "memorychip"
        case .events: return "list.bullet.clipboard"
        case .json: return "doc.text"
        case .vectors: return "arrow.trianglehead.branch"
        }
    }
}

enum SidebarSelection: Hashable {
    case info
    case primitive(space: String, primitive: Primitive)
}

struct DatabaseView: View {
    @Environment(AppState.self) private var appState
    @State private var selection: SidebarSelection? = .info
    @State private var showCreateSpaceSheet = false
    @State private var showDeleteSpaceConfirm = false
    @State private var newSpaceName = ""
    @State private var forceDeleteSpace = false
    @State private var spaceError: String?

    // Branch create/delete
    @State private var showCreateBranchSheet = false
    @State private var showDeleteBranchConfirm = false
    @State private var newBranchName = ""
    @State private var branchError: String?

    // Import/Export
    @State private var showExportResult: BranchExportResult?
    @State private var showImportResult: BranchImportResult?
    @State private var showValidateResult: BundleValidateResult?
    @State private var isBranchOperationInProgress = false

    var body: some View {
        @Bindable var appState = appState
        NavigationSplitView {
            List(selection: $selection) {
                Label("Database Info", systemImage: "info.circle")
                    .tag(SidebarSelection.info)

                ForEach(appState.spaces, id: \.self) { space in
                    Section(space) {
                        ForEach(Primitive.allCases) { prim in
                            Label(prim.rawValue, systemImage: prim.icon)
                                .tag(SidebarSelection.primitive(space: space, primitive: prim))
                        }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .toolbar(removing: .sidebarToggle)
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Button {
                        newSpaceName = ""
                        spaceError = nil
                        showCreateSpaceSheet = true
                    } label: {
                        Label("New Space", systemImage: "plus")
                    }
                    .disabled(appState.timeTravelDate != nil)

                    Spacer()

                    Button {
                        forceDeleteSpace = false
                        showDeleteSpaceConfirm = true
                    } label: {
                        Label("Delete Space", systemImage: "trash")
                    }
                    .disabled(appState.selectedSpace == "default" || appState.timeTravelDate != nil)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .sheet(isPresented: $showCreateSpaceSheet) {
                VStack(spacing: 12) {
                    Text("New Space").font(.headline)
                    TextField("Space name", text: $newSpaceName)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 200)
                    if let spaceError {
                        Text(spaceError)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                    HStack {
                        Button("Cancel") {
                            showCreateSpaceSheet = false
                        }
                        .keyboardShortcut(.cancelAction)
                        Button("Create") {
                            Task {
                                do {
                                    try await appState.createSpace(newSpaceName)
                                    showCreateSpaceSheet = false
                                } catch {
                                    spaceError = error.localizedDescription
                                }
                            }
                        }
                        .keyboardShortcut(.defaultAction)
                        .disabled(newSpaceName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding()
            }
            .alert("Delete Space", isPresented: $showDeleteSpaceConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    let spaceName = appState.selectedSpace
                    Task {
                        do {
                            try await appState.deleteSpace(spaceName, force: true)
                            selection = .info
                        } catch {
                            appState.errorMessage = error.localizedDescription
                        }
                    }
                }
            } message: {
                Text("Are you sure you want to delete the space \"\(appState.selectedSpace)\"? This cannot be undone.")
            }
        } detail: {
            switch selection {
            case .info, nil:
                DatabaseInfoView()
            case .primitive(_, let prim):
                switch prim {
                case .kv:
                    KVStoreView()
                case .state:
                    StateCellsView()
                case .events:
                    EventLogView()
                case .json:
                    JsonStoreView()
                case .vectors:
                    VectorStoreView()
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Picker("Branch", selection: $appState.selectedBranch) {
                    ForEach(appState.branches, id: \.self) { branch in
                        Text(branch).tag(branch)
                    }
                }
                .pickerStyle(.menu)
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    newBranchName = ""
                    branchError = nil
                    showCreateBranchSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Create branch")
                .disabled(appState.timeTravelDate != nil)
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    showDeleteBranchConfirm = true
                } label: {
                    Image(systemName: "trash")
                }
                .help("Delete branch")
                .disabled(appState.selectedBranch == "default" || appState.timeTravelDate != nil)
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    exportBranchPanel()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .help("Export branch")
                .disabled(appState.timeTravelDate != nil || isBranchOperationInProgress)
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    importBranchPanel()
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .help("Import branch")
                .disabled(appState.timeTravelDate != nil || isBranchOperationInProgress)
            }

            ToolbarItem(placement: .automatic) {
                if appState.timeTravelDate != nil {
                    HStack(spacing: 6) {
                        DatePicker(
                            "As of",
                            selection: Binding(
                                get: { appState.timeTravelDate ?? Date() },
                                set: { appState.timeTravelDate = $0 }
                            ),
                            in: (appState.timeRangeOldest ?? .distantPast)...(appState.timeRangeLatest ?? Date()),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .labelsHidden()

                        Button {
                            appState.timeTravelDate = nil
                        } label: {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 8, height: 8)
                                Text("Live")
                            }
                        }
                        .help("Return to live data")
                    }
                } else {
                    Button {
                        appState.timeTravelDate = appState.timeRangeLatest ?? Date()
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .help("Enable time travel")
                }
            }
        }
        .navigationTitle(appState.databaseName)
        .onChange(of: selection) {
            if case .primitive(let space, _) = selection {
                appState.selectedSpace = space
            }
        }
        .onChange(of: appState.selectedBranch) {
            selection = .info
            appState.selectedSpace = "default"
            Task { await appState.loadSpaces() }
        }
        .sheet(isPresented: $showCreateBranchSheet) {
            VStack(spacing: 12) {
                Text("New Branch").font(.headline)
                TextField("Branch name", text: $newBranchName)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 200)
                if let branchError {
                    Text(branchError)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
                HStack {
                    Button("Cancel") {
                        showCreateBranchSheet = false
                    }
                    .keyboardShortcut(.cancelAction)
                    Button("Create") {
                        Task {
                            do {
                                try await appState.createBranch(newBranchName)
                                showCreateBranchSheet = false
                            } catch {
                                branchError = error.localizedDescription
                            }
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(newBranchName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding()
        }
        .alert("Delete Branch", isPresented: $showDeleteBranchConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                let branchName = appState.selectedBranch
                Task {
                    do {
                        try await appState.deleteBranch(branchName)
                        selection = .info
                    } catch {
                        appState.errorMessage = error.localizedDescription
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete the branch \"\(appState.selectedBranch)\"? This cannot be undone.")
        }
        .alert("Branch Exported",
               isPresented: Binding(
                   get: { showExportResult != nil },
                   set: { if !$0 { showExportResult = nil } }
               )) {
            Button("OK") { showExportResult = nil }
        } message: {
            if let result = showExportResult {
                Text("Branch: \(result.branchId)\nEntries: \(result.entryCount)\nBundle size: \(result.bundleSize) bytes")
            }
        }
        .alert("Branch Imported",
               isPresented: Binding(
                   get: { showImportResult != nil },
                   set: { if !$0 { showImportResult = nil } }
               )) {
            Button("OK") { showImportResult = nil }
        } message: {
            if let result = showImportResult {
                Text("Branch: \(result.branchId)\nTransactions applied: \(result.transactionsApplied)\nKeys written: \(result.keysWritten)")
            }
        }
        .alert("Bundle Validation",
               isPresented: Binding(
                   get: { showValidateResult != nil },
                   set: { if !$0 { showValidateResult = nil } }
               )) {
            Button("OK") { showValidateResult = nil }
        } message: {
            if let result = showValidateResult {
                Text("Branch: \(result.branchId)\nFormat version: \(result.formatVersion)\nEntries: \(result.entryCount)\nChecksums valid: \(result.checksumsValid ? "Yes" : "No")")
            }
        }
    }

    private func exportBranchPanel() {
        let branch = appState.selectedBranch
        DispatchQueue.main.async {
            let panel = NSSavePanel()
            panel.title = "Export Branch"
            panel.nameFieldStringValue = "\(branch).branchbundle.tar.zst"
            panel.allowedContentTypes = [.data]
            if panel.runModal() == .OK, let url = panel.url {
                isBranchOperationInProgress = true
                Task {
                    defer { isBranchOperationInProgress = false }
                    do {
                        let result = try await appState.exportBranch(branch, to: url.path)
                        showExportResult = result
                    } catch {
                        appState.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    private func importBranchPanel() {
        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.title = "Import Branch Bundle"
            panel.allowedContentTypes = [.data]
            panel.allowsMultipleSelection = false
            if panel.runModal() == .OK, let url = panel.url {
                isBranchOperationInProgress = true
                Task {
                    defer { isBranchOperationInProgress = false }
                    do {
                        let result = try await appState.importBranch(from: url.path)
                        showImportResult = result
                    } catch {
                        appState.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
}
