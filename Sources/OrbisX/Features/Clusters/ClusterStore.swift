import Foundation
import SwiftUI

/// Henter og holder brugerens cluster-liste.
///
/// Cache-first pattern: lokal cache vises straks, ferskt svar fra Mikkel
/// hentes i baggrunden og opdaterer UI når det kommer. Hvis Mikkel er nede
/// beholder vi den cached visning + viser "opdateret X siden" subtilt.
@MainActor
final class ClusterStore: ObservableObject {
    @Published var clusters: [Cluster] = []
    @Published var isLoading: Bool = false
    @Published var errorText: String?
    @Published var lastUpdated: Date?

    private let cacheKey = "orbisx.clusters"

    init() {
        // Indlæs cache straks så UI ikke flickrer ved app-start.
        if let cached = Cache.load([Cluster].self, key: cacheKey) {
            clusters = cached
            lastUpdated = Cache.timestamp(cacheKey)
        }
    }

    func load(auth: AuthStore) async {
        // Hvis vi har cached data, vis dem mens vi henter friske.
        // Hvis ikke, vis spinner.
        if clusters.isEmpty {
            isLoading = true
        }
        errorText = nil

        do {
            let userId = try await auth.ensureUserId()
            let resp = try await APIClient.shared.request(
                "/users/\(userId)/clusters",
                as: ClustersFrontpageResponse.self
            )
            clusters = resp.results
            lastUpdated = Date()
            Cache.save(resp.results, key: cacheKey)
        } catch {
            // Hvis vi har cached data, vis fejl subtilt — drop ikke listen.
            errorText = error.localizedDescription
        }
        isLoading = false
    }
}

struct EmptyResponse: Decodable {}
