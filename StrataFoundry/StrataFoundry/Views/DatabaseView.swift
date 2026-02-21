//
//  DatabaseView.swift
//  StrataFoundry
//
//  Main view after opening a database. Sidebar + content area.
//

import SwiftUI

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
    }
}
