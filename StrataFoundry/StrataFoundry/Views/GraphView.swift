//
//  GraphView.swift
//  StrataFoundry
//
//  Graph Explorer — 14 graph commands.
//

import SwiftUI

// MARK: - Mode Enum

enum GraphMode: String, CaseIterable {
    case nodes = "Nodes"
    case edges = "Edges"
    case neighbors = "Neighbors"
    case bfs = "BFS"
    case bulkInsert = "Bulk Insert"
}

// MARK: - Model Structs

struct NeighborEntry: Identifiable {
    let id: UUID
    let nodeId: String
    let edgeType: String
    let weight: Double?
}

struct BfsResult {
    let visited: [String]
    let depths: [String: Int]
    let edges: [[String: String]]
}

// MARK: - View

struct GraphView: View {
    @Environment(AppState.self) private var appState
    @State private var graphs: [String] = []
    @State private var selectedGraph: String?
    @State private var isLoading = false
    @State private var errorMessage: String?

    // Create graph
    @State private var showCreateSheet = false
    @State private var showDeleteConfirm = false
    @State private var formGraphName = ""
    @State private var formCascadePolicy = "none"

    // Right pane
    @State private var graphMode: GraphMode = .nodes
    @State private var graphMeta: String?

    // Nodes
    @State private var nodeList: [String] = []
    @State private var nodeIdField = ""
    @State private var nodeLabelField = ""
    @State private var nodePropsField = ""
    @State private var nodeResult: String?
    @State private var nodeError: String?

    // Edges
    @State private var edgeSrc = ""
    @State private var edgeDst = ""
    @State private var edgeType = ""
    @State private var edgeWeight = ""
    @State private var edgePropsField = ""
    @State private var edgeError: String?
    @State private var edgeSuccess: String?

    // Neighbors
    @State private var neighborNodeId = ""
    @State private var neighborDirection = "outgoing"
    @State private var neighborEdgeType = ""
    @State private var neighborResults: [NeighborEntry] = []
    @State private var neighborError: String?

    // BFS
    @State private var bfsStart = ""
    @State private var bfsMaxDepth = "3"
    @State private var bfsMaxNodes = "100"
    @State private var bfsDirection = "outgoing"
    @State private var bfsEdgeTypes = ""
    @State private var bfsResult: BfsResult?
    @State private var bfsError: String?

    // Bulk Insert
    @State private var bulkJSON = ""
    @State private var bulkResult: String?
    @State private var bulkError: String?

    private var isTimeTraveling: Bool { appState.timeTravelDate != nil }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Toolbar
            HStack {
                Text("Graph Explorer")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(graphs.count) graphs")
                    .foregroundStyle(.secondary)
                Button {
                    formGraphName = ""
                    formCascadePolicy = "none"
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Create Graph")
                .disabled(isTimeTraveling)
                Button {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                }
                .help("Delete Graph")
                .disabled(isTimeTraveling || selectedGraph == nil)
                Button {
                    Task { await loadGraphs() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)

            Divider()

            // MARK: Content
            if isLoading {
                Spacer()
                ProgressView("Loading graphs...")
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                Text(error).foregroundStyle(.red).padding()
                Spacer()
            } else if graphs.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "circle.hexagongrid")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No graphs")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                HSplitView {
                    // Left pane: graph list
                    List(graphs, id: \.self, selection: $selectedGraph) { graph in
                        Text(graph)
                            .font(.system(.body, design: .monospaced))
                            .tag(graph)
                    }
                    .frame(minWidth: 160, idealWidth: 200)

                    // Right pane: operations
                    rightPane
                }
            }
        }
        .task(id: appState.reloadToken) {
            await loadGraphs()
        }
        .onChange(of: selectedGraph) { _, newValue in
            resetRightPaneState()
            if newValue != nil {
                Task {
                    await loadGraphMeta()
                    await loadNodes()
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            VStack(spacing: 16) {
                Text("Create Graph")
                    .font(.headline)

                TextField("Graph Name", text: $formGraphName)
                    .textFieldStyle(.roundedBorder)

                Picker("Cascade Policy", selection: $formCascadePolicy) {
                    Text("None").tag("none")
                    Text("Delete").tag("delete")
                }
                .pickerStyle(.segmented)

                HStack {
                    Button("Cancel") {
                        showCreateSheet = false
                    }
                    .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Create") {
                        Task {
                            await createGraph()
                            showCreateSheet = false
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(formGraphName.isEmpty)
                }
            }
            .padding(20)
            .frame(minWidth: 350)
        }
        .alert("Delete Graph", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let name = selectedGraph {
                    Task { await deleteGraph(name) }
                }
            }
        } message: {
            if let name = selectedGraph {
                Text("Delete graph \"\(name)\"? All nodes and edges will be removed.")
            }
        }
    }

    // MARK: - Right Pane

    @ViewBuilder
    private var rightPane: some View {
        if let graphName = selectedGraph {
            VStack(spacing: 0) {
                // Meta banner
                if let meta = graphMeta {
                    HStack(spacing: 8) {
                        statsCapsule("Graph", graphName)
                        statsCapsule("Nodes", "\(nodeList.count)")
                        if !meta.isEmpty {
                            statsCapsule("Meta", meta)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    Divider()
                }

                // Mode picker
                Picker("Mode", selection: $graphMode) {
                    ForEach(GraphMode.allCases, id: \.self) { mode in
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
                        switch graphMode {
                        case .nodes:
                            nodesModeView(graph: graphName)
                        case .edges:
                            edgesModeView(graph: graphName)
                        case .neighbors:
                            neighborsModeView(graph: graphName)
                        case .bfs:
                            bfsModeView(graph: graphName)
                        case .bulkInsert:
                            bulkInsertModeView(graph: graphName)
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

    // MARK: - Stats Capsule

    @ViewBuilder
    private func statsCapsule(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary, in: Capsule())
    }

    // MARK: - Nodes Mode

    @ViewBuilder
    private func nodesModeView(graph: String) -> some View {
        // Node list
        if !nodeList.isEmpty {
            GroupBox("Nodes (\(nodeList.count))") {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(nodeList, id: \.self) { nodeId in
                            HStack {
                                Text(nodeId)
                                    .font(.system(.body, design: .monospaced))
                                Spacer()
                                Button("Get") {
                                    nodeIdField = nodeId
                                    Task { await getNode(graph: graph, nodeId: nodeId) }
                                }
                                .buttonStyle(.borderless)
                                .font(.caption)
                                Button("Remove") {
                                    Task { await removeNode(graph: graph, nodeId: nodeId) }
                                }
                                .buttonStyle(.borderless)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .disabled(isTimeTraveling)
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
            TextField("Node ID", text: $nodeIdField)
                .textFieldStyle(.roundedBorder)
            Button("Get") {
                Task { await getNode(graph: graph, nodeId: nodeIdField) }
            }
            .disabled(nodeIdField.isEmpty)
        }

        TextField("Label (optional)", text: $nodeLabelField)
            .textFieldStyle(.roundedBorder)

        Text("Properties (optional JSON object)")
            .font(.caption)
            .foregroundStyle(.secondary)
        TextEditor(text: $nodePropsField)
            .font(.system(.body, design: .monospaced))
            .frame(minHeight: 60)
            .border(Color.secondary.opacity(0.3))
            .disabled(isTimeTraveling)

        HStack {
            Button("Add Node") {
                Task { await addNode(graph: graph) }
            }
            .disabled(isTimeTraveling || nodeIdField.isEmpty)

            Button("Remove Node") {
                Task { await removeNode(graph: graph, nodeId: nodeIdField) }
            }
            .disabled(isTimeTraveling || nodeIdField.isEmpty)

            Button("Refresh List") {
                Task { await loadNodes() }
            }
        }

        if let error = nodeError {
            Text(error)
                .foregroundStyle(.red)
                .font(.callout)
        }

        if let result = nodeResult {
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
    private func edgesModeView(graph: String) -> some View {
        if isTimeTraveling {
            Label("Edge operations are disabled during time travel", systemImage: "info.circle")
                .foregroundStyle(.orange)
                .font(.callout)
        }

        Text("Add Edge")
            .font(.headline)

        HStack {
            TextField("Source Node", text: $edgeSrc)
                .textFieldStyle(.roundedBorder)
            TextField("Destination Node", text: $edgeDst)
                .textFieldStyle(.roundedBorder)
        }
        .disabled(isTimeTraveling)

        HStack {
            TextField("Edge Type", text: $edgeType)
                .textFieldStyle(.roundedBorder)
            TextField("Weight (optional)", text: $edgeWeight)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 120)
        }
        .disabled(isTimeTraveling)

        Text("Properties (optional JSON object)")
            .font(.caption)
            .foregroundStyle(.secondary)
        TextEditor(text: $edgePropsField)
            .font(.system(.body, design: .monospaced))
            .frame(minHeight: 60)
            .border(Color.secondary.opacity(0.3))
            .disabled(isTimeTraveling)

        HStack {
            Button("Add Edge") {
                Task { await addEdge(graph: graph) }
            }
            .disabled(isTimeTraveling || edgeSrc.isEmpty || edgeDst.isEmpty || edgeType.isEmpty)

            Button("Remove Edge") {
                Task { await removeEdge(graph: graph) }
            }
            .disabled(isTimeTraveling || edgeSrc.isEmpty || edgeDst.isEmpty || edgeType.isEmpty)
        }

        if let success = edgeSuccess {
            Text(success)
                .foregroundStyle(.green)
                .font(.callout)
        }
        if let error = edgeError {
            Text(error)
                .foregroundStyle(.red)
                .font(.callout)
        }
    }

    // MARK: - Neighbors Mode

    @ViewBuilder
    private func neighborsModeView(graph: String) -> some View {
        Text("Graph Neighbors")
            .font(.headline)

        TextField("Node ID", text: $neighborNodeId)
            .textFieldStyle(.roundedBorder)

        Picker("Direction", selection: $neighborDirection) {
            Text("Outgoing").tag("outgoing")
            Text("Incoming").tag("incoming")
            Text("Both").tag("both")
        }
        .pickerStyle(.segmented)

        TextField("Edge Type Filter (optional)", text: $neighborEdgeType)
            .textFieldStyle(.roundedBorder)

        Button("Find Neighbors") {
            Task { await findNeighbors(graph: graph) }
        }
        .disabled(neighborNodeId.isEmpty)

        if let error = neighborError {
            Text(error)
                .foregroundStyle(.red)
                .font(.callout)
        }

        if !neighborResults.isEmpty {
            GroupBox("Neighbors (\(neighborResults.count))") {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(neighborResults) { neighbor in
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
    private func bfsModeView(graph: String) -> some View {
        Text("Breadth-First Search")
            .font(.headline)

        TextField("Start Node", text: $bfsStart)
            .textFieldStyle(.roundedBorder)

        HStack {
            Text("Max Depth")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("3", text: $bfsMaxDepth)
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)

            Text("Max Nodes")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("100", text: $bfsMaxNodes)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
        }

        Picker("Direction", selection: $bfsDirection) {
            Text("Outgoing").tag("outgoing")
            Text("Incoming").tag("incoming")
            Text("Both").tag("both")
        }
        .pickerStyle(.segmented)

        TextField("Edge Types (comma-separated, optional)", text: $bfsEdgeTypes)
            .textFieldStyle(.roundedBorder)

        Button("Run BFS") {
            Task { await runBfs(graph: graph) }
        }
        .disabled(bfsStart.isEmpty)

        if let error = bfsError {
            Text(error)
                .foregroundStyle(.red)
                .font(.callout)
        }

        if let result = bfsResult {
            GroupBox("BFS Result — \(result.visited.count) nodes visited") {
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
    private func bulkInsertModeView(graph: String) -> some View {
        if isTimeTraveling {
            Label("Bulk insert is disabled during time travel", systemImage: "info.circle")
                .foregroundStyle(.orange)
                .font(.callout)
        }

        Text("Bulk Insert")
            .font(.headline)

        Text("Paste JSON with \"nodes\" and \"edges\" arrays:")
            .font(.caption)
            .foregroundStyle(.secondary)

        TextEditor(text: $bulkJSON)
            .font(.system(.body, design: .monospaced))
            .frame(minHeight: 200)
            .border(Color.secondary.opacity(0.3))
            .disabled(isTimeTraveling)

        Text("Format: {\"nodes\": [{\"node_id\": \"...\", \"label\": \"...\", \"properties\": {...}}], \"edges\": [{\"src\": \"...\", \"dst\": \"...\", \"edge_type\": \"...\", \"weight\": 1.0}]}")
            .font(.caption2)
            .foregroundStyle(.tertiary)

        Button("Insert") {
            Task { await bulkInsert(graph: graph) }
        }
        .disabled(isTimeTraveling || bulkJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        if let result = bulkResult {
            Text(result)
                .foregroundStyle(.green)
                .font(.callout)
        }
        if let error = bulkError {
            Text(error)
                .foregroundStyle(.red)
                .font(.callout)
        }
    }

    // MARK: - State Management

    private func resetRightPaneState() {
        graphMeta = nil
        nodeList = []
        nodeIdField = ""
        nodeLabelField = ""
        nodePropsField = ""
        nodeResult = nil
        nodeError = nil
        edgeSrc = ""
        edgeDst = ""
        edgeType = ""
        edgeWeight = ""
        edgePropsField = ""
        edgeError = nil
        edgeSuccess = nil
        neighborNodeId = ""
        neighborDirection = "outgoing"
        neighborEdgeType = ""
        neighborResults = []
        neighborError = nil
        bfsStart = ""
        bfsMaxDepth = "3"
        bfsMaxNodes = "100"
        bfsDirection = "outgoing"
        bfsEdgeTypes = ""
        bfsResult = nil
        bfsError = nil
        bulkJSON = ""
        bulkResult = nil
        bulkError = nil
    }

    // MARK: - Graph CRUD

    private func loadGraphs() async {
        guard let client = appState.client else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let json = try await client.executeRaw("{\"GraphList\": {\"branch\": \"\(appState.selectedBranch)\"\(appState.spaceFragment())\(appState.asOfFragment())}}")
            guard let data = json.data(using: .utf8),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let keys = root["Keys"] as? [String] else {
                graphs = []
                return
            }
            graphs = keys
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createGraph() async {
        guard let client = appState.client else { return }
        do {
            var cmd: [String: Any] = [
                "branch": appState.selectedBranch,
                "graph": formGraphName
            ]
            if appState.selectedSpace != "default" {
                cmd["space"] = appState.selectedSpace
            }
            if formCascadePolicy != "none" {
                cmd["cascade_policy"] = formCascadePolicy
            }
            let wrapper: [String: Any] = ["GraphCreate": cmd]
            let data = try JSONSerialization.data(withJSONObject: wrapper)
            let jsonStr = String(data: data, encoding: .utf8)!
            _ = try await client.executeRaw(jsonStr)
            await loadGraphs()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteGraph(_ name: String) async {
        guard let client = appState.client else { return }
        do {
            var cmd: [String: Any] = [
                "branch": appState.selectedBranch,
                "graph": name
            ]
            if appState.selectedSpace != "default" {
                cmd["space"] = appState.selectedSpace
            }
            let wrapper: [String: Any] = ["GraphDelete": cmd]
            let data = try JSONSerialization.data(withJSONObject: wrapper)
            let jsonStr = String(data: data, encoding: .utf8)!
            _ = try await client.executeRaw(jsonStr)
            if selectedGraph == name { selectedGraph = nil }
            await loadGraphs()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadGraphMeta() async {
        guard let client = appState.client,
              let graphName = selectedGraph else { return }
        do {
            var cmd: [String: Any] = [
                "branch": appState.selectedBranch,
                "graph": graphName
            ]
            if appState.selectedSpace != "default" {
                cmd["space"] = appState.selectedSpace
            }
            if let date = appState.timeTravelDate {
                cmd["as_of"] = Int64(date.timeIntervalSince1970 * 1_000_000)
            }
            let wrapper: [String: Any] = ["GraphGetMeta": cmd]
            let data = try JSONSerialization.data(withJSONObject: wrapper)
            let jsonStr = String(data: data, encoding: .utf8)!
            let json = try await client.executeRaw(jsonStr)

            if let respData = json.data(using: .utf8),
               let root = try? JSONSerialization.jsonObject(with: respData) as? [String: Any],
               let maybe = root["Maybe"] {
                if let metaData = try? JSONSerialization.data(withJSONObject: maybe, options: [.prettyPrinted, .sortedKeys]),
                   let str = String(data: metaData, encoding: .utf8) {
                    graphMeta = str
                } else {
                    graphMeta = "\(maybe)"
                }
            } else {
                graphMeta = ""
            }
        } catch {
            graphMeta = ""
        }
    }

    // MARK: - Node Operations

    private func loadNodes() async {
        guard let client = appState.client,
              let graphName = selectedGraph else { return }
        do {
            var cmd: [String: Any] = [
                "branch": appState.selectedBranch,
                "graph": graphName
            ]
            if appState.selectedSpace != "default" {
                cmd["space"] = appState.selectedSpace
            }
            if let date = appState.timeTravelDate {
                cmd["as_of"] = Int64(date.timeIntervalSince1970 * 1_000_000)
            }
            let wrapper: [String: Any] = ["GraphListNodes": cmd]
            let data = try JSONSerialization.data(withJSONObject: wrapper)
            let jsonStr = String(data: data, encoding: .utf8)!
            let json = try await client.executeRaw(jsonStr)

            guard let respData = json.data(using: .utf8),
                  let root = try? JSONSerialization.jsonObject(with: respData) as? [String: Any],
                  let keys = root["Keys"] as? [String] else {
                nodeList = []
                return
            }
            nodeList = keys
        } catch {
            nodeList = []
        }
    }

    private func getNode(graph: String, nodeId: String) async {
        guard let client = appState.client else { return }
        nodeResult = nil
        nodeError = nil
        do {
            var cmd: [String: Any] = [
                "branch": appState.selectedBranch,
                "graph": graph,
                "node_id": nodeId
            ]
            if appState.selectedSpace != "default" {
                cmd["space"] = appState.selectedSpace
            }
            if let date = appState.timeTravelDate {
                cmd["as_of"] = Int64(date.timeIntervalSince1970 * 1_000_000)
            }
            let wrapper: [String: Any] = ["GraphGetNode": cmd]
            let data = try JSONSerialization.data(withJSONObject: wrapper)
            let jsonStr = String(data: data, encoding: .utf8)!
            let json = try await client.executeRaw(jsonStr)

            if let respData = json.data(using: .utf8),
               let root = try? JSONSerialization.jsonObject(with: respData) as? [String: Any],
               let maybe = root["Maybe"] {
                if let prettyData = try? JSONSerialization.data(withJSONObject: maybe, options: [.prettyPrinted, .sortedKeys]),
                   let str = String(data: prettyData, encoding: .utf8) {
                    nodeResult = str
                } else {
                    nodeResult = "\(maybe)"
                }
            } else {
                nodeError = "Node \"\(nodeId)\" not found"
            }
        } catch {
            nodeError = error.localizedDescription
        }
    }

    private func addNode(graph: String) async {
        guard let client = appState.client else { return }
        nodeError = nil
        do {
            var cmd: [String: Any] = [
                "branch": appState.selectedBranch,
                "graph": graph,
                "node_id": nodeIdField
            ]
            if appState.selectedSpace != "default" {
                cmd["space"] = appState.selectedSpace
            }
            if !nodeLabelField.isEmpty {
                cmd["label"] = nodeLabelField
            }
            if !nodePropsField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                guard let propsData = nodePropsField.data(using: .utf8),
                      let propsObj = try? JSONSerialization.jsonObject(with: propsData) as? [String: Any] else {
                    nodeError = "Invalid properties: must be a JSON object"
                    return
                }
                cmd["properties"] = propsObj
            }
            let wrapper: [String: Any] = ["GraphAddNode": cmd]
            let data = try JSONSerialization.data(withJSONObject: wrapper)
            let jsonStr = String(data: data, encoding: .utf8)!
            _ = try await client.executeRaw(jsonStr)
            await loadNodes()
            nodeResult = "Node \"\(nodeIdField)\" added."
        } catch {
            nodeError = error.localizedDescription
        }
    }

    private func removeNode(graph: String, nodeId: String) async {
        guard let client = appState.client else { return }
        nodeError = nil
        do {
            var cmd: [String: Any] = [
                "branch": appState.selectedBranch,
                "graph": graph,
                "node_id": nodeId
            ]
            if appState.selectedSpace != "default" {
                cmd["space"] = appState.selectedSpace
            }
            let wrapper: [String: Any] = ["GraphRemoveNode": cmd]
            let data = try JSONSerialization.data(withJSONObject: wrapper)
            let jsonStr = String(data: data, encoding: .utf8)!
            _ = try await client.executeRaw(jsonStr)
            await loadNodes()
            nodeResult = nil
            nodeError = nil
        } catch {
            nodeError = error.localizedDescription
        }
    }

    // MARK: - Edge Operations

    private func addEdge(graph: String) async {
        guard let client = appState.client else { return }
        edgeError = nil
        edgeSuccess = nil
        do {
            var cmd: [String: Any] = [
                "branch": appState.selectedBranch,
                "graph": graph,
                "src": edgeSrc,
                "dst": edgeDst,
                "edge_type": edgeType
            ]
            if appState.selectedSpace != "default" {
                cmd["space"] = appState.selectedSpace
            }
            if let w = Double(edgeWeight) {
                cmd["weight"] = w
            }
            if !edgePropsField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                guard let propsData = edgePropsField.data(using: .utf8),
                      let propsObj = try? JSONSerialization.jsonObject(with: propsData) as? [String: Any] else {
                    edgeError = "Invalid properties: must be a JSON object"
                    return
                }
                cmd["properties"] = propsObj
            }
            let wrapper: [String: Any] = ["GraphAddEdge": cmd]
            let data = try JSONSerialization.data(withJSONObject: wrapper)
            let jsonStr = String(data: data, encoding: .utf8)!
            _ = try await client.executeRaw(jsonStr)
            edgeSuccess = "Edge \(edgeSrc) → \(edgeDst) (\(edgeType)) added."
        } catch {
            edgeError = error.localizedDescription
        }
    }

    private func removeEdge(graph: String) async {
        guard let client = appState.client else { return }
        edgeError = nil
        edgeSuccess = nil
        do {
            var cmd: [String: Any] = [
                "branch": appState.selectedBranch,
                "graph": graph,
                "src": edgeSrc,
                "dst": edgeDst,
                "edge_type": edgeType
            ]
            if appState.selectedSpace != "default" {
                cmd["space"] = appState.selectedSpace
            }
            let wrapper: [String: Any] = ["GraphRemoveEdge": cmd]
            let data = try JSONSerialization.data(withJSONObject: wrapper)
            let jsonStr = String(data: data, encoding: .utf8)!
            _ = try await client.executeRaw(jsonStr)
            edgeSuccess = "Edge \(edgeSrc) → \(edgeDst) (\(edgeType)) removed."
        } catch {
            edgeError = error.localizedDescription
        }
    }

    // MARK: - Neighbors

    private func findNeighbors(graph: String) async {
        guard let client = appState.client else { return }
        neighborResults = []
        neighborError = nil
        do {
            var cmd: [String: Any] = [
                "branch": appState.selectedBranch,
                "graph": graph,
                "node_id": neighborNodeId,
                "direction": neighborDirection
            ]
            if appState.selectedSpace != "default" {
                cmd["space"] = appState.selectedSpace
            }
            if let date = appState.timeTravelDate {
                cmd["as_of"] = Int64(date.timeIntervalSince1970 * 1_000_000)
            }
            if !neighborEdgeType.isEmpty {
                cmd["edge_type"] = neighborEdgeType
            }
            let wrapper: [String: Any] = ["GraphNeighbors": cmd]
            let data = try JSONSerialization.data(withJSONObject: wrapper)
            let jsonStr = String(data: data, encoding: .utf8)!
            let json = try await client.executeRaw(jsonStr)

            guard let respData = json.data(using: .utf8),
                  let root = try? JSONSerialization.jsonObject(with: respData) as? [String: Any],
                  let neighbors = root["GraphNeighbors"] as? [[String: Any]] else {
                neighborError = "No neighbors found"
                return
            }

            neighborResults = neighbors.compactMap { n in
                guard let nodeId = n["node_id"] as? String else { return nil }
                let et = n["edge_type"] as? String ?? ""
                let w = n["weight"] as? Double
                return NeighborEntry(id: UUID(), nodeId: nodeId, edgeType: et, weight: w)
            }

            if neighborResults.isEmpty {
                neighborError = "No neighbors found"
            }
        } catch {
            neighborError = error.localizedDescription
        }
    }

    // MARK: - BFS

    private func runBfs(graph: String) async {
        guard let client = appState.client else { return }
        bfsResult = nil
        bfsError = nil
        do {
            var cmd: [String: Any] = [
                "branch": appState.selectedBranch,
                "graph": graph,
                "start": bfsStart,
                "max_depth": Int(bfsMaxDepth) ?? 3,
                "max_nodes": Int(bfsMaxNodes) ?? 100,
                "direction": bfsDirection
            ]
            if appState.selectedSpace != "default" {
                cmd["space"] = appState.selectedSpace
            }
            if let date = appState.timeTravelDate {
                cmd["as_of"] = Int64(date.timeIntervalSince1970 * 1_000_000)
            }
            if !bfsEdgeTypes.isEmpty {
                cmd["edge_types"] = bfsEdgeTypes.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            }
            let wrapper: [String: Any] = ["GraphBfs": cmd]
            let data = try JSONSerialization.data(withJSONObject: wrapper)
            let jsonStr = String(data: data, encoding: .utf8)!
            let json = try await client.executeRaw(jsonStr)

            guard let respData = json.data(using: .utf8),
                  let root = try? JSONSerialization.jsonObject(with: respData) as? [String: Any],
                  let bfs = root["GraphBfs"] as? [String: Any] else {
                bfsError = "BFS returned no results"
                return
            }

            let visited = bfs["visited"] as? [String] ?? []
            let rawDepths = bfs["depths"] as? [String: Any] ?? [:]
            var depths: [String: Int] = [:]
            for (k, v) in rawDepths {
                if let d = v as? Int { depths[k] = d }
                else if let d = v as? NSNumber { depths[k] = d.intValue }
            }
            let edges = bfs["edges"] as? [[String: String]] ?? []

            bfsResult = BfsResult(visited: visited, depths: depths, edges: edges)
        } catch {
            bfsError = error.localizedDescription
        }
    }

    // MARK: - Bulk Insert

    private func bulkInsert(graph: String) async {
        guard let client = appState.client else { return }
        bulkResult = nil
        bulkError = nil
        do {
            guard let jsonData = bulkJSON.data(using: .utf8),
                  let parsed = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                bulkError = "Invalid JSON. Expected {\"nodes\": [...], \"edges\": [...]}"
                return
            }

            var cmd: [String: Any] = [
                "branch": appState.selectedBranch,
                "graph": graph
            ]
            if appState.selectedSpace != "default" {
                cmd["space"] = appState.selectedSpace
            }
            if let nodes = parsed["nodes"] {
                cmd["nodes"] = nodes
            }
            if let edges = parsed["edges"] {
                cmd["edges"] = edges
            }
            let wrapper: [String: Any] = ["GraphBulkInsert": cmd]
            let data = try JSONSerialization.data(withJSONObject: wrapper)
            let jsonStr = String(data: data, encoding: .utf8)!
            let json = try await client.executeRaw(jsonStr)

            if let respData = json.data(using: .utf8),
               let root = try? JSONSerialization.jsonObject(with: respData) as? [String: Any],
               let result = root["GraphBulkInsertResult"] as? [String: Any] {
                let nodesInserted = result["nodes_inserted"] as? Int ?? 0
                let edgesInserted = result["edges_inserted"] as? Int ?? 0
                bulkResult = "Inserted \(nodesInserted) nodes and \(edgesInserted) edges."
                await loadNodes()
            } else {
                bulkResult = "Bulk insert completed."
                await loadNodes()
            }
        } catch {
            bulkError = error.localizedDescription
        }
    }
}
