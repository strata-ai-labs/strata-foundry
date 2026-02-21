//
//  DatabaseView.swift
//  StrataFoundry
//
//  Main view after opening a database. Sidebar + content area.
//

import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
    case info = "Database Info"
    case kv = "KV Store"
    case state = "State Cells"
    case events = "Event Log"
    case json = "JSON Store"
    case vectors = "Vector Store"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .info: return "info.circle"
        case .kv: return "key"
        case .state: return "memorychip"
        case .events: return "list.bullet.clipboard"
        case .json: return "doc.text"
        case .vectors: return "arrow.trianglehead.branch"
        }
    }
}

struct DatabaseView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedItem: SidebarItem? = .info

    var body: some View {
        @Bindable var appState = appState
        NavigationSplitView {
            List(selection: $selectedItem) {
                ForEach(SidebarItem.allCases) { item in
                    Label(item.rawValue, systemImage: item.icon)
                        .tag(item)
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            switch selectedItem {
            case .info:
                DatabaseInfoView()
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
            case nil:
                DatabaseInfoView()
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
    }
}
