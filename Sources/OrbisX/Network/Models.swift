import Foundation

// MARK: - Cluster (overvågnings-agent)

/// En gemt søgning som henter artikler automatisk.
/// Type: "keyword" (eksakt match) eller "contextual" (semantisk match via embedding).
struct Cluster: Identifiable, Decodable, Hashable {
    let cluster_id: Int
    let user_cluster_id: Int?
    let title: String
    let search_text: String?
    let cluster_type: String?            // "keyword" | "contextual"
    let country: String?
    let score: Double?
    let limit: Int?
    let site_names: [String]?
    let article_count: Int?
    let unseen_count: Int?
    let last_article_at: String?
    let created_at: String?

    var id: Int { cluster_id }

    var isContextual: Bool { cluster_type == "contextual" }
}

/// Svaret fra GET /v2/users/{email}/clusters (frontpage).
/// Indeholder også user_id som vi cacher i memory (må aldrig vises i UI).
struct ClustersFrontpageResponse: Decodable {
    let user_id: Int
    let email: String
    let clusters: [Cluster]
}

// MARK: - Article

struct Article: Identifiable, Decodable, Hashable {
    let article_id: Int
    let thread_id: Int?
    let title: String
    let url: String
    let site_name: String?
    let site_id: Int?
    let published_at: String?
    let summary: String?
    let image_url: String?
    let label_ids: [Int]?
    let click_count: Int?

    var id: Int { article_id }
}

struct ArticlesResponse: Decodable {
    let articles: [Article]
    let total: Int?
    let page: Int?
    let limit: Int?
}

// MARK: - Label

struct ClusterLabel: Identifiable, Decodable, Hashable {
    let label_id: Int
    let text: String
    let color_hex: String

    var id: Int { label_id }
}

// MARK: - Trending

struct TrendingStory: Decodable, Hashable, Identifiable {
    let thread_id: Int
    let title: String
    let site_count: Int
    let article_count: Int?
    let top_url: String?
    let top_site: String?
    let image_url: String?

    var id: Int { thread_id }
}

struct TrendingResponse: Decodable {
    let stories: [TrendingStory]
}

// MARK: - Create cluster

struct CreateClusterRequest: Encodable {
    let user_email: String
    let title: String
    let search_text: String
    let cluster_type: String              // "keyword" | "contextual"
    let country: String
    let score: Double?
    let limit: Int?
    let site_names: [String]?
    let backfill: Bool?
}

struct CreateClusterResponse: Decodable {
    let cluster_id: Int
    let user_cluster_id: Int?
}

// MARK: - Sites (til site-filter ved opret)

struct Site: Decodable, Hashable, Identifiable {
    let value: Int
    let label: String

    var id: Int { value }
}
