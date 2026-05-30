import SwiftUI
import UIKit

enum ClusterSort: String, CaseIterable, Identifiable {
    case newest
    case mostNew
    case mostArticles
    case titleAZ

    var id: String { rawValue }
    var label: String {
        switch self {
        case .newest: return "Senest opdateret"
        case .mostNew: return "Flest nye"
        case .mostArticles: return "Flest artikler"
        case .titleAZ: return "Titel A–Å"
        }
    }
    var systemImage: String {
        switch self {
        case .newest: return "clock"
        case .mostNew: return "bell.badge"
        case .mostArticles: return "doc.text"
        case .titleAZ: return "textformat.abc"
        }
    }
}

struct ClusterListView: View {
    @EnvironmentObject var auth: AuthStore
    @StateObject private var store = ClusterStore()
    @State private var showingCreate = false
    @State private var showingSettings = false
    @State private var searchText = ""
    @AppStorage("orbisx.sort") private var sortRaw: String = ClusterSort.newest.rawValue

    private var sort: ClusterSort {
        ClusterSort(rawValue: sortRaw) ?? .newest
    }

    private var visibleClusters: [Cluster] {
        let filtered: [Cluster]
        if searchText.isEmpty {
            filtered = store.clusters
        } else {
            let q = searchText.lowercased()
            filtered = store.clusters.filter {
                ($0.title ?? "").lowercased().contains(q) ||
                ($0.country ?? "").lowercased().contains(q)
            }
        }
        switch sort {
        case .newest:
            return filtered.sorted { ($0.last_article_created_at ?? "") > ($1.last_article_created_at ?? "") }
        case .mostNew:
            return filtered.sorted { $0.new_articles > $1.new_articles }
        case .mostArticles:
            return filtered.sorted { $0.total_cluster_articles > $1.total_cluster_articles }
        case .titleAZ:
            return filtered.sorted { ($0.title ?? "") < ($1.title ?? "") }
        }
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Mine agenter")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "person.crop.circle")
                                .font(.title3)
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Section("Sortér efter") {
                                ForEach(ClusterSort.allCases) { option in
                                    Button {
                                        sortRaw = option.rawValue
                                    } label: {
                                        Label(option.label, systemImage: option.systemImage)
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.title3)
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingCreate = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.title3)
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "Søg agenter")
                .task { await refresh() }
                .refreshable { await refresh() }
                .sheet(isPresented: $showingCreate) {
                    CreateClusterSheet {
                        Task { await refresh() }
                    }
                }
                .sheet(isPresented: $showingSettings) {
                    SettingsSheet()
                        .environmentObject(auth)
                        .environmentObject(NotificationManager.shared)
                }
        }
    }

    private func refresh() async {
        await store.load(auth: auth)
    }

    @ViewBuilder
    private var content: some View {
        if store.isLoading && store.clusters.isEmpty {
            ProgressView().controlSize(.large)
        } else if let errorText = store.errorText, store.clusters.isEmpty {
            ErrorState(text: errorText) { Task { await refresh() } }
        } else if store.clusters.isEmpty {
            ContentUnavailableView(
                "Ingen agenter endnu",
                systemImage: "antenna.radiowaves.left.and.right",
                description: Text("Opret en agent for at begynde at overvåge nyheder")
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 12, pinnedViews: []) {
                    UpdatedBanner(date: store.lastUpdated, error: store.errorText)

                    HStack(alignment: .firstTextBaseline) {
                        Text("\(visibleClusters.count) \(visibleClusters.count == 1 ? "agent" : "agenter")")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 4)

                    ForEach(visibleClusters) { cluster in
                        NavigationLink {
                            ClusterDetailView(cluster: cluster)
                        } label: {
                            ClusterCard(cluster: cluster)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .overlay(alignment: .center) {
                if visibleClusters.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
    }
}

private struct ErrorState: View {
    let text: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("Kunne ikke hente")
                .font(.headline)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Prøv igen", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

private struct UpdatedBanner: View {
    let date: Date?
    let error: String?

    private var relativeText: String {
        guard let date else { return "" }
        let rel = RelativeDateTimeFormatter()
        rel.locale = Locale(identifier: "da_DK")
        rel.unitsStyle = .short
        return rel.localizedString(for: date, relativeTo: Date())
    }

    var body: some View {
        if let error {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Viser cached data")
                        .font(.caption.weight(.medium))
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(12)
            .background(Color.orange.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        } else if let date {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
                Text("Opdateret \(relativeText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 4)
        }
    }
}

private struct ClusterCard: View {
    let cluster: Cluster

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Type-indikator: keyword vs contextual
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(typeColor.opacity(0.15))
                Image(systemName: cluster.isContextual ? "sparkles" : "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(typeColor)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 6) {
                Text(cluster.displayTitle)
                    .font(.system(.headline, design: .default, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    if let country = cluster.country {
                        Text(flagEmoji(for: country))
                            .font(.caption)
                    }
                    Label("\(cluster.total_cluster_articles)", systemImage: "doc.text.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    if let updated = cluster.last_article_created_at, updated != "No Time" {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Label(updated, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .labelStyle(.titleOnly)
                    }
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                if cluster.new_articles > 0 {
                    Text("\(cluster.new_articles) nye")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.black.opacity(0.04), lineWidth: 0.5)
        )
    }

    private var typeColor: Color {
        cluster.isContextual ? .purple : .blue
    }

    private func flagEmoji(for country: String) -> String {
        switch country.lowercased() {
        case "dk": return "🇩🇰"
        case "se": return "🇸🇪"
        case "no": return "🇳🇴"
        case "gb": return "🇬🇧"
        case "fi": return "🇫🇮"
        case "de": return "🇩🇪"
        default: return "🌐"
        }
    }
}

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var auth: AuthStore
    @EnvironmentObject var notifications: NotificationManager
    @State private var permissionDeniedAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Konto") {
                    HStack {
                        Text("Email")
                        Spacer()
                        Text(auth.email ?? "—")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Toggle("Notificér mig om nye artikler", isOn: notificationsBinding)
                } header: {
                    Text("Notifikationer")
                } footer: {
                    Text(notificationsFooter)
                }

                Section {
                    Link("Åbn orbisx.ai", destination: URL(string: "https://orbisx.ai")!)
                }
                Section {
                    Button("Log ud", role: .destructive) {
                        Task {
                            await auth.signOut()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Indstillinger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Luk") { dismiss() }
                }
            }
            .alert("Tilladelse til notifikationer", isPresented: $permissionDeniedAlert) {
                Button("Åbn Indstillinger") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Annullér", role: .cancel) {}
            } message: {
                Text("Notifikationer er slået fra for OrbisX. Slå det til i iOS Indstillinger for at få besked om nye artikler.")
            }
        }
    }

    private var notificationsBinding: Binding<Bool> {
        Binding(
            get: { notifications.isEnabled && notifications.permissionStatus == .authorized },
            set: { newValue in
                if newValue {
                    Task {
                        if notifications.permissionStatus == .notDetermined {
                            let granted = await notifications.requestPermission()
                            notifications.isEnabled = granted
                        } else if notifications.permissionStatus == .denied {
                            permissionDeniedAlert = true
                        } else {
                            notifications.isEnabled = true
                        }
                    }
                } else {
                    notifications.isEnabled = false
                }
            }
        )
    }

    private var notificationsFooter: String {
        switch notifications.permissionStatus {
        case .denied:
            return "Tilladelse afvist. Åbn iOS Indstillinger → OrbisX → Notifikationer for at slå til."
        case .authorized, .provisional, .ephemeral:
            return notifications.isEnabled
                ? "OrbisX tjekker dine agenter i baggrunden (cirka hvert 30 min). iOS bestemmer den præcise tid."
                : "Slå til for at få besked når dine agenter finder nye artikler."
        case .notDetermined:
            return "Du bliver spurgt om tilladelse første gang."
        @unknown default:
            return ""
        }
    }
}
