import SwiftUI

struct ClusterListView: View {
    @EnvironmentObject var auth: AuthStore
    @StateObject private var store = ClusterStore()
    @State private var showingCreate = false
    @State private var showingSettings = false

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
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingCreate = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .task { await refresh() }
                .refreshable { await refresh() }
                .sheet(isPresented: $showingCreate) {
                    CreateClusterSheet { _ in
                        Task { await refresh() }
                    }
                }
                .sheet(isPresented: $showingSettings) {
                    SettingsSheet()
                        .environmentObject(auth)
                }
        }
    }

    private func refresh() async {
        guard let email = auth.email else { return }
        await store.load(email: email, auth: auth)
    }

    @ViewBuilder
    private var content: some View {
        if store.isLoading && store.clusters.isEmpty {
            ProgressView().controlSize(.large)
        } else if let errorText = store.errorText, store.clusters.isEmpty {
            VStack(spacing: 12) {
                Text("Kunne ikke hente")
                    .font(.headline)
                Text(errorText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Prøv igen") {
                    Task { await refresh() }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        } else if store.clusters.isEmpty {
            ContentUnavailableView(
                "Ingen agenter endnu",
                systemImage: "antenna.radiowaves.left.and.right",
                description: Text("Opret en agent for at begynde at overvåge nyheder")
            )
        } else {
            List(store.clusters) { cluster in
                NavigationLink {
                    ClusterDetailView(cluster: cluster)
                } label: {
                    ClusterRow(cluster: cluster)
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}

private struct ClusterRow: View {
    let cluster: Cluster

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: cluster.isContextual ? "sparkles" : "magnifyingglass")
                .font(.title3)
                .foregroundStyle(cluster.isContextual ? Color.purple : Color.blue)
                .frame(width: 32, height: 32)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(cluster.title)
                    .font(.headline)
                if let search = cluster.search_text, !search.isEmpty {
                    Text(search)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                HStack(spacing: 8) {
                    if let country = cluster.country {
                        Label(country.uppercased(), systemImage: "globe")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let count = cluster.article_count {
                        Label("\(count)", systemImage: "doc.text")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if let unseen = cluster.unseen_count, unseen > 0 {
                Text("\(unseen)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var auth: AuthStore

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
        }
    }
}
