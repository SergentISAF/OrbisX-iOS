import Foundation
import SwiftUI
import Amplify
import AWSCognitoAuthPlugin

/// Cognito-backed auth-store til OrbisX v2.
///
/// Login sker via USER_SRP_AUTH (email + password) mod User Pool eu-north-1_gUBypMFpf.
/// Amplify håndterer SRP-protokollen, token-refresh og persistent session i Keychain.
///
/// VIGTIGT: `userId` cacher vi i memory som verifikations-token til backend.
/// Det må ALDRIG vises i UI, logs eller fejlbeskeder — kun email er bruger-synlig.
@MainActor
final class AuthStore: ObservableObject {
    @Published private(set) var email: String?
    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var isWorking: Bool = false

    /// Backend-side verifikation. Cache i memory only, vis aldrig.
    private(set) var userId: Int?

    private let emailKey = "orbisx.email"

    /// Hentes ved app-start. Tjekker om Amplify har en gemt session.
    func restore() async {
        do {
            let session = try await Amplify.Auth.fetchAuthSession()
            if session.isSignedIn {
                let attrs = try await Amplify.Auth.fetchUserAttributes()
                email = attrs.first(where: { $0.key == .email })?.value
                    ?? UserDefaults.standard.string(forKey: emailKey)
                isAuthenticated = true
            }
        } catch {
            // Ingen session — bruger skal logge ind. Ikke en fejl.
        }
    }

    func signIn(email: String, password: String) async throws {
        isWorking = true
        defer { isWorking = false }

        // Hvis Amplify allerede har en session (fra forrige forsøg), ryd den først.
        _ = try? await Amplify.Auth.signOut()

        let result = try await Amplify.Auth.signIn(username: email, password: password)
        guard result.isSignedIn else {
            throw AuthError.signInIncomplete(result.nextStep)
        }
        self.email = email
        UserDefaults.standard.set(email, forKey: emailKey)
        self.isAuthenticated = true
    }

    func signOut() async {
        _ = await Amplify.Auth.signOut()
        email = nil
        userId = nil
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: emailKey)
    }

    /// Cacher user_id fra første frontpage-request. Vis aldrig i UI.
    func cacheUserId(_ id: Int) {
        self.userId = id
    }
}

enum AuthError: LocalizedError {
    case signInIncomplete(AuthSignInStep)

    var errorDescription: String? {
        switch self {
        case .signInIncomplete(let step):
            return "Login ikke færdigt: \(step)"
        }
    }
}
