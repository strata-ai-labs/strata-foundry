//
//  ContentView.swift
//  StrataFoundry
//
//  Created by Aniruddha Joshi on 2/20/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(WorkspaceState.self) private var workspace

    // OpenOptions config sheet
    @State private var showConfigSheet = false
    @State private var pendingDatabasePath: String?
    @State private var pendingIsCreate = false
    @State private var configAccessMode = "read_write"
    @State private var configAutoEmbed = false
    @State private var configAutoEmbedEnabled = false
    @State private var configDurability = "standard"
    @State private var configDurabilityEnabled = false
    @State private var configModelEndpoint = ""
    @State private var configModelName = ""
    @State private var configModelApiKey = ""
    @State private var configModelTimeoutMs = ""
    @State private var configEmbedBatchSize = ""

    var body: some View {
        @Bindable var workspace = workspace
        VStack(spacing: 0) {
            // Tab bar (shown when there are multiple tabs or an open database)
            if workspace.sessions.count > 1 || workspace.sessions.contains(where: { $0.isOpen }) {
                tabBar
            }

            // Active session content
            if let session = workspace.activeSession {
                Group {
                    if session.isOpen {
                        DatabaseView()
                    } else {
                        WelcomeView()
                    }
                }
                .environment(session.appState)
                .id(session.id) // Force re-render when switching tabs
            } else {
                // Should never be reached — WorkspaceState always has >= 1 session
                Color.clear
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .onChange(of: workspace.showOpenPanel) { _, show in
            if show {
                openDatabasePanel()
                workspace.showOpenPanel = false
            }
        }
        .onChange(of: workspace.showCreatePanel) { _, show in
            if show {
                createDatabasePanel()
                workspace.showCreatePanel = false
            }
        }
        // Bridge per-session open/create triggers from WelcomeView
        .onChange(of: workspace.activeSession?.appState.showOpenPanel ?? false) { _, show in
            if show {
                workspace.activeSession?.appState.showOpenPanel = false
                openDatabasePanel()
            }
        }
        .onChange(of: workspace.activeSession?.appState.showCreatePanel ?? false) { _, show in
            if show {
                workspace.activeSession?.appState.showCreatePanel = false
                createDatabasePanel()
            }
        }
        .alert("Error", isPresented: .init(
            get: {
                workspace.errorMessage != nil ||
                (workspace.activeSession?.appState.errorMessage != nil)
            },
            set: { if !$0 {
                workspace.errorMessage = nil
                workspace.activeSession?.appState.errorMessage = nil
            }}
        )) {
            Button("OK") {
                workspace.errorMessage = nil
                workspace.activeSession?.appState.errorMessage = nil
            }
        } message: {
            Text(workspace.errorMessage ?? workspace.activeSession?.appState.errorMessage ?? "")
        }
        .sheet(isPresented: $showConfigSheet) {
            openOptionsSheet
        }
    }

    // MARK: - Tab Bar

    @ViewBuilder
    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(workspace.sessions) { session in
                    tabButton(for: session)
                }

                // New tab button
                Button {
                    workspace.addTab()
                } label: {
                    Image(systemName: "plus")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderless)
                .help("New Tab")
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 32)
        .background(.bar)

        Divider()
    }

    @ViewBuilder
    private func tabButton(for session: DatabaseSession) -> some View {
        let isActive = session.id == workspace.activeSessionId

        HStack(spacing: 4) {
            if session.isOpen {
                Image(systemName: "cylinder.split.1x2")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(session.isOpen ? session.name : "New Tab")
                .font(.caption)
                .lineLimit(1)

            if workspace.sessions.count > 1 {
                Button {
                    workspace.closeTab(session.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.borderless)
                .help("Close Tab")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isActive ? Color.accentColor.opacity(0.12) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isActive ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            workspace.activeSessionId = session.id
        }
    }

    // MARK: - OpenOptions Configuration Sheet

    @ViewBuilder
    private var openOptionsSheet: some View {
        VStack(spacing: 16) {
            Text(pendingIsCreate ? "Configure New Database" : "Open Database Options")
                .font(.headline)

            Text(pendingDatabasePath.map { URL(fileURLWithPath: $0).deletingLastPathComponent().lastPathComponent } ?? "")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            // Access Mode
            Picker("Access Mode", selection: $configAccessMode) {
                Text("Read/Write").tag("read_write")
                Text("Read Only").tag("read_only")
            }
            .pickerStyle(.segmented)

            // Auto-Embed
            HStack {
                Toggle("Auto-Embed", isOn: $configAutoEmbedEnabled)
                    .toggleStyle(.checkbox)
                if configAutoEmbedEnabled {
                    Toggle(configAutoEmbed ? "Enabled" : "Disabled", isOn: $configAutoEmbed)
                        .toggleStyle(.switch)
                }
                Spacer()
            }

            // Durability
            HStack {
                Toggle("Durability", isOn: $configDurabilityEnabled)
                    .toggleStyle(.checkbox)
                if configDurabilityEnabled {
                    Picker("", selection: $configDurability) {
                        Text("Standard").tag("standard")
                        Text("Always").tag("always")
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)
                }
                Spacer()
            }

            // Model Configuration
            GroupBox("Model Configuration (optional)") {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Model Endpoint (e.g. http://localhost:11434/v1)", text: $configModelEndpoint)
                        .textFieldStyle(.roundedBorder)
                    TextField("Model Name (e.g. qwen3:1.7b)", text: $configModelName)
                        .textFieldStyle(.roundedBorder)
                    TextField("API Key (optional)", text: $configModelApiKey)
                        .textFieldStyle(.roundedBorder)
                    HStack(spacing: 16) {
                        HStack {
                            Text("Timeout (ms)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("5000", text: $configModelTimeoutMs)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                        HStack {
                            Text("Batch Size")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("512", text: $configEmbedBatchSize)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            HStack {
                Button("Use Defaults") {
                    openWithDefaults()
                }

                Spacer()

                Button("Cancel") {
                    showConfigSheet = false
                    pendingDatabasePath = nil
                }
                .keyboardShortcut(.cancelAction)

                Button(pendingIsCreate ? "Create" : "Open") {
                    openWithConfig()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 480, idealWidth: 500)
    }

    private func resetConfigForm() {
        configAccessMode = "read_write"
        configAutoEmbed = false
        configAutoEmbedEnabled = false
        configDurability = "standard"
        configDurabilityEnabled = false
        configModelEndpoint = ""
        configModelName = ""
        configModelApiKey = ""
        configModelTimeoutMs = ""
        configEmbedBatchSize = ""
    }

    private func buildOpenOptions() -> OpenOptions? {
        var opts = OpenOptions()
        opts.accessMode = configAccessMode
        if configAutoEmbedEnabled { opts.autoEmbed = configAutoEmbed }
        if configDurabilityEnabled { opts.durability = configDurability }
        if !configModelEndpoint.isEmpty { opts.modelEndpoint = configModelEndpoint }
        if !configModelName.isEmpty { opts.modelName = configModelName }
        if !configModelApiKey.isEmpty { opts.modelApiKey = configModelApiKey }
        if let ms = Int(configModelTimeoutMs) { opts.modelTimeoutMs = ms }
        if let size = Int(configEmbedBatchSize) { opts.embedBatchSize = size }

        // Return nil if everything is default
        if opts.toJSON() == nil { return nil }
        return opts
    }

    private func openWithDefaults() {
        guard let path = pendingDatabasePath else { return }
        showConfigSheet = false
        let ws = workspace
        Task {
            if pendingIsCreate {
                await ws.createDatabase(at: path)
            } else {
                await ws.openDatabase(at: path)
            }
            pendingDatabasePath = nil
        }
    }

    private func openWithConfig() {
        guard let path = pendingDatabasePath else { return }
        let options = buildOpenOptions()
        showConfigSheet = false
        let ws = workspace
        Task {
            if pendingIsCreate {
                await ws.createDatabase(at: path, options: options)
            } else {
                await ws.openDatabase(at: path, options: options)
            }
            pendingDatabasePath = nil
        }
    }

    // MARK: - File Panels

    private func openDatabasePanel() {
        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.title = "Open Strata Database"
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.message = "Select the folder containing your .strata database"

            if panel.runModal() == .OK, let url = panel.url {
                let strataURL = url.lastPathComponent == ".strata"
                    ? url
                    : url.appendingPathComponent(".strata")
                pendingDatabasePath = strataURL.path
                pendingIsCreate = false
                resetConfigForm()
                showConfigSheet = true
            }
        }
    }

    private func createDatabasePanel() {
        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.title = "Create Strata Database"
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.canCreateDirectories = true
            panel.message = "Choose a directory for the new database"
            panel.prompt = "Create"

            if panel.runModal() == .OK, let url = panel.url {
                let dbPath = url.appendingPathComponent(".strata").path
                pendingDatabasePath = dbPath
                pendingIsCreate = true
                resetConfigForm()
                showConfigSheet = true
            }
        }
    }
}
