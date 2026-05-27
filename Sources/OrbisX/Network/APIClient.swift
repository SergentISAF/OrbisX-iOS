import Foundation

/// Klient mod OrbisX v2 cloud API.
/// Henter altid frisk id_token fra AuthStore før hver request — refresh håndteres der.
/// API'en kræver Cognito id_token (token_use: "id"), IKKE access_token.
@MainActor
final class APIClient {
    static let shared = APIClient()

    weak var auth: AuthStore?

    private let baseURL = URL(string: "https://yifub04z0f.execute-api.eu-north-1.amazonaws.com/v2")!

    func request<Response: Decodable>(
        _ path: String,
        method: String = "GET",
        body: Encodable? = nil,
        as type: Response.Type
    ) async throws -> Response {
        guard let auth else { throw APIError.notAuthenticated }
        let idToken = try await auth.currentIdToken()

        let normalizedPath = path.hasPrefix("/") ? path : "/" + path
        guard let url = URL(string: baseURL.absoluteString + normalizedPath) else {
            throw APIError.invalidResponse
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if http.statusCode == 401 { throw APIError.unauthorized }
        if !(200..<300).contains(http.statusCode) {
            let detail = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.detail
                ?? String(data: data, encoding: .utf8)
            throw APIError.http(status: http.statusCode, detail: detail)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Response.self, from: data)
    }
}

enum APIError: LocalizedError {
    case invalidResponse
    case notAuthenticated
    case unauthorized
    case http(status: Int, detail: String?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Ugyldigt svar fra serveren"
        case .notAuthenticated: return "Ikke logget ind"
        case .unauthorized: return "Session udløbet — log ind igen"
        case let .http(status, detail): return detail ?? "HTTP \(status)"
        }
    }
}

private struct ErrorBody: Decodable {
    let detail: String?
}

private struct AnyEncodable: Encodable {
    let value: Encodable
    init(_ value: Encodable) { self.value = value }
    func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
}
