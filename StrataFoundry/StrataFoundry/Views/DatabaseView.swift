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
    case graph = "Graph"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .kv: return "key"
        case .state: return "memorychip"
        case .events: return "list.bullet.clipboard"
        case .json: return "doc.text"
        case .vectors: return "arrow.trianglehead.branch"
        case .graph: return "circle.hexagongrid"
        }
    }
}

enum TopLevelItem: String, CaseIterable, Identifiable, Hashable {
    case search = "Search"
    case models = "Models"
    case generation = "Generation"
    case admin = "Admin"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .search: return "magnifyingglass"
        case .models: return "cpu"
        case .generation: return "text.bubble"
        case .admin: return "gearshape.2"
        }
    }
}

enum SidebarSelection: Hashable {
    case info
    case primitive(space: String, primitive: Primitive)
    case topLevel(TopLevelItem)
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

    // Branch Fork
    @State private var showForkSheet = false
    @State private var forkDestination = ""
    @State private var forkError: String?

    // Branch Diff
    @State private var showDiffSheet = false
    @State private var diffBranchA = ""
    @State private var diffBranchB = ""
    @State private var diffResult: String?
    @State private var diffError: String?

    // Branch Merge
    @State private var showMergeSheet = false
    @State private var mergeSource = ""
    @State private var mergeTarget = ""
    @State private var mergeStrategy = "source_wins"
    @State private var mergeError: String?
    @State private var mergeResult: String?

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

                Section("Tools") {
                    ForEach(TopLevelItem.allCases) { item in
                        Label(item.rawValue, systemImage: item.icon)
                            .tag(SidebarSelection.topLevel(item))
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
                case .graph:
                    GraphView()
                }
            case .topLevel(let item):
                switch item {
                case .search:
                    SearchView()
                case .models:
                    ModelsView()
                case .generation:
                    GenerationView()
                case .admin:
                    AdminView()
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

            // Branch Fork
            ToolbarItem(placement: .automatic) {
                Button {
                    forkDestination = ""
                    forkError = nil
                    showForkSheet = true
                } label: {
                    Image(systemName: "arrow.triangle.branch")
                }
                .help("Fork branch")
                .disabled(appState.timeTravelDate != nil)
            }

            // Branch Diff
            ToolbarItem(placement: .automatic) {
                Button {
                    diffBranchA = appState.selectedBranch
                    diffBranchB = appState.branches.first(where: { $0 != appState.selectedBranch }) ?? "default"
                    diffResult = nil
                    diffError = nil
                    showDiffSheet = true
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                }
                .help("Diff branches")
            }

            // Branch Merge
            ToolbarItem(placement: .automatic) {
                Button {
                    mergeSource = appState.selectedBranch
                    mergeTarget = appState.branches.first(where: { $0 != appState.selectedBranch }) ?? "default"
                    mergeStrategy = "source_wins"
                    mergeError = nil
                    mergeResult = nil
                    showMergeSheet = true
                } label: {
                    Image(systemName: "arrow.triangle.merge")
                }
                .help("Merge branches")
                .disabled(appState.timeTravelDate != nil || appState.branches.count < 2)
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
        // Fork sheet
        .sheet(isPresented: $showForkSheet) {
            VStack(spacing: 16) {
                Text("Fork Branch").font(.headline)
                LabeledContent("Source") {
                    Text(appState.selectedBranch)
                        .font(.system(.body, design: .monospaced))
                }
                TextField("Destination branch name", text: $forkDestination)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 250)
                if let forkError {
                    Text(forkError)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
                HStack {
                    Button("Cancel") {
                        showForkSheet = false
                    }
                    .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Fork") {
                        Task {
                            do {
                                try await appState.forkBranch(
                                    source: appState.selectedBranch,
                                    destination: forkDestination
                                )
                                showForkSheet = false
                            } catch {
                                forkError = error.localizedDescription
                            }
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(forkDestination.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(20)
            .frame(minWidth: 350)
        }
        // Diff sheet
        .sheet(isPresented: $showDiffSheet) {
            VStack(spacing: 16) {
                Text("Diff Branches").font(.headline)
                Picker("Branch A", selection: $diffBranchA) {
                    ForEach(appState.branches, id: \.self) { b in
                        Text(b).tag(b)
                    }
                }
                Picker("Branch B", selection: $diffBranchB) {
                    ForEach(appState.branches, id: \.self) { b in
                        Text(b).tag(b)
                    }
                }
                HStack {
                    Button("Cancel") {
                        showDiffSheet = false
                    }
                    .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Diff") {
                        Task {
                            do {
                                diffResult = try await appState.diffBranches(
                                    branchA: diffBranchA,
                                    branchB: diffBranchB
                                )
                            } catch {
                                diffError = error.localizedDescription
                            }
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(diffBranchA == diffBranchB)
                }
                if let diffError {
                    Text(diffError)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
                if let diffResult {
                    GroupBox("Diff Result") {
                        ScrollView {
                            Text(diffResult)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 300)
                    }
                }
            }
            .padding(20)
            .frame(minWidth: 500, minHeight: 300)
        }
        // Merge sheet
        .sheet(isPresented: $showMergeSheet) {
            VStack(spacing: 16) {
                Text("Merge Branches").font(.headline)
                Picker("Source", selection: $mergeSource) {
                    ForEach(appState.branches, id: \.self) { b in
                        Text(b).tag(b)
                    }
                }
                Picker("Target", selection: $mergeTarget) {
                    ForEach(appState.branches, id: \.self) { b in
                        Text(b).tag(b)
                    }
                }
                Picker("Strategy", selection: $mergeStrategy) {
                    Text("Source Wins").tag("source_wins")
                    Text("Target Wins").tag("target_wins")
                }
                .pickerStyle(.segmented)
                if let mergeError {
                    Text(mergeError)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
                if let mergeResult {
                    Text(mergeResult)
                        .foregroundStyle(.green)
                        .font(.callout)
                }
                HStack {
                    Button("Cancel") {
                        showMergeSheet = false
                    }
                    .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Merge") {
                        Task {
                            do {
                                mergeResult = try await appState.mergeBranches(
                                    source: mergeSource,
                                    target: mergeTarget,
                                    strategy: mergeStrategy
                                )
                            } catch {
                                mergeError = error.localizedDescription
                            }
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(mergeSource == mergeTarget)
                }
            }
            .padding(20)
            .frame(minWidth: 400)
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
