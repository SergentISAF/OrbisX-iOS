import SwiftUI

@main
struct OrbisXApp: App {
    @StateObject private var auth = AuthStore()

    init() {
        NotificationManager.shared.registerBackgroundTask()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(NotificationManager.shared)
                .task {
                    APIClient.shared.auth = auth
                    await NotificationManager.shared.refreshPermissionStatus()
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var auth: AuthStore

    var body: some View {
        Group {
            if auth.isAuthenticated {
                MainPager()
            } else {
                LoginView()
            }
        }
        .task { await auth.restore() }
    }
}

/// Horisontal swipe mellem app'ens hovedsider. Dot-indikator nederst.
struct MainPager: View {
    var body: some View {
        TabView {
            ClusterListView()
            CompareView()
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .ignoresSafeArea(.container, edges: .bottom)
    }
}
