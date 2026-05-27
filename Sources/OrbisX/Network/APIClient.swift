import Foundation
import Amplify
import AWSCognitoAuthPlugin
import AWSPluginsCore

/// Klient mod OrbisX v2 cloud API.
/// Henter altid frisk id_token fra Amplify før hver request — refresh håndteres automatisk.
/// API'en kræver Cognito id_token (token_use: "id"), IKKE access_token.
actor APIClient {
    static let shared = APIClient()

    private let baseURL = URL(string: "https://yifub04z0f.execute-api.eu-north-1.amazonaws.com/v2")!

    /// Henter et frisk id_token fra Amplify. Amplify refresher selv hvis det er udløbet.
    private func currentIdToken() async throws -> String {
        let session = try await Amplify.Auth.fetchAuthSession()
        guard let provider = session as? AuthCognitoTokensProvider else {
            throw APIError.notAuthenticated
        }
        let tokens = try provider.getCognitoTokens().get()
        return tokens.idToken
    }

    func request<Response: Decodable>(
        _ path: String,
        method: String = "GET",
        body: Encodable? = nil,
        as type: Response.Type
    ) async throws -> Response {
        let normalizedPath = path.hasPrefix("/") ? path : "/" + path
        let base = baseURL.absoluteString
        guard let url = URL(string: base + normalizedPath) else {
            throw APIError.invalidResponse
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let idToken = try await currentIdToken()
        req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if http.statusCode == 401 {
            throw APIError.unauthorized
        }
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
