import Foundation

/// Direkte REST mod Cognito User Pool — ingen SDK.
///
/// Bruger USER_PASSWORD_AUTH-flowet: app sender email+password via TLS,
/// Cognito returnerer id_token, access_token, refresh_token.
///
/// REFERENCE: https://docs.aws.amazon.com/cognito-user-identity-pools/latest/APIReference/API_InitiateAuth.html
enum CognitoAuth {
    static let region = "eu-north-1"
    static let clientId = "5m1ct7mmfgle8a9hkg7mdumkhv"

    private static let endpoint = URL(string: "https://cognito-idp.\(region).amazonaws.com/")!

    /// Logger ind med email + password. Returnerer alle tre tokens + expiry.
    static func signIn(email: String, password: String) async throws -> CognitoTokens {
        let body: [String: Any] = [
            "AuthFlow": "USER_PASSWORD_AUTH",
            "ClientId": clientId,
            "AuthParameters": [
                "USERNAME": email,
                "PASSWORD": password
            ]
        ]
        let resp: InitiateAuthResponse = try await call(target: "InitiateAuth", body: body)
        guard let result = resp.AuthenticationResult, let refresh = result.RefreshToken else {
            throw CognitoError.noAuthenticationResult
        }
        return CognitoTokens(from: result, refreshToken: refresh)
    }

    /// Henter friske id+access-tokens med refresh_token. Refresh-token genbruges.
    static func refresh(refreshToken: String) async throws -> CognitoTokens {
        let body: [String: Any] = [
            "AuthFlow": "REFRESH_TOKEN_AUTH",
            "ClientId": clientId,
            "AuthParameters": [
                "REFRESH_TOKEN": refreshToken
            ]
        ]
        let resp: InitiateAuthResponse = try await call(target: "InitiateAuth", body: body)
        guard let result = resp.AuthenticationResult else {
            throw CognitoError.noAuthenticationResult
        }
        // Cognito returnerer ikke nyt refresh_token ved refresh — behold det gamle.
        return CognitoTokens(from: result, refreshToken: refreshToken)
    }

    private static func call<Response: Decodable>(
        target: String,
        body: [String: Any]
    ) async throws -> Response {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/x-amz-json-1.1", forHTTPHeaderField: "Content-Type")
        req.setValue("AWSCognitoIdentityProviderService.\(target)", forHTTPHeaderField: "X-Amz-Target")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw CognitoError.invalidResponse
        }
        if !(200..<300).contains(http.statusCode) {
            if let err = try? JSONDecoder().decode(CognitoErrorResponse.self, from: data) {
                throw CognitoError.api(type: err.__type, message: err.message)
            }
            throw CognitoError.httpStatus(http.statusCode)
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }
}

// MARK: - Tokens

struct CognitoTokens {
    let idToken: String
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date

    init(from result: InitiateAuthResult, refreshToken: String) {
        self.idToken = result.IdToken
        self.accessToken = result.AccessToken
        self.refreshToken = refreshToken
        // Buffer 60 sek så vi refresher før udløb, ikke efter.
        self.expiresAt = Date().addingTimeInterval(TimeInterval(result.ExpiresIn - 60))
    }

    var isExpired: Bool { Date() >= expiresAt }
}

// MARK: - Wire format

struct InitiateAuthResponse: Decodable {
    let AuthenticationResult: InitiateAuthResult?
}

struct InitiateAuthResult: Decodable {
    let IdToken: String
    let AccessToken: String
    let RefreshToken: String?     // Kun ved første sign-in, ikke ved refresh
    let ExpiresIn: Int
    let TokenType: String?
}

private struct CognitoErrorResponse: Decodable {
    let __type: String?
    let message: String?
}

enum CognitoError: LocalizedError {
    case invalidResponse
    case noAuthenticationResult
    case httpStatus(Int)
    case api(type: String?, message: String?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Ugyldigt svar fra Cognito"
        case .noAuthenticationResult: return "Cognito returnerede intet authentication-result"
        case .httpStatus(let code): return "HTTP \(code) fra Cognito"
        case let .api(_, message): return message ?? "Cognito-fejl"
        }
    }
}
