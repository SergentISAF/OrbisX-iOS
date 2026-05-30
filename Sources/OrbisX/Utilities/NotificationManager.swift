#if canImport(UIKit)
import UIKit
#endif
import Foundation
import UserNotifications
import BackgroundTasks

/// Håndterer lokal notifikation om nye artikler i brugerens agenter.
///
/// **Hvordan det virker:**
/// 1. Brugeren slår notifikationer til i Indstillinger → kalder `enable()`
/// 2. Vi registrerer en background-task som iOS planlægger (typisk hvert 30+ min)
/// 3. Når den fyrer: vi fetcher clusters, sammenligner `new_articles` med sidste snapshot
/// 4. Hvis en cluster har flere nye end før: lokal notifikation med titel + antal
///
/// **iOS begrænsninger:** Apple styrer hvornår background fetch faktisk kører.
/// Det kan være 30 min, 1 time, eller flere timer mellem hver. Bruger skal også
/// have "Background App Refresh" slået til i Indstillinger.
@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    static let taskIdentifier = "dk.holmstadit.orbisx.refresh"
    private let enabledKey = "orbisx.notifications.enabled"
    private let snapshotKey = "orbisx.notifications.snapshot"

    @Published private(set) var permissionStatus: UNAuthorizationStatus = .notDetermined
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: enabledKey)
            if isEnabled {
                scheduleNextRefresh()
            } else {
                BGTaskScheduler.shared.cancelAllTaskRequests()
            }
        }
    }

    private init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
        Task { await refreshPermissionStatus() }
    }

    func refreshPermissionStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        permissionStatus = settings.authorizationStatus
    }

    /// Beder brugeren om tilladelse. Returnerer true hvis godkendt.
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            await refreshPermissionStatus()
            return granted
        } catch {
            return false
        }
    }

    /// Registrerer background-task handler. Kald én gang ved app-start.
    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { task in
            Task { @MainActor in
                await self.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
            }
        }
    }

    /// Planlæg næste refresh. Skal kaldes hver gang vi fuldfører en, samt når brugeren toggler ON.
    func scheduleNextRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        // Tidligst 30 min fra nu — iOS bestemmer den faktiske tid.
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handleBackgroundRefresh(task: BGAppRefreshTask) async {
        // Planlæg næste runde først — så vi får én næste gang også selv om vi crasher.
        scheduleNextRefresh()

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        guard isEnabled, permissionStatus == .authorized else {
            task.setTaskCompleted(success: true)
            return
        }

        do {
            let auth = await AuthStore.persistedAuthForBackground()
            guard let auth else {
                task.setTaskCompleted(success: true)
                return
            }
            let userId = try await auth.ensureUserId()
            let resp = try await APIClient.shared.request(
                "/users/\(userId)/clusters",
                as: ClustersFrontpageResponse.self
            )
            let snapshot = loadSnapshot()
            var newSnapshot: [Int: Int] = [:]
            for cluster in resp.results {
                newSnapshot[cluster.user_cluster_id] = cluster.new_articles
                let previous = snapshot[cluster.user_cluster_id] ?? 0
                if cluster.new_articles > previous {
                    let delta = cluster.new_articles - previous
                    fireNotification(for: cluster, delta: delta)
                }
            }
            saveSnapshot(newSnapshot)
            Cache.save(resp.results, key: "orbisx.clusters")
            task.setTaskCompleted(success: true)
        } catch {
            task.setTaskCompleted(success: false)
        }
    }

    private func fireNotification(for cluster: Cluster, delta: Int) {
        let content = UNMutableNotificationContent()
        content.title = cluster.displayTitle
        content.body = delta == 1 ? "1 ny artikel" : "\(delta) nye artikler"
        content.sound = .default
        content.badge = NSNumber(value: delta)

        let request = UNNotificationRequest(
            identifier: "cluster-\(cluster.user_cluster_id)-\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func loadSnapshot() -> [Int: Int] {
        guard let data = UserDefaults.standard.data(forKey: snapshotKey),
              let raw = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return [:]
        }
        var out: [Int: Int] = [:]
        for (k, v) in raw { if let i = Int(k) { out[i] = v } }
        return out
    }

    private func saveSnapshot(_ snap: [Int: Int]) {
        let raw = Dictionary(uniqueKeysWithValues: snap.map { (String($0.key), $0.value) })
        if let data = try? JSONEncoder().encode(raw) {
            UserDefaults.standard.set(data, forKey: snapshotKey)
        }
    }
}

extension AuthStore {
    /// Bruges af background-task som ikke har @EnvironmentObject. Henter cached refresh-token
    /// og bygger en authstore op uden UI.
    static func persistedAuthForBackground() async -> AuthStore? {
        let store = AuthStore()
        await store.restore()
        return store.isAuthenticated ? store : nil
    }
}
