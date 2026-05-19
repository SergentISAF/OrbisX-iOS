import Foundation

@MainActor
final class AuthStore: ObservableObject {
    @Published private(set) var token: String?
    @Published private(set) var email: String?
    @Published private(set) var tenantName: String?
    @Published private(set) var userId: Int?
    @Published private(set) var tenantId: Int?

    var isAuthenticated: Bool { token != nil }

    private let tokenKey = "access_token"
    private let emailKey = "email"
    private let tenantNameKey = "tenant_name"
    private let userIdKey = "user_id"
    private let tenantIdKey = "tenant_id"

    func restore() async {
        let stored = Keychain.read(key: tokenKey)
        guard let stored, !stored.isEmpty else { return }
        token = stored
        email = Keychain.read(key: emailKey)
        tenantName = Keychain.read(key: tenantNameKey)
        userId = Keychain.read(key: userIdKey).flatMap(Int.init)
        tenantId = Keychain.read(key: tenantIdKey).flatMap(Int.init)
        await APIClient.shared.setToken(stored)
    }

    func login(email: String, password: String) async throws {
        let body = LoginRequest(email: email, password: password)
        let resp = try await APIClient.shared.request(
            "/api/auth/login",
            method: "POST",
            body: body,
            as: TokenResponse.self
        )
        await apply(resp)
    }

    func signup(email: String, password: String, tenantName: String) async throws {
        let body = SignupRequest(email: email, password: password, tenant_name: tenantName)
        let resp = try await APIClient.shared.request(
            "/api/auth/signup",
            method: "POST",
            body: body,
            as: TokenResponse.self
        )
        await apply(resp)
    }

    func logout() async {
        Keychain.delete(key: tokenKey)
        Keychain.delete(key: emailKey)
        Keychain.delete(key: tenantNameKey)
        Keychain.delete(key: userIdKey)
        Keychain.delete(key: tenantIdKey)
        token = nil
        email = nil
        tenantName = nil
        userId = nil
        tenantId = nil
        await APIClient.shared.setToken(nil)
    }

    private func apply(_ resp: TokenResponse) async {
        Keychain.save(key: tokenKey, value: resp.access_token)
        Keychain.save(key: emailKey, value: resp.email)
        Keychain.save(key: tenantNameKey, value: resp.tenant_name)
        Keychain.save(key: userIdKey, value: String(resp.user_id))
        Keychain.save(key: tenantIdKey, value: String(resp.tenant_id))
        token = resp.access_token
        email = resp.email
        tenantName = resp.tenant_name
        userId = resp.user_id
        tenantId = resp.tenant_id
        await APIClient.shared.setToken(resp.access_token)
    }
}
