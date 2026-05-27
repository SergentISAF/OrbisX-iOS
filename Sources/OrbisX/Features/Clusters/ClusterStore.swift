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
            clusters = resp.clusters
        } catch {
            errorText = error.localizedDescription
        }
        isLoading = false
    }

    func deleteCluster(_ cluster: Cluster, email: String) async {
        do {
            struct DeleteBody: Encodable {
                let user_email: String
                let cluster_id: Int
                let inactive: Int
            }
            let body = DeleteBody(user_email: email, cluster_id: cluster.cluster_id, inactive: 1)
            _ = try await APIClient.shared.request(
                "/clusters/\(cluster.cluster_id)",
                method: "DELETE",
                body: body,
                as: EmptyResponse.self
            )
            clusters.removeAll { $0.cluster_id == cluster.cluster_id }
        } catch {
            errorText = error.localizedDescription
        }
    }
}

struct EmptyResponse: Decodable {}
