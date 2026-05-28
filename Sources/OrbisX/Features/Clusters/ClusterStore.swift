import Foundation
import SwiftUI

/// Henter og holder brugerens cluster-liste.
/// Første kald cacher også user_id i AuthStore — bruges internt, vises aldrig.
@MainActor
final class ClusterStore: ObservableObject {
    @Published var clusters: [Cluster] = []
    @Published var isLoading: Bool = false
    @Published var errorText: String?

    func load(email: String, auth: AuthStore) async {
        isLoading = true
        errorText = nil
        do {
            let encoded = email.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? email
            let resp = try await APIClient.shared.request(
                "/users/\(encoded)/clusters",
                as: ClustersFrontpageResponse.self
            )
            auth.cacheUserId(resp.user_id)
            clusters = resp.results
        } catch {
            errorText = error.localizedDescription
        }
        isLoading = false
    }
}

struct EmptyResponse: Decodable {}
