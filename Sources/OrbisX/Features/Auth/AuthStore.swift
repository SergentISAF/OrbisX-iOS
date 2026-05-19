import Foundation

@MainActor
final class AuthStore: ObservableObject {
    @Published private(set) var token: String?
    @Published private(set) var email: String?
    @Published private(set) var tenantName: String?
    @Published private(set) var userId: Int?
    @Published private(set) var tenantId: Int?
    @Published private(set) var relationshipType: RelationshipType = .sponsor
    @Published private(set) var ownBrandName: String?

    var isAuthenticated: Bool { token != nil }

    private let tokenKey = "access_token"
    private let emailKey = "email"
    private let tenantNameKey = "tenant_name"
    private let userIdKey = "user_id"
    private let tenantIdKey = "tenant_id"
    private let roleKey = "relationship_type"
    private let ownBrandKey = "own_brand_name"

    func restore() async {
        let stored = Keychain.read(key: tokenKey)
        guard let stored, !stored.isEmpty else { return }
        token = stored
        email = Keychain.read(key: emailKey)
        tenantName = Keychain.read(key: tenantNameKey)
        userId = Keychain.read(key: userIdKey).flatMap(Int.init)
        tenantId = Keychain.read(key: tenantIdKey).flatMap(Int.init)
        if let raw = Keychain.read(key: roleKey), let r = RelationshipType(rawValue: raw) {
            relationshipType = r
        }
        ownBrandName = Keychain.read(key: ownBrandKey)
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

    func signup(
        email: String,
        password: String,
        tenantName: String,
        relationshipType: RelationshipType,
        ownBrandName: String?
    ) async throws {
        let body = SignupRequest(
            email: email,
            password: password,
            tenant_name: tenantName,
            relationship_type: relationshipType.rawValue,
            own_brand_name: ownBrandName
        )
        let resp = try await APIClient.shared.request(
            "/api/auth/signup",
            method: "POST",
            body: body,
            as: TokenResponse.self
        )
        await apply(resp)
    }

    func updateTenant(relationshipType: RelationshipType?, ownBrandName: String?, name: String?) async throws {
        let body = TenantUpdate(
            relationship_type: relationshipType?.rawValue,
            own_brand_name: ownBrandName,
            name: name
        )
        let resp = try await APIClient.shared.request(
            "/api/auth/tenant",
            method: "PATCH",
            body: body,
            as: MeResponse.self
        )
        if let r = RelationshipType(rawValue: resp.relationship_type) {
            self.relationshipType = r
            Keychain.save(key: roleKey, value: resp.relationship_type)
        }
        self.ownBrandName = resp.own_brand_name
        if let v = resp.own_brand_name { Keychain.save(key: ownBrandKey, value: v) } else { Keychain.delete(key: ownBrandKey) }
        self.tenantName = resp.tenant_name
        Keychain.save(key: tenantNameKey, value: resp.tenant_name)
    }

    func logout() async {
        for k in [tokenKey, emailKey, tenantNameKey, userIdKey, tenantIdKey, roleKey, ownBrandKey] {
            Keychain.delete(key: k)
        }
        token = nil
        email = nil
        tenantName = nil
        userId = nil
        tenantId = nil
        relationshipType = .sponsor
        ownBrandName = nil
        await APIClient.shared.setToken(nil)
    }

    private func apply(_ resp: TokenResponse) async {
        Keychain.save(key: tokenKey, value: resp.access_token)
        Keychain.save(key: emailKey, value: resp.email)
        Keychain.save(key: tenantNameKey, value: resp.tenant_name)
        Keychain.save(key: userIdKey, value: String(resp.user_id))
        Keychain.save(key: tenantIdKey, value: String(resp.tenant_id))
        Keychain.save(key: roleKey, value: resp.relationship_type)
        if let own = resp.own_brand_name { Keychain.save(key: ownBrandKey, value: own) }
        token = resp.access_token
        email = resp.email
        tenantName = resp.tenant_name
        userId = resp.user_id
        tenantId = resp.tenant_id
        if let r = RelationshipType(rawValue: resp.relationship_type) {
            relationshipType = r
        }
        ownBrandName = resp.own_brand_name
        await APIClient.shared.setToken(resp.access_token)
    }
}
