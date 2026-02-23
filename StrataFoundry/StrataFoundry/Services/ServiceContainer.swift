//
//  ServiceContainer.swift
//  StrataFoundry
//
//  Dependency injection container creating all domain services.
//  Accessed via `appState.services`.
//

import Foundation

/// Central container for all domain services.
///
/// Created once per database session and provides typed access to every Strata primitive.
/// Services are lazy-initialized on first access.
@Observable
final class ServiceContainer {
    let transport: StrataTransport
    let client: StrataTypedClient

    init(transport: StrataTransport) {
        self.transport = transport
        self.client = StrataTypedClient(transport: transport)
    }

    // MARK: - Services (lazily created)

    private var _kvService: KVService?
    var kvService: KVService {
        if _kvService == nil { _kvService = KVService(client: client) }
        return _kvService!
    }

    private var _stateService: StateService?
    var stateService: StateService {
        if _stateService == nil { _stateService = StateService(client: client) }
        return _stateService!
    }

    private var _eventService: EventService?
    var eventService: EventService {
        if _eventService == nil { _eventService = EventService(client: client) }
        return _eventService!
    }

    private var _jsonService: JsonService?
    var jsonService: JsonService {
        if _jsonService == nil { _jsonService = JsonService(client: client) }
        return _jsonService!
    }

    private var _vectorService: VectorService?
    var vectorService: VectorService {
        if _vectorService == nil { _vectorService = VectorService(client: client) }
        return _vectorService!
    }

    private var _graphService: GraphService?
    var graphService: GraphService {
        if _graphService == nil { _graphService = GraphService(client: client) }
        return _graphService!
    }

    private var _branchService: BranchService?
    var branchService: BranchService {
        if _branchService == nil { _branchService = BranchService(client: client) }
        return _branchService!
    }

    private var _spaceService: SpaceService?
    var spaceService: SpaceService {
        if _spaceService == nil { _spaceService = SpaceService(client: client) }
        return _spaceService!
    }

    private var _searchService: SearchService?
    var searchService: SearchService {
        if _searchService == nil { _searchService = SearchService(client: client) }
        return _searchService!
    }

    private var _modelService: ModelService?
    var modelService: ModelService {
        if _modelService == nil { _modelService = ModelService(client: client) }
        return _modelService!
    }

    private var _generationService: GenerationService?
    var generationService: GenerationService {
        if _generationService == nil { _generationService = GenerationService(client: client) }
        return _generationService!
    }

    private var _adminService: AdminService?
    var adminService: AdminService {
        if _adminService == nil { _adminService = AdminService(client: client) }
        return _adminService!
    }
}
