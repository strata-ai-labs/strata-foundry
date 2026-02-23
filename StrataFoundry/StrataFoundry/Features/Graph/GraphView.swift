//
//  GraphView.swift
//  StrataFoundry
//
//  Thin view observing GraphFeatureModel — all business logic delegated to model.
//

import SwiftUI

// MARK: - View

struct GraphView: View {
    @Environment(AppState.self) private var appState
    @State private var model: GraphFeatureModel?

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
                model = GraphFeatureModel(graphService: services.graphService, appState: appState)
            }
            await model?.loadGraphs()
        }
        .onChange(of: model?.selectedGraph) { _, newValue in
            model?.onSelectGraph(newValue)
        }
        .sheet(isPresented: Binding(
            get: { model?.showCreateSheet ?? false },
            set: { model?.showCreateSheet = $0 }
        )) {
            if let model {
                createGraphSheet(model)
            }
        }
        .alert("Delete Graph", isPresented: Binding(
            get: { model?.showDeleteConfirm ?? false },
            set: { model?.showDeleteConfirm = $0 }
        )) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let name = model?.selectedGraph {
                    Task { await model?.deleteGraph(name) }
                }
            }
        } message: {
            if let name = model?.selectedGraph {
                Text("Delete graph \"\(name)\"? All nodes and edges will be removed.")
            }
        }
    }

    // MARK: - Toolbar

    @ViewBuilder
    private func toolbar(_ model: GraphFeatureModel) -> some View {
        HStack {
            Text("Graph Explorer")
                .font(.title2)
                .fontWeight(.semibold)
            Spacer()
            Text("\(model.graphs.count) graphs")
                .foregroundStyle(.secondary)
            Button {
                model.formGraphName = ""
                model.formCascadePolicy = "none"
                model.showCreateSheet = true
            } label: {
                Image(systemName: "plus")
            }
            .help("Create Graph")
            .disabled(model.isTimeTraveling)
            Button {
                model.showDeleteConfirm = true
            } label: {
                Image(systemName: "trash")
            }
            .help("Delete Graph")
            .disabled(model.isTimeTraveling || model.selectedGraph == nil)
            Button {
                Task { await model.loadGraphs() }
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
    private func content(_ model: GraphFeatureModel) -> some View {
        LoadingErrorEmptyView(
            isLoading: model.isLoading,
            errorMessage: model.errorMessage,
            isEmpty: model.graphs.isEmpty,
            emptyIcon: "circle.hexagongrid",
            emptyText: "No graphs"
        ) {
            HSplitView {
                // Left pane: graph list
                List(model.graphs, id: \.self, selection: Binding(
                    get: { model.selectedGraph },
                    set: { model.selectedGraph = $0 }
                )) { graph in
                    Text(graph)
                        .font(.system(.body, design: .monospaced))
                        .tag(graph)
                }
                .frame(minWidth: 160, idealWidth: 200)

                // Right pane: operations
                rightPane(model)
            }
        }
    }

    // MARK: - Create Graph Sheet

    @ViewBuilder
    private func createGraphSheet(_ model: GraphFeatureModel) -> some View {
        VStack(spacing: 16) {
            Text("Create Graph")
                .font(.headline)

            TextField("Graph Name", text: Binding(
                get: { model.formGraphName },
                set: { model.formGraphName = $0 }
            ))
            .textFieldStyle(.roundedBorder)

            Picker("Cascade Policy", selection: Binding(
                get: { model.formCascadePolicy },
                set: { model.formCascadePolicy = $0 }
            )) {
                Text("None").tag("none")
                Text("Delete").tag("delete")
            }
            .pickerStyle(.segmented)

            HStack {
                Button("Cancel") {
                    model.showCreateSheet = false
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create") {
                    Task {
                        await model.createGraph()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(model.formGraphName.isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 350)
    }

    // MARK: - Right Pane

    @ViewBuilder
    private func rightPane(_ model: GraphFeatureModel) -> some View {
        if let graphName = model.selectedGraph {
            VStack(spacing: 0) {
                // Meta banner
                if let meta = model.graphMeta {
                    HStack(spacing: 8) {
                        StatsCapsule(label: "Graph", value: graphName)
                        StatsCapsule(label: "Nodes", value: "\(model.nodeList.count)")
                        if !meta.isEmpty {
                            StatsCapsule(label: "Meta", value: meta)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    Divider()
                }

                // Mode picker
                Picker("Mode", selection: Binding(
                    get: { model.graphMode },
                    set: { model.graphMode = $0 }
                )) {
                    ForEach(GraphPaneMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                Divider()

                // Mode content
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        switch model.graphMode {
                        case .nodes:
                            nodesModeView(model)
                        case .edges:
                            edgesModeView(model)
                        case .neighbors:
                            neighborsModeView(model)
                        case .bfs:
                            bfsModeView(model)
                        case .bulkInsert:
                            bulkInsertModeView(model)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } else {
            VStack {
                Spacer()
                Text("Select a graph")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Nodes Mode

    @ViewBuilder
    private func nodesModeView(_ model: GraphFeatureModel) -> some View {
        // Node list
        if !model.nodeList.isEmpty {
            GroupBox("Nodes (\(model.nodeList.count))") {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(model.nodeList, id: \.self) { nodeId in
                            HStack {
                                Text(nodeId)
                                    .font(.system(.body, design: .monospaced))
                                Spacer()
                                Button("Get") {
                                    model.nodeIdField = nodeId
                                    Task { await model.getNode(nodeId: nodeId) }
                                }
                                .buttonStyle(.borderless)
                                .font(.caption)
                                Button("Remove") {
                                    Task { await model.removeNode(nodeId: nodeId) }
                                }
                                .buttonStyle(.borderless)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .disabled(model.isTimeTraveling)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: 200)
            }
        }

        Divider()

        // Add Node
        Text("Add / Get Node")
            .font(.headline)

        HStack {
            TextField("Node ID", text: Binding(
                get: { model.nodeIdField },
                set: { model.nodeIdField = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            Button("Get") {
                Task { await model.getNode(nodeId: model.nodeIdField) }
            }
            .disabled(model.nodeIdField.isEmpty)
        }

        TextField("Label (optional)", text: Binding(
            get: { model.nodeLabelField },
            set: { model.nodeLabelField = $0 }
        ))
        .textFieldStyle(.roundedBorder)

        Text("Properties (optional JSON object)")
            .font(.caption)
            .foregroundStyle(.secondary)
        TextEditor(text: Binding(
            get: { model.nodePropsField },
            set: { model.nodePropsField = $0 }
        ))
        .font(.system(.body, design: .monospaced))
        .frame(minHeight: 60)
        .border(Color.secondary.opacity(0.3))
        .disabled(model.isTimeTraveling)

        HStack {
            Button("Add Node") {
                Task { await model.addNode() }
            }
            .disabled(model.isTimeTraveling || model.nodeIdField.isEmpty)

            Button("Remove Node") {
                Task { await model.removeNode(nodeId: model.nodeIdField) }
            }
            .disabled(model.isTimeTraveling || model.nodeIdField.isEmpty)

            Button("Refresh List") {
                Task { await model.loadNodes() }
            }
        }

        if let error = model.nodeError {
            Text(error)
                .foregroundStyle(.red)
                .font(.callout)
        }

        if let result = model.nodeResult {
            GroupBox("Node Data") {
                Text(result)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Edges Mode

    @ViewBuilder
    private func edgesModeView(_ model: GraphFeatureModel) -> some View {
        if model.isTimeTraveling {
            Label("Edge operations are disabled during time travel", systemImage: "info.circle")
                .foregroundStyle(.orange)
                .font(.callout)
        }

        Text("Add Edge")
            .font(.headline)

        HStack {
            TextField("Source Node", text: Binding(
                get: { model.edgeSrc },
                set: { model.edgeSrc = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            TextField("Destination Node", text: Binding(
                get: { model.edgeDst },
                set: { model.edgeDst = $0 }
            ))
            .textFieldStyle(.roundedBorder)
        }
        .disabled(model.isTimeTraveling)

        HStack {
            TextField("Edge Type", text: Binding(
                get: { model.edgeType },
                set: { model.edgeType = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            TextField("Weight (optional)", text: Binding(
                get: { model.edgeWeight },
                set: { model.edgeWeight = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 120)
        }
        .disabled(model.isTimeTraveling)

        Text("Properties (optional JSON object)")
            .font(.caption)
            .foregroundStyle(.secondary)
        TextEditor(text: Binding(
            get: { model.edgePropsField },
            set: { model.edgePropsField = $0 }
        ))
        .font(.system(.body, design: .monospaced))
        .frame(minHeight: 60)
        .border(Color.secondary.opacity(0.3))
        .disabled(model.isTimeTraveling)

        HStack {
            Button("Add Edge") {
                Task { await model.addEdge() }
            }
            .disabled(model.isTimeTraveling || model.edgeSrc.isEmpty || model.edgeDst.isEmpty || model.edgeType.isEmpty)

            Button("Remove Edge") {
                Task { await model.removeEdge() }
            }
            .disabled(model.isTimeTraveling || model.edgeSrc.isEmpty || model.edgeDst.isEmpty || model.edgeType.isEmpty)
        }

        if let success = model.edgeSuccess {
            Text(success)
                .foregroundStyle(.green)
                .font(.callout)
        }
        if let error = model.edgeError {
            Text(error)
                .foregroundStyle(.red)
                .font(.callout)
        }
    }

    // MARK: - Neighbors Mode

    @ViewBuilder
    private func neighborsModeView(_ model: GraphFeatureModel) -> some View {
        Text("Graph Neighbors")
            .font(.headline)

        TextField("Node ID", text: Binding(
            get: { model.neighborNodeId },
            set: { model.neighborNodeId = $0 }
        ))
        .textFieldStyle(.roundedBorder)

        Picker("Direction", selection: Binding(
            get: { model.neighborDirection },
            set: { model.neighborDirection = $0 }
        )) {
            Text("Outgoing").tag("outgoing")
            Text("Incoming").tag("incoming")
            Text("Both").tag("both")
        }
        .pickerStyle(.segmented)

        TextField("Edge Type Filter (optional)", text: Binding(
            get: { model.neighborEdgeType },
            set: { model.neighborEdgeType = $0 }
        ))
        .textFieldStyle(.roundedBorder)

        Button("Find Neighbors") {
            Task { await model.findNeighbors() }
        }
        .disabled(model.neighborNodeId.isEmpty)

        if let error = model.neighborError {
            Text(error)
                .foregroundStyle(.red)
                .font(.callout)
        }

        if !model.neighborResults.isEmpty {
            GroupBox("Neighbors (\(model.neighborResults.count))") {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(model.neighborResults) { neighbor in
                        HStack {
                            Text(neighbor.nodeId)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Text(neighbor.edgeType)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.quaternary)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            if let w = neighbor.weight {
                                Text(String(format: "%.3f", w))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(8)
            }
        }
    }

    // MARK: - BFS Mode

    @ViewBuilder
    private func bfsModeView(_ model: GraphFeatureModel) -> some View {
        Text("Breadth-First Search")
            .font(.headline)

        TextField("Start Node", text: Binding(
            get: { model.bfsStart },
            set: { model.bfsStart = $0 }
        ))
        .textFieldStyle(.roundedBorder)

        HStack {
            Text("Max Depth")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("3", text: Binding(
                get: { model.bfsMaxDepth },
                set: { model.bfsMaxDepth = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .frame(width: 60)

            Text("Max Nodes")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("100", text: Binding(
                get: { model.bfsMaxNodes },
                set: { model.bfsMaxNodes = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .frame(width: 80)
        }

        Picker("Direction", selection: Binding(
            get: { model.bfsDirection },
            set: { model.bfsDirection = $0 }
        )) {
            Text("Outgoing").tag("outgoing")
            Text("Incoming").tag("incoming")
            Text("Both").tag("both")
        }
        .pickerStyle(.segmented)

        TextField("Edge Types (comma-separated, optional)", text: Binding(
            get: { model.bfsEdgeTypes },
            set: { model.bfsEdgeTypes = $0 }
        ))
        .textFieldStyle(.roundedBorder)

        Button("Run BFS") {
            Task { await model.runBfs() }
        }
        .disabled(model.bfsStart.isEmpty)

        if let error = model.bfsError {
            Text(error)
                .foregroundStyle(.red)
                .font(.callout)
        }

        if let result = model.bfsResult {
            GroupBox("BFS Result \u{2014} \(result.visited.count) nodes visited") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Visited Nodes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(result.visited.joined(separator: ", "))
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)

                    if !result.depths.isEmpty {
                        Divider()
                        Text("Depths")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(result.depths.sorted(by: { $0.value < $1.value }), id: \.key) { node, depth in
                            HStack {
                                Text(node)
                                    .font(.system(.caption, design: .monospaced))
                                Spacer()
                                Text("depth \(depth)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(8)
            }
        }
    }

    // MARK: - Bulk Insert Mode

    @ViewBuilder
    private func bulkInsertModeView(_ model: GraphFeatureModel) -> some View {
        if model.isTimeTraveling {
            Label("Bulk insert is disabled during time travel", systemImage: "info.circle")
                .foregroundStyle(.orange)
                .font(.callout)
        }

        Text("Bulk Insert")
            .font(.headline)

        Text("Paste JSON with \"nodes\" and \"edges\" arrays:")
            .font(.caption)
            .foregroundStyle(.secondary)

        TextEditor(text: Binding(
            get: { model.bulkJSON },
            set: { model.bulkJSON = $0 }
        ))
        .font(.system(.body, design: .monospaced))
        .frame(minHeight: 200)
        .border(Color.secondary.opacity(0.3))
        .disabled(model.isTimeTraveling)

        Text("Format: {\"nodes\": [{\"node_id\": \"...\", \"label\": \"...\", \"properties\": {...}}], \"edges\": [{\"src\": \"...\", \"dst\": \"...\", \"edge_type\": \"...\", \"weight\": 1.0}]}")
            .font(.caption2)
            .foregroundStyle(.tertiary)

        Button("Insert") {
            Task { await model.bulkInsert() }
        }
        .disabled(model.isTimeTraveling || model.bulkJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        if let result = model.bulkResult {
            Text(result)
                .foregroundStyle(.green)
                .font(.callout)
        }
        if let error = model.bulkError {
            Text(error)
                .foregroundStyle(.red)
                .font(.callout)
        }
    }
}
