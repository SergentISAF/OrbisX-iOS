import Foundation
import SwiftUI

/// Auth-store til OrbisX v2.
///
/// Login sker via Cognito USER_PASSWORD_AUTH direkte mod cognito-idp.eu-north-1.amazonaws.com
/// (se [[orbisx-cognito-auth]] memory). Vi gemmer refresh_token i Keychain så brugeren
/// ikke skal logge ind igen efter app-restart. id_token + access_token holdes i memory
/// og refreshes automatisk når de udløber (efter 1 time).
///
/// VIGTIGT: userId er backend-verifikations-token. Cache i memory only, vis aldrig.
@MainActor
final class AuthStore: ObservableObject {
    @Published private(set) var email: String?
    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var isWorking: Bool = false

    private(set) var userId: Int?

    // Memory-only token-state.
    private var tokens: CognitoTokens?

    private let refreshTokenKey = "orbisx.refresh_token"
    private let emailKey = "orbisx.email"

    /// Kører ved app-start. Hvis vi har refresh_token i Keychain, henter vi nye access-tokens.
    func restore() async {
        guard
            let refresh = Keychain.read(key: refreshTokenKey),
            let storedEmail = UserDefaults.standard.string(forKey: emailKey)
        else { return }

        do {
            let newTokens = try await CognitoAuth.refresh(refreshToken: refresh)
            self.tokens = newTokens
            self.email = storedEmail
            self.isAuthenticated = true
        } catch {
            // Refresh fejlede — refresh_token udløbet eller invalid. Ryd og forlang re-login.
            Keychain.delete(key: refreshTokenKey)
            UserDefaults.standard.removeObject(forKey: emailKey)
        }
    }

    func signIn(email: String, password: String) async throws {
        isWorking = true
        defer { isWorking = false }

        let tokens = try await CognitoAuth.signIn(email: email, password: password)
        self.tokens = tokens
        self.email = email
        Keychain.save(key: refreshTokenKey, value: tokens.refreshToken)
        UserDefaults.standard.set(email, forKey: emailKey)
        self.isAuthenticated = true
    }

    func signOut() async {
        Keychain.delete(key: refreshTokenKey)
        UserDefaults.standard.removeObject(forKey: emailKey)
        tokens = nil
        email = nil
        userId = nil
        isAuthenticated = false
    }

    func cacheUserId(_ id: Int) {
        self.userId = id
    }

    /// Returnerer et frisk id_token. Refresher automatisk hvis det er udløbet.
    /// Bruges af APIClient før hver API-request.
    func currentIdToken() async throws -> String {
        guard var tokens = self.tokens else {
            throw CognitoError.api(type: "NotAuthenticated", message: "Ikke logget ind")
        }
        if tokens.isExpired {
            tokens = try await CognitoAuth.refresh(refreshToken: tokens.refreshToken)
            self.tokens = tokens
        }
        return tokens.idToken
    }
}
