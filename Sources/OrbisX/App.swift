import SwiftUI
import Amplify
import AWSCognitoAuthPlugin

@main
struct OrbisXApp: App {
    @StateObject private var auth = AuthStore()

    init() {
        Self.configureAmplify()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
        }
    }

    /// Læser amplifyconfiguration.json fra app-bundle og bootstrapper Amplify Auth.
    /// Config-detaljer: se [[orbisx-cognito-auth]] memory.
    private static func configureAmplify() {
        do {
            try Amplify.add(plugin: AWSCognitoAuthPlugin())
            try Amplify.configure()
        } catch {
            assertionFailure("Amplify-konfiguration fejlede: \(error)")
        }
    }
}

struct RootView: View {
    @EnvironmentObject var auth: AuthStore

    var body: some View {
        Group {
            if auth.isAuthenticated {
                ClusterListView()
            } else {
                LoginView()
            }
        }
        .task { await auth.restore() }
    }
}
