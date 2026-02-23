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

    var iconColor: Color {
        switch self {
        case .kv: return .blue
        case .state: return .purple
        case .events: return .orange
        case .json: return .green
        case .vectors: return .pink
        case .graph: return .teal
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

    var iconColor: Color {
        switch self {
        case .search: return .blue
        case .models: return .indigo
        case .generation: return .green
        case .admin: return .gray
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
    @State private var showExportResult: StrataBranchExportResult?
    @State private var showImportResult: StrataBranchImportResult?
    @State private var showValidateResult: StrataBundleValidateResult?
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
                Label {
                    Text("Database Info")
                } icon: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)
                }
                .tag(SidebarSelection.info)

                ForEach(appState.spaces, id: \.self) { space in
                    Section {
                        ForEach(Primitive.allCases) { prim in
                            Label {
                                Text(prim.rawValue)
                            } icon: {
                                Image(systemName: prim.icon)
                                    .foregroundStyle(prim.iconColor)
                            }
                            .tag(SidebarSelection.primitive(space: space, primitive: prim))
                        }
                    } header: {
                        Label(space, systemImage: "square.stack.3d.up")
                    }
                }

                Section {
                    ForEach(TopLevelItem.allCases) { item in
                        Label {
                            Text(item.rawValue)
                        } icon: {
                            Image(systemName: item.icon)
                                .foregroundStyle(item.iconColor)
                        }
                        .tag(SidebarSelection.topLevel(item))
                    }
                } header: {
                    Label("Tools", systemImage: "wrench.and.screwdriver")
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: StrataLayout.sidebarIdealWidth)
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
                Form {
                    Section("Space") {
                        TextField("Space name", text: $newSpaceName)
                    }
                    if let spaceError {
                        StrataErrorCallout(message: spaceError)
                    }
                }
                .formStyle(.grouped)
                .navigationTitle("New Space")
                .frame(minWidth: StrataLayout.sheetMinWidth)
                .safeAreaInset(edge: .bottom) {
                    HStack {
                        Button("Cancel") {
                            showCreateSpaceSheet = false
                        }
                        .keyboardShortcut(.cancelAction)
                        Spacer()
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
                        .buttonStyle(.borderedProminent)
                        .disabled(newSpaceName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(StrataSpacing.lg)
                }
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
            NavigationStack {
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
                Menu {
                    Section("Branch") {
                        Button {
                            newBranchName = ""
                            branchError = nil
                            showCreateBranchSheet = true
                        } label: {
                            Label("New Branch", systemImage: "plus")
                        }
                        .disabled(appState.timeTravelDate != nil)

                        Button {
                            forkDestination = ""
                            forkError = nil
                            showForkSheet = true
                        } label: {
                            Label("Fork Branch", systemImage: "arrow.triangle.branch")
                        }
                        .disabled(appState.timeTravelDate != nil)

                        Button(role: .destructive) {
                            showDeleteBranchConfirm = true
                        } label: {
                            Label("Delete Branch", systemImage: "trash")
                        }
                        .disabled(appState.selectedBranch == "default" || appState.timeTravelDate != nil)
                    }

                    Section("Compare & Merge") {
                        Button {
                            diffBranchA = appState.selectedBranch
                            diffBranchB = appState.branches.first(where: { $0 != appState.selectedBranch }) ?? "default"
                            diffResult = nil
                            diffError = nil
                            showDiffSheet = true
                        } label: {
                            Label("Diff Branches", systemImage: "arrow.left.arrow.right")
                        }

                        Button {
                            mergeSource = appState.selectedBranch
                            mergeTarget = appState.branches.first(where: { $0 != appState.selectedBranch }) ?? "default"
                            mergeStrategy = "source_wins"
                            mergeError = nil
                            mergeResult = nil
                            showMergeSheet = true
                        } label: {
                            Label("Merge Branches", systemImage: "arrow.triangle.merge")
                        }
                        .disabled(appState.timeTravelDate != nil || appState.branches.count < 2)
                    }

                    Section("Import / Export") {
                        Button {
                            exportBranchPanel()
                        } label: {
                            Label("Export Branch", systemImage: "square.and.arrow.up")
                        }
                        .disabled(appState.timeTravelDate != nil || isBranchOperationInProgress)

                        Button {
                            importBranchPanel()
                        } label: {
                            Label("Import Branch", systemImage: "square.and.arrow.down")
                        }
                        .disabled(appState.timeTravelDate != nil || isBranchOperationInProgress)
                    }
                } label: {
                    Label("Branch Actions", systemImage: "ellipsis.circle")
                }
                .help("Branch actions")
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
            Form {
                Section("Branch") {
                    TextField("Branch name", text: $newBranchName)
                }
                if let branchError {
                    StrataErrorCallout(message: branchError)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("New Branch")
            .frame(minWidth: StrataLayout.sheetMinWidth)
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Button("Cancel") {
                        showCreateBranchSheet = false
                    }
                    .keyboardShortcut(.cancelAction)
                    Spacer()
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
                    .buttonStyle(.borderedProminent)
                    .disabled(newBranchName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(StrataSpacing.lg)
            }
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
            Form {
                Section("Fork") {
                    LabeledContent("Source") {
                        Text(appState.selectedBranch)
                            .font(.system(.body, design: .monospaced))
                    }
                    TextField("Destination branch name", text: $forkDestination)
                }
                if let forkError {
                    StrataErrorCallout(message: forkError)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Fork Branch")
            .frame(minWidth: StrataLayout.sheetMinWidth)
            .safeAreaInset(edge: .bottom) {
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
                    .buttonStyle(.borderedProminent)
                    .disabled(forkDestination.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(StrataSpacing.lg)
            }
        }
        // Diff sheet
        .sheet(isPresented: $showDiffSheet) {
            Form {
                Section("Branches") {
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
                }
                if let diffError {
                    StrataErrorCallout(message: diffError)
                }
                if let diffResult {
                    Section("Diff Result") {
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
            .formStyle(.grouped)
            .navigationTitle("Diff Branches")
            .frame(minWidth: StrataLayout.sheetWideMinWidth, minHeight: 300)
            .safeAreaInset(edge: .bottom) {
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
                    .buttonStyle(.borderedProminent)
                    .disabled(diffBranchA == diffBranchB)
                }
                .padding(StrataSpacing.lg)
            }
        }
        // Merge sheet
        .sheet(isPresented: $showMergeSheet) {
            Form {
                Section("Branches") {
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
                }
                Section("Strategy") {
                    Picker("Strategy", selection: $mergeStrategy) {
                        Text("Source Wins").tag("source_wins")
                        Text("Target Wins").tag("target_wins")
                    }
                    .pickerStyle(.segmented)
                }
                if let mergeError {
                    StrataErrorCallout(message: mergeError)
                }
                if let mergeResult {
                    StrataSuccessCallout(message: mergeResult)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Merge Branches")
            .frame(minWidth: StrataLayout.sheetMinWidth)
            .safeAreaInset(edge: .bottom) {
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
                    .buttonStyle(.borderedProminent)
                    .disabled(mergeSource == mergeTarget)
                }
                .padding(StrataSpacing.lg)
            }
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
