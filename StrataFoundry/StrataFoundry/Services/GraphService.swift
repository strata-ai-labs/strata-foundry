//
//  GraphService.swift
//  StrataFoundry
//
//  Graph operations.
//

import Foundation

final class GraphService: Sendable {
    private let client: StrataTypedClient
    init(client: StrataTypedClient) { self.client = client }

    func create(graph: String, cascadePolicy: String? = nil, branch: String? = nil) async throws {
        let output = try await client.execute(.graphCreate(branch: branch, graph: graph, cascadePolicy: cascadePolicy))
        guard case .unit = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Unit", got: output.variantName)
        }
    }

    func delete(graph: String, branch: String? = nil) async throws {
        let output = try await client.execute(.graphDelete(branch: branch, graph: graph))
        guard case .unit = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Unit", got: output.variantName)
        }
    }

    func list(branch: String? = nil) async throws -> [String] {
        let output = try await client.execute(.graphList(branch: branch))
        guard case .keys(let keys) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Keys", got: output.variantName)
        }
        return keys
    }

    func getMeta(graph: String, branch: String? = nil) async throws -> StrataValue? {
        let output = try await client.execute(.graphGetMeta(branch: branch, graph: graph))
        guard case .maybe(let val) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Maybe", got: output.variantName)
        }
        return val
    }

    func addNode(graph: String, nodeId: String, entityRef: String? = nil, properties: StrataValue? = nil, objectType: String? = nil, branch: String? = nil) async throws {
        let output = try await client.execute(.graphAddNode(branch: branch, graph: graph, nodeId: nodeId, entityRef: entityRef, properties: properties, objectType: objectType))
        guard case .unit = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Unit", got: output.variantName)
        }
    }

    func getNode(graph: String, nodeId: String, branch: String? = nil) async throws -> StrataValue? {
        let output = try await client.execute(.graphGetNode(branch: branch, graph: graph, nodeId: nodeId))
        guard case .maybe(let val) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Maybe", got: output.variantName)
        }
        return val
    }

    func removeNode(graph: String, nodeId: String, branch: String? = nil) async throws {
        let output = try await client.execute(.graphRemoveNode(branch: branch, graph: graph, nodeId: nodeId))
        guard case .unit = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Unit", got: output.variantName)
        }
    }

    func listNodes(graph: String, branch: String? = nil) async throws -> [String] {
        let output = try await client.execute(.graphListNodes(branch: branch, graph: graph))
        guard case .keys(let keys) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Keys", got: output.variantName)
        }
        return keys
    }

    func addEdge(graph: String, src: String, dst: String, edgeType: String, weight: Double? = nil, properties: StrataValue? = nil, branch: String? = nil) async throws {
        let output = try await client.execute(.graphAddEdge(branch: branch, graph: graph, src: src, dst: dst, edgeType: edgeType, weight: weight, properties: properties))
        guard case .unit = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Unit", got: output.variantName)
        }
    }

    func removeEdge(graph: String, src: String, dst: String, edgeType: String, branch: String? = nil) async throws {
        let output = try await client.execute(.graphRemoveEdge(branch: branch, graph: graph, src: src, dst: dst, edgeType: edgeType))
        guard case .unit = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Unit", got: output.variantName)
        }
    }

    func neighbors(graph: String, nodeId: String, direction: String? = nil, edgeType: String? = nil, branch: String? = nil) async throws -> [GraphNeighborHit] {
        let output = try await client.execute(.graphNeighbors(branch: branch, graph: graph, nodeId: nodeId, direction: direction, edgeType: edgeType))
        guard case .graphNeighbors(let hits) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "GraphNeighbors", got: output.variantName)
        }
        return hits
    }

    func bulkInsert(graph: String, nodes: [BulkGraphNode], edges: [BulkGraphEdge], chunkSize: Int? = nil, branch: String? = nil) async throws -> (nodesInserted: UInt64, edgesInserted: UInt64) {
        let output = try await client.execute(.graphBulkInsert(branch: branch, graph: graph, nodes: nodes, edges: edges, chunkSize: chunkSize))
        guard case .graphBulkInsertResult(let nodesInserted, let edgesInserted) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "GraphBulkInsertResult", got: output.variantName)
        }
        return (nodesInserted: nodesInserted, edgesInserted: edgesInserted)
    }

    func bfs(graph: String, start: String, maxDepth: Int, maxNodes: Int? = nil, edgeTypes: [String]? = nil, direction: String? = nil, branch: String? = nil) async throws -> GraphBfsResult {
        let output = try await client.execute(.graphBfs(branch: branch, graph: graph, start: start, maxDepth: maxDepth, maxNodes: maxNodes, edgeTypes: edgeTypes, direction: direction))
        guard case .graphBfs(let result) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "GraphBfs", got: output.variantName)
        }
        return result
    }

    // MARK: - Ontology

    func defineObjectType(graph: String, definition: StrataValue, branch: String? = nil) async throws {
        let output = try await client.execute(.graphDefineObjectType(branch: branch, graph: graph, definition: definition))
        guard case .unit = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Unit", got: output.variantName)
        }
    }

    func getObjectType(graph: String, name: String, branch: String? = nil) async throws -> StrataValue? {
        let output = try await client.execute(.graphGetObjectType(branch: branch, graph: graph, name: name))
        guard case .maybe(let val) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Maybe", got: output.variantName)
        }
        return val
    }

    func listObjectTypes(graph: String, branch: String? = nil) async throws -> [String] {
        let output = try await client.execute(.graphListObjectTypes(branch: branch, graph: graph))
        guard case .keys(let keys) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Keys", got: output.variantName)
        }
        return keys
    }

    func deleteObjectType(graph: String, name: String, branch: String? = nil) async throws {
        let output = try await client.execute(.graphDeleteObjectType(branch: branch, graph: graph, name: name))
        guard case .unit = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Unit", got: output.variantName)
        }
    }

    func defineLinkType(graph: String, definition: StrataValue, branch: String? = nil) async throws {
        let output = try await client.execute(.graphDefineLinkType(branch: branch, graph: graph, definition: definition))
        guard case .unit = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Unit", got: output.variantName)
        }
    }

    func getLinkType(graph: String, name: String, branch: String? = nil) async throws -> StrataValue? {
        let output = try await client.execute(.graphGetLinkType(branch: branch, graph: graph, name: name))
        guard case .maybe(let val) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Maybe", got: output.variantName)
        }
        return val
    }

    func listLinkTypes(graph: String, branch: String? = nil) async throws -> [String] {
        let output = try await client.execute(.graphListLinkTypes(branch: branch, graph: graph))
        guard case .keys(let keys) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Keys", got: output.variantName)
        }
        return keys
    }

    func deleteLinkType(graph: String, name: String, branch: String? = nil) async throws {
        let output = try await client.execute(.graphDeleteLinkType(branch: branch, graph: graph, name: name))
        guard case .unit = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Unit", got: output.variantName)
        }
    }

    func freezeOntology(graph: String, branch: String? = nil) async throws {
        let output = try await client.execute(.graphFreezeOntology(branch: branch, graph: graph))
        guard case .unit = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Unit", got: output.variantName)
        }
    }

    func ontologyStatus(graph: String, branch: String? = nil) async throws -> StrataValue? {
        let output = try await client.execute(.graphOntologyStatus(branch: branch, graph: graph))
        guard case .maybe(let val) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Maybe", got: output.variantName)
        }
        return val
    }

    func ontologySummary(graph: String, branch: String? = nil) async throws -> StrataValue? {
        let output = try await client.execute(.graphOntologySummary(branch: branch, graph: graph))
        guard case .maybe(let val) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Maybe", got: output.variantName)
        }
        return val
    }

    func nodesByType(graph: String, objectType: String, branch: String? = nil) async throws -> [String] {
        let output = try await client.execute(.graphNodesByType(branch: branch, graph: graph, objectType: objectType))
        guard case .keys(let keys) = output else {
            throw StrataServiceError.unexpectedOutput(expected: "Keys", got: output.variantName)
        }
        return keys
    }
}
