import Foundation

// MARK: - Cluster (overvågnings-agent)
//
// Schema fra https://yifub04z0f.execute-api.eu-north-1.amazonaws.com/v2/openapi.json
// (FrontPageResponse + ClusterSummary, snake_case).

/// En agent (= et "user_cluster") set fra brugerens perspektiv.
struct Cluster: Identifiable, Decodable, Hashable {
    let user_cluster_id: Int
    let user_cluster_created_at: String?
    let cluster_type: String?
    let cluster_last_seen: String?
    let last_article_created_at: String?
    let new_articles: Int
    let title: String?
    let total_cluster_articles: Int
    let country: String?
    let total_expected_views: String?
    let owner_id: Int?

    var id: Int { user_cluster_id }
    var displayTitle: String { title ?? "Uden navn" }
    var isContextual: Bool { (cluster_type ?? "").lowercased() == "contextual" }
}

/// GET /v2/users/{email-or-id}/clusters response.
struct ClustersFrontpageResponse: Decodable {
    let user_id: String
    let results: [Cluster]
}

// MARK: - Article (artikel-bundle / story-thread inden i en cluster)
//
// Mikkels "Article" er reelt en gruppering: én post pr. thread med op til 2 titler,
// last_article_url + last_article_id som "den seneste artikel i tråden".

struct Article: Identifiable, Decodable, Hashable {
    let last_article_id: Int?
    let thread_id: Int?
    let article_title_1: String?
    let article_title_2: String?
    let last_article_url: String?
    let last_article_created_at: String?
    let first_article_created_at: String?
    let total_articles: Int
    let site_names: [String]
    let minutes_on_frontpage: Int
    let article_extract: [String]
    let clicked: String?
    let country: String?

    /// Stable id for SwiftUI lists — vi bruger thread_id når den findes, ellers last_article_id.
    var id: Int { thread_id ?? last_article_id ?? Int.random(in: 0..<Int.max) }

    var displayTitle: String { article_title_1 ?? article_title_2 ?? "Uden titel" }
    var displaySite: String? { site_names.first }
}

struct ClusterArticlesResponse: Decodable {
    let user_id: String
    let user_cluster_id: Int
    let results: [Article]
}

// MARK: - Create cluster

/// POST /v2/clusters request body.
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
    let cluster_id: Int?
    let user_cluster_id: Int?
}

// MARK: - Trending (til discovery senere)

struct TrendingStory: Decodable, Hashable, Identifiable {
    let thread_id: Int
    let title: String?
    let site_count: Int?
    let top_url: String?
    let top_site: String?
    let image_url: String?

    var id: Int { thread_id }
}

struct TrendingResponse: Decodable {
    let stories: [TrendingStory]
}
