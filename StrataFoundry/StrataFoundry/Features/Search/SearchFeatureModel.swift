import Foundation

struct SearchHitDisplay: Identifiable {
    let id: UUID
    let entity: String
    let primitive: String
    let score: Double
    let rank: Int
    let snippet: String
}

@Observable
final class SearchFeatureModel {
    private let searchService: SearchService
    private let appState: AppState

    // Search form
    var query = ""
    var k = "10"
    var mode = "hybrid"
    var selectedPrimitives: Set<String> = []
    var useTimeRange = false
    var startDate = Date()
    var endDate = Date()
    var expandResults = false
    var rerankResults = false

    // Results
    var results: [SearchHitDisplay] = []
    var isSearching = false
    var errorMessage: String?

    let allPrimitives = ["kv", "json", "event", "state", "vector"]

    init(searchService: SearchService, appState: AppState) {
        self.searchService = searchService
        self.appState = appState
    }

    func performSearch() async {
        results = []
        errorMessage = nil
        isSearching = true
        defer { isSearching = false }

        let branch = appState.selectedBranch
        let space: String? = appState.selectedSpace == "default" ? nil : appState.selectedSpace
        let primitives: [String]? = selectedPrimitives.isEmpty ? nil : Array(selectedPrimitives)
        let timeRange: TimeRangeInput? = useTimeRange ? TimeRangeInput(
            start: UInt64(startDate.timeIntervalSince1970 * 1_000_000),
            end: UInt64(endDate.timeIntervalSince1970 * 1_000_000)
        ) : nil

        do {
            let hits = try await searchService.search(
                query: query,
                k: UInt64(k) ?? 10,
                primitives: primitives,
                timeRange: timeRange,
                mode: mode,
                expand: expandResults ? true : nil,
                rerank: rerankResults ? true : nil,
                branch: branch,
                space: space
            )

            results = hits.enumerated().map { (index, hit) in
                SearchHitDisplay(
                    id: UUID(),
                    entity: hit.entity,
                    primitive: hit.primitive,
                    score: hit.score,
                    rank: hit.rank.map { Int($0) } ?? (index + 1),
                    snippet: hit.snippet ?? ""
                )
            }

            if results.isEmpty {
                errorMessage = "No results found"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reset() {
        results = []
        errorMessage = nil
    }
}
