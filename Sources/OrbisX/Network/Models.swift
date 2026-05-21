import Foundation

// MARK: - Auth

enum RelationshipType: String, Codable, CaseIterable, Identifiable {
    case sponsor      // Jeg sponsorerer andre (Carlsberg)
    case sponseret    // Jeg er sponsoreret (Aalborg Håndbold)
    case mixed        // Bureau eller blandet
    var id: String { rawValue }

    var workspaceTitle: String {
        switch self {
        case .sponsor: return "Mine sponsorater"
        case .sponseret: return "Mine sponsorer"
        case .mixed: return "Mine brands"
        }
    }

    var addLabel: String {
        switch self {
        case .sponsor: return "Tilføj sponsorat"
        case .sponseret: return "Tilføj sponsor"
        case .mixed: return "Tilføj brand"
        }
    }
}

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct SignupRequest: Encodable {
    let email: String
    let password: String
    let tenant_name: String
    let relationship_type: String
    let own_brand_name: String?
}

struct TokenResponse: Decodable {
    let access_token: String
    let user_id: Int
    let tenant_id: Int
    let email: String
    let tenant_name: String
    let relationship_type: String
    let own_brand_name: String?
}

struct MeResponse: Decodable {
    let user_id: Int
    let tenant_id: Int
    let email: String
    let tenant_name: String
    let role: String
    let relationship_type: String
    let own_brand_name: String?
}

struct TenantUpdate: Encodable {
    let relationship_type: String?
    let own_brand_name: String?
    let name: String?
}

// MARK: - Entities

struct TrackedEntity: Decodable, Identifiable, Equatable {
    let id: Int
    let name: String
    let entity_type: String
    let search_text: String
    let color: String?
    let logo_url: String?
    let sponsor_link: String?
    let last_synced_at: Date?
    let last_match_count: Int
    let last_ave_dkk: Int
}

struct EntityCreate: Encodable {
    let name: String
    let entity_type: String
    let search_text: String?
    let color: String?
    let sponsor_link: String?
}

struct SyncResult: Decodable {
    let entity_id: Int
    let articles_fetched: Int
    let articles_new: Int
    let matches_new: Int
    let last_synced_at: Date
}

// MARK: - Brand overview (genbruges til entity-detalje)

struct OutletStat: Decodable, Identifiable {
    var id: String { site_name }
    let site_name: String
    let count: Int
}

struct PublicArticle: Decodable, Identifiable {
    var id: Int { article_id }
    let article_id: Int
    let site_name: String
    let article_url: String
    let article_title: String?
    let article_created: String?
    let time_on_frontpage: Int?
    let availability: String?
}

struct SponsorshipReport: Decodable {
    let sponsored: String
    let sponsor: String?
    let total_matches: Int
    let sampled: Int
    let unique_outlets: Int
    let avg_time_on_frontpage: Double
    let top_outlets: [OutletStat]
    let top_stories: [PublicArticle]
    let ave_extrapolated_dkk: Int
}

// MARK: - Share

struct ShareLinkResponse: Decodable {
    let token: String
    let url: String
    let entity_id: Int
    let view_count: Int
}
