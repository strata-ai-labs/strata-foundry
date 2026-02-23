import Foundation

enum GraphPaneMode: String, CaseIterable {
    case nodes = "Nodes"
    case edges = "Edges"
    case neighbors = "Neighbors"
    case bfs = "BFS"
    case bulkInsert = "Bulk Insert"
}

struct NeighborDisplay: Identifiable {
    let id: UUID
    let nodeId: String
    let edgeType: String
    let weight: Double?
}

struct BfsResultDisplay {
    let visited: [String]
    let depths: [String: Int]
}

@Observable
final class GraphFeatureModel {
    private let graphService: GraphService
    private let appState: AppState

    var graphs: [String] = []
    var selectedGraph: String?
    var isLoading = false
    var errorMessage: String?

    // Create graph
    var showCreateSheet = false
    var showDeleteConfirm = false
    var formGraphName = ""
    var formCascadePolicy = "none"

    // Right pane
    var graphMode: GraphPaneMode = .nodes
    var graphMeta: String?

    // Nodes
    var nodeList: [String] = []
    var nodeIdField = ""
    var nodeLabelField = ""
    var nodePropsField = ""
    var nodeResult: String?
    var nodeError: String?

    // Edges
    var edgeSrc = ""
    var edgeDst = ""
    var edgeType = ""
    var edgeWeight = ""
    var edgePropsField = ""
    var edgeError: String?
    var edgeSuccess: String?

    // Neighbors
    var neighborNodeId = ""
    var neighborDirection = "outgoing"
    var neighborEdgeType = ""
    var neighborResults: [NeighborDisplay] = []
    var neighborError: String?

    // BFS
    var bfsStart = ""
    var bfsMaxDepth = "3"
    var bfsMaxNodes = "100"
    var bfsDirection = "outgoing"
    var bfsEdgeTypes = ""
    var bfsResult: BfsResultDisplay?
    var bfsError: String?

    // Bulk Insert
    var bulkJSON = ""
    var bulkResult: String?
    var bulkError: String?

    var isTimeTraveling: Bool { appState.timeTravelDate != nil }

    init(graphService: GraphService, appState: AppState) {
        self.graphService = graphService
        self.appState = appState
    }

    // MARK: - Graph CRUD

    func loadGraphs() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            graphs = try await graphService.list(branch: appState.selectedBranch)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createGraph() async {
        let cascade: String? = formCascadePolicy == "none" ? nil : formCascadePolicy
        do {
            try await graphService.create(graph: formGraphName, cascadePolicy: cascade, branch: appState.selectedBranch)
            showCreateSheet = false
            await loadGraphs()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteGraph(_ name: String) async {
        do {
            try await graphService.delete(graph: name, branch: appState.selectedBranch)
            if selectedGraph == name { selectedGraph = nil }
            await loadGraphs()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadGraphMeta() async {
        guard let graphName = selectedGraph else { return }
        do {
            if let meta = try await graphService.getMeta(graph: graphName, branch: appState.selectedBranch) {
                graphMeta = meta.prettyJSON
            } else {
                graphMeta = ""
            }
        } catch {
            graphMeta = ""
        }
    }

    // MARK: - Node Operations

    func loadNodes() async {
        guard let graphName = selectedGraph else { return }
        do {
            nodeList = try await graphService.listNodes(graph: graphName, branch: appState.selectedBranch)
        } catch {
            nodeList = []
        }
    }

    func getNode(nodeId: String) async {
        guard let graphName = selectedGraph else { return }
        nodeResult = nil
        nodeError = nil
        do {
            if let val = try await graphService.getNode(graph: graphName, nodeId: nodeId, branch: appState.selectedBranch) {
                nodeResult = val.prettyJSON
            } else {
                nodeError = "Node \"\(nodeId)\" not found"
            }
        } catch {
            nodeError = error.localizedDescription
        }
    }

    func addNode() async {
        guard let graphName = selectedGraph else { return }
        nodeError = nil
        var properties: StrataValue? = nil
        if !nodePropsField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let parsed = StrataValue.fromJSONString(nodePropsField),
                  case .object = parsed else {
                nodeError = "Invalid properties: must be a JSON object"
                return
            }
            properties = parsed
        }
        let label: String? = nodeLabelField.isEmpty ? nil : nodeLabelField
        do {
            try await graphService.addNode(graph: graphName, nodeId: nodeIdField, entityRef: label, properties: properties, branch: appState.selectedBranch)
            await loadNodes()
            nodeResult = "Node \"\(nodeIdField)\" added."
        } catch {
            nodeError = error.localizedDescription
        }
    }

    func removeNode(nodeId: String) async {
        guard let graphName = selectedGraph else { return }
        nodeError = nil
        do {
            try await graphService.removeNode(graph: graphName, nodeId: nodeId, branch: appState.selectedBranch)
            await loadNodes()
            nodeResult = nil
        } catch {
            nodeError = error.localizedDescription
        }
    }

    // MARK: - Edge Operations

    func addEdge() async {
        guard let graphName = selectedGraph else { return }
        edgeError = nil
        edgeSuccess = nil
        var properties: StrataValue? = nil
        if !edgePropsField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let parsed = StrataValue.fromJSONString(edgePropsField),
                  case .object = parsed else {
                edgeError = "Invalid properties: must be a JSON object"
                return
            }
            properties = parsed
        }
        let weight = Double(edgeWeight)
        do {
            try await graphService.addEdge(graph: graphName, src: edgeSrc, dst: edgeDst, edgeType: edgeType, weight: weight, properties: properties, branch: appState.selectedBranch)
            edgeSuccess = "Edge \(edgeSrc) \u{2192} \(edgeDst) (\(edgeType)) added."
        } catch {
            edgeError = error.localizedDescription
        }
    }

    func removeEdge() async {
        guard let graphName = selectedGraph else { return }
        edgeError = nil
        edgeSuccess = nil
        do {
            try await graphService.removeEdge(graph: graphName, src: edgeSrc, dst: edgeDst, edgeType: edgeType, branch: appState.selectedBranch)
            edgeSuccess = "Edge \(edgeSrc) \u{2192} \(edgeDst) (\(edgeType)) removed."
        } catch {
            edgeError = error.localizedDescription
        }
    }

    // MARK: - Neighbors

    func findNeighbors() async {
        guard let graphName = selectedGraph else { return }
        neighborResults = []
        neighborError = nil
        do {
            let hits = try await graphService.neighbors(graph: graphName, nodeId: neighborNodeId, direction: neighborDirection, edgeType: neighborEdgeType.isEmpty ? nil : neighborEdgeType, branch: appState.selectedBranch)
            neighborResults = hits.map { hit in
                NeighborDisplay(id: UUID(), nodeId: hit.nodeId, edgeType: hit.edgeType, weight: hit.weight)
            }
            if neighborResults.isEmpty {
                neighborError = "No neighbors found"
            }
        } catch {
            neighborError = error.localizedDescription
        }
    }

    // MARK: - BFS

    func runBfs() async {
        guard let graphName = selectedGraph else { return }
        bfsResult = nil
        bfsError = nil
        let maxDepth = Int(bfsMaxDepth) ?? 3
        let maxNodes = Int(bfsMaxNodes) ?? 100
        let edgeTypes: [String]? = bfsEdgeTypes.isEmpty ? nil : bfsEdgeTypes.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        do {
            let result = try await graphService.bfs(graph: graphName, start: bfsStart, maxDepth: maxDepth, maxNodes: maxNodes, edgeTypes: edgeTypes, direction: bfsDirection, branch: appState.selectedBranch)
            var depths: [String: Int] = [:]
            for (k, v) in result.depths {
                depths[k] = Int(v)
            }
            bfsResult = BfsResultDisplay(visited: result.visited, depths: depths)
        } catch {
            bfsError = error.localizedDescription
        }
    }

    // MARK: - Bulk Insert

    func bulkInsert() async {
        guard let graphName = selectedGraph else { return }
        bulkResult = nil
        bulkError = nil

        guard let jsonData = bulkJSON.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            bulkError = "Invalid JSON. Expected {\"nodes\": [...], \"edges\": [...]}"
            return
        }

        var nodes: [BulkGraphNode] = []
        if let nodesArr = parsed["nodes"] as? [[String: Any]] {
            for n in nodesArr {
                guard let nodeId = n["node_id"] as? String else { continue }
                let label = n["label"] as? String
                var properties: StrataValue? = nil
                if let propsObj = n["properties"] {
                    properties = StrataValue.fromJSONObject(propsObj)
                }
                nodes.append(BulkGraphNode(nodeId: nodeId, entityRef: label, properties: properties))
            }
        }

        var edges: [BulkGraphEdge] = []
        if let edgesArr = parsed["edges"] as? [[String: Any]] {
            for e in edgesArr {
                guard let src = e["src"] as? String,
                      let dst = e["dst"] as? String,
                      let et = e["edge_type"] as? String else { continue }
                let weight = e["weight"] as? Double
                var properties: StrataValue? = nil
                if let propsObj = e["properties"] {
                    properties = StrataValue.fromJSONObject(propsObj)
                }
                edges.append(BulkGraphEdge(src: src, dst: dst, edgeType: et, weight: weight, properties: properties))
            }
        }

        do {
            let result = try await graphService.bulkInsert(graph: graphName, nodes: nodes, edges: edges, branch: appState.selectedBranch)
            bulkResult = "Inserted \(result.nodesInserted) nodes and \(result.edgesInserted) edges."
            await loadNodes()
        } catch {
            bulkError = error.localizedDescription
        }
    }

    // MARK: - State Management

    func resetRightPaneState() {
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

    func onSelectGraph(_ name: String?) {
        resetRightPaneState()
        selectedGraph = name
        if name != nil {
            Task {
                await loadGraphMeta()
                await loadNodes()
            }
        }
    }
}
