import Foundation

enum GraphPaneMode: String, CaseIterable {
    case nodes = "Nodes"
    case edges = "Edges"
    case neighbors = "Neighbors"
    case bfs = "BFS"
    case visualize = "Visualize"
    case bulkInsert = "Bulk Insert"
    case ontology = "Ontology"
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

    // Visualization
    var vizNodes: [GraphCanvasNode] = []
    var vizEdges: [GraphCanvasEdge] = []
    var isLoadingViz = false
    var vizError: String?

    // Ontology
    var ontologyStatusText: String?
    var objectTypes: [String] = []
    var linkTypes: [String] = []
    var selectedObjectType: String?
    var selectedLinkType: String?
    var objectTypeDetail: String?
    var linkTypeDetail: String?
    var ontologySummaryText: String?
    var ontologyError: String?
    var ontologySuccess: String?

    // Define object type form
    var defineObjectTypeName = ""
    var defineObjectTypeJSON = ""

    // Define link type form
    var defineLinkTypeName = ""
    var defineLinkTypeSource = ""
    var defineLinkTypeTarget = ""
    var defineLinkTypeCardinality = ""
    var defineLinkTypeJSON = ""

    // Nodes by type
    var nodesByTypeResult: [String] = []
    var nodesByTypeSelected: String?

    // Node object type field (for Add Node form)
    var nodeObjectTypeField = ""

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
        let objectType: String? = nodeObjectTypeField.isEmpty ? nil : nodeObjectTypeField
        do {
            try await graphService.addNode(graph: graphName, nodeId: nodeIdField, entityRef: label, properties: properties, objectType: objectType, branch: appState.selectedBranch)
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

    // MARK: - Visualization

    func loadVisualizationData() async {
        guard let graphName = selectedGraph else { return }
        isLoadingViz = true
        vizError = nil
        defer { isLoadingViz = false }

        do {
            // Use all nodes from nodeList as starting points; do BFS from first node
            if nodeList.isEmpty {
                await loadNodes()
            }
            guard let startNode = nodeList.first else {
                vizError = "No nodes in graph"
                return
            }

            let result = try await graphService.bfs(
                graph: graphName,
                start: startNode,
                maxDepth: 100,
                maxNodes: 500,
                direction: "both",
                branch: appState.selectedBranch
            )

            // Build node set from visited nodes
            var nodeIds = Set(result.visited)

            // Also add any nodes not reachable from BFS (disconnected components)
            for nodeId in nodeList.prefix(500) {
                nodeIds.insert(nodeId)
            }

            vizNodes = nodeIds.map { GraphCanvasNode(id: $0, label: $0) }

            // Build edges from BFS result
            var edgeSet = Set<String>()
            var edges: [GraphCanvasEdge] = []
            for parsed in result.parsedEdges {
                let edgeId = "\(parsed.src)->\(parsed.dst):\(parsed.edgeType)"
                if edgeSet.insert(edgeId).inserted {
                    edges.append(GraphCanvasEdge(
                        id: edgeId,
                        source: parsed.src,
                        target: parsed.dst,
                        edgeType: parsed.edgeType
                    ))
                }
            }
            vizEdges = edges
        } catch {
            vizError = error.localizedDescription
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
        vizNodes = []
        vizEdges = []
        isLoadingViz = false
        vizError = nil
        ontologyStatusText = nil
        objectTypes = []
        linkTypes = []
        selectedObjectType = nil
        selectedLinkType = nil
        objectTypeDetail = nil
        linkTypeDetail = nil
        ontologySummaryText = nil
        ontologyError = nil
        ontologySuccess = nil
        defineObjectTypeName = ""
        defineObjectTypeJSON = ""
        defineLinkTypeName = ""
        defineLinkTypeSource = ""
        defineLinkTypeTarget = ""
        defineLinkTypeCardinality = ""
        defineLinkTypeJSON = ""
        nodesByTypeResult = []
        nodesByTypeSelected = nil
        nodeObjectTypeField = ""
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

    // MARK: - Ontology

    func loadOntology() async {
        guard let graphName = selectedGraph else { return }
        ontologyError = nil
        do {
            async let statusResult = graphService.ontologyStatus(graph: graphName, branch: appState.selectedBranch)
            async let objectTypesResult = graphService.listObjectTypes(graph: graphName, branch: appState.selectedBranch)
            async let linkTypesResult = graphService.listLinkTypes(graph: graphName, branch: appState.selectedBranch)

            let status = try await statusResult
            objectTypes = try await objectTypesResult
            linkTypes = try await linkTypesResult

            if let statusVal = status {
                // Extract the status string from the response.
                // The backend may return {"status":"frozen",...} or just "frozen".
                switch statusVal {
                case .string(let s):
                    ontologyStatusText = s
                case .object(let map):
                    if case .string(let s) = map["status"] {
                        ontologyStatusText = s
                    } else {
                        ontologyStatusText = statusVal.prettyJSON
                    }
                default:
                    ontologyStatusText = statusVal.prettyJSON
                }
            } else {
                ontologyStatusText = "draft"
            }
        } catch {
            ontologyError = error.localizedDescription
        }
    }

    func defineObjectType() async {
        guard let graphName = selectedGraph else { return }
        ontologyError = nil
        ontologySuccess = nil

        let name = defineObjectTypeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            ontologyError = "Object type name is required"
            return
        }

        var propertiesMap: [String: StrataValue] = [:]
        let jsonTrimmed = defineObjectTypeJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        if !jsonTrimmed.isEmpty {
            guard let parsed = StrataValue.fromJSONString(jsonTrimmed),
                  case .object = parsed else {
                ontologyError = "Invalid properties: must be a JSON object"
                return
            }
            if case .object(let map) = parsed {
                propertiesMap = map
            }
        }

        var definitionMap: [String: StrataValue] = [
            "name": .string(name),
        ]
        if !propertiesMap.isEmpty {
            definitionMap["properties"] = .object(propertiesMap)
        }
        let definition = StrataValue.object(definitionMap)

        do {
            try await graphService.defineObjectType(graph: graphName, definition: definition, branch: appState.selectedBranch)
            ontologySuccess = "Object type \"\(name)\" defined."
            defineObjectTypeName = ""
            defineObjectTypeJSON = ""
            await loadOntology()
        } catch {
            ontologyError = error.localizedDescription
        }
    }

    func defineLinkType() async {
        guard let graphName = selectedGraph else { return }
        ontologyError = nil
        ontologySuccess = nil

        let name = defineLinkTypeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            ontologyError = "Link type name is required"
            return
        }

        var definitionMap: [String: StrataValue] = [
            "name": .string(name),
        ]
        let source = defineLinkTypeSource.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = defineLinkTypeTarget.trimmingCharacters(in: .whitespacesAndNewlines)
        let cardinality = defineLinkTypeCardinality.trimmingCharacters(in: .whitespacesAndNewlines)

        if !source.isEmpty { definitionMap["source_type"] = .string(source) }
        if !target.isEmpty { definitionMap["target_type"] = .string(target) }
        if !cardinality.isEmpty { definitionMap["cardinality"] = .string(cardinality) }

        let jsonTrimmed = defineLinkTypeJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        if !jsonTrimmed.isEmpty {
            guard let parsed = StrataValue.fromJSONString(jsonTrimmed),
                  case .object(let map) = parsed else {
                ontologyError = "Invalid properties: must be a JSON object"
                return
            }
            definitionMap["properties"] = .object(map)
        }

        let definition = StrataValue.object(definitionMap)

        do {
            try await graphService.defineLinkType(graph: graphName, definition: definition, branch: appState.selectedBranch)
            ontologySuccess = "Link type \"\(name)\" defined."
            defineLinkTypeName = ""
            defineLinkTypeSource = ""
            defineLinkTypeTarget = ""
            defineLinkTypeCardinality = ""
            defineLinkTypeJSON = ""
            await loadOntology()
        } catch {
            ontologyError = error.localizedDescription
        }
    }

    func getObjectTypeDetail(_ name: String) async {
        guard let graphName = selectedGraph else { return }
        ontologyError = nil
        selectedObjectType = name
        objectTypeDetail = nil
        do {
            if let val = try await graphService.getObjectType(graph: graphName, name: name, branch: appState.selectedBranch) {
                objectTypeDetail = val.prettyJSON
            } else {
                objectTypeDetail = "Not found"
            }
        } catch {
            ontologyError = error.localizedDescription
        }
    }

    func getLinkTypeDetail(_ name: String) async {
        guard let graphName = selectedGraph else { return }
        ontologyError = nil
        selectedLinkType = name
        linkTypeDetail = nil
        do {
            if let val = try await graphService.getLinkType(graph: graphName, name: name, branch: appState.selectedBranch) {
                linkTypeDetail = val.prettyJSON
            } else {
                linkTypeDetail = "Not found"
            }
        } catch {
            ontologyError = error.localizedDescription
        }
    }

    func deleteObjectType(_ name: String) async {
        guard let graphName = selectedGraph else { return }
        ontologyError = nil
        ontologySuccess = nil
        do {
            try await graphService.deleteObjectType(graph: graphName, name: name, branch: appState.selectedBranch)
            ontologySuccess = "Object type \"\(name)\" deleted."
            if selectedObjectType == name { objectTypeDetail = nil; selectedObjectType = nil }
            await loadOntology()
        } catch {
            ontologyError = error.localizedDescription
        }
    }

    func deleteLinkType(_ name: String) async {
        guard let graphName = selectedGraph else { return }
        ontologyError = nil
        ontologySuccess = nil
        do {
            try await graphService.deleteLinkType(graph: graphName, name: name, branch: appState.selectedBranch)
            ontologySuccess = "Link type \"\(name)\" deleted."
            if selectedLinkType == name { linkTypeDetail = nil; selectedLinkType = nil }
            await loadOntology()
        } catch {
            ontologyError = error.localizedDescription
        }
    }

    func freezeOntology() async {
        guard let graphName = selectedGraph else { return }
        ontologyError = nil
        ontologySuccess = nil
        do {
            try await graphService.freezeOntology(graph: graphName, branch: appState.selectedBranch)
            ontologySuccess = "Ontology frozen."
            await loadOntology()
        } catch {
            ontologyError = error.localizedDescription
        }
    }

    func loadOntologySummary() async {
        guard let graphName = selectedGraph else { return }
        ontologyError = nil
        ontologySummaryText = nil
        do {
            if let val = try await graphService.ontologySummary(graph: graphName, branch: appState.selectedBranch) {
                ontologySummaryText = val.prettyJSON
            } else {
                ontologySummaryText = "No ontology summary available"
            }
        } catch {
            ontologyError = error.localizedDescription
        }
    }

    func loadNodesByType(_ objectType: String) async {
        guard let graphName = selectedGraph else { return }
        ontologyError = nil
        nodesByTypeResult = []
        nodesByTypeSelected = objectType
        do {
            nodesByTypeResult = try await graphService.nodesByType(graph: graphName, objectType: objectType, branch: appState.selectedBranch)
        } catch {
            ontologyError = error.localizedDescription
        }
    }

    var isOntologyFrozen: Bool {
        guard let status = ontologyStatusText else { return false }
        return status.lowercased() == "frozen"
    }
}
