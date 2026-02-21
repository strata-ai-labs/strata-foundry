//
//  DatabaseView.swift
//  StrataFoundry
//
//  Main view after opening a database. Sidebar + content area.
//

import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case info = "Database Info"
    case kv = "KV Store"
    case events = "Event Log"
    case state = "State Cells"
    case json = "JSON Store"
    case vectors = "Vector Store"
    case branches = "Branches"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .info: return "info.circle"
        case .kv: return "key"
        case .events: return "list.bullet.clipboard"
        case .state: return "memorychip"
        case .json: return "doc.text"
        case .vectors: return "arrow.trianglehead.branch"
        case .branches: return "arrow.triangle.branch"
        }
    }
}

struct DatabaseView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedItem: SidebarItem = .info

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selectedItem) { item in
                Label(item.rawValue, systemImage: item.icon)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            switch selectedItem {
            case .info:
                DatabaseInfoView()
            case .kv:
                KVStoreView()
            case .events:
                EventLogView()
            case .state:
                StateCellsView()
            case .json:
                JsonStoreView()
            case .vectors:
                VectorStoreView()
            case .branches:
                BranchesView()
            }
        }
        .navigationTitle(appState.databaseName)
    }
}
