import Foundation

/// Klient mod OrbisX-værktøjets backend. Bruger Bearer-JWT i Authorization-header.
actor APIClient {
    static let shared = APIClient()

    /// Standard backend-URL. Skiftes til `app.holmstadit.dk` når Cloudflare Tunnel er opsat.
    var baseURL: URL = URL(string: "https://elpris-dashboard.tail330027.ts.net")!

    var baseURLString: String {
        let s = baseURL.absoluteString
        return s.hasSuffix("/") ? String(s.dropLast()) : s
    }

    private var token: String?

    func setToken(_ token: String?) {
        self.token = token
    }

    func request<Response: Decodable>(
        _ path: String,
        method: String = "GET",
        body: Encodable? = nil,
        as type: Response.Type
    ) async throws -> Response {
        // Vi bygger URL'en som streng for at bevare query-strings (`?` må ikke escapes).
        let normalizedPath = path.hasPrefix("/") ? path : "/" + path
        let base = baseURL.absoluteString.hasSuffix("/")
            ? String(baseURL.absoluteString.dropLast())
            : baseURL.absoluteString
        guard let url = URL(string: base + normalizedPath) else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if !(200..<300).contains(http.statusCode) {
            let detail = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.detail
            throw APIError.http(status: http.statusCode, detail: detail)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Response.self, from: data)
    }
}

enum APIError: LocalizedError {
    case invalidResponse
    case http(status: Int, detail: String?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Ugyldigt svar fra serveren"
        case let .http(status, detail):
            return detail ?? "HTTP \(status)"
        }
    }
}

private struct ErrorBody: Decodable {
    let detail: String?
}

/// Helper så vi kan encode `Encodable` direkte uden generisk param-jonglering.
private struct AnyEncodable: Encodable {
    let value: Encodable
    init(_ value: Encodable) { self.value = value }
    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}
