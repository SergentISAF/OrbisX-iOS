import SwiftUI

@main
struct OrbisXApp: App {
    @StateObject private var auth = AuthStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .task {
                    APIClient.shared.auth = auth
                }
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
