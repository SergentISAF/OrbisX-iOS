import SwiftUI
import SafariServices

@MainActor
final class ArticlesStore: ObservableObject {
    @Published var articles: [Article] = []
    @Published var isLoading: Bool = false
    @Published var errorText: String?

    func load(email: String, clusterId: Int) async {
        isLoading = true
        errorText = nil
        do {
            let encoded = email.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? email
            let resp = try await APIClient.shared.request(
                "/users/\(encoded)/clusters/\(clusterId)/articles?page=1&limit=50",
                as: ArticlesResponse.self
            )
            articles = resp.articles
        } catch {
            errorText = error.localizedDescription
        }
        isLoading = false
    }

    func markSeen(email: String, clusterId: Int) async {
        // POST /v2/clusters/{cluster_id}/seen?user_id=...&country=...
        // Ikke kritisk hvis den fejler — bare best effort.
        struct SeenBody: Encodable { let user_email: String }
        _ = try? await APIClient.shared.request(
            "/clusters/\(clusterId)/seen",
            method: "POST",
            body: SeenBody(user_email: email),
            as: EmptyResponse.self
        )
    }
}

struct ClusterDetailView: View {
    let cluster: Cluster

    @EnvironmentObject var auth: AuthStore
    @StateObject private var store = ArticlesStore()
    @State private var safariURL: URL?

    var body: some View {
        content
            .navigationTitle(cluster.title)
            .navigationBarTitleDisplayMode(.inline)
            .task { await refresh() }
            .refreshable { await refresh() }
            .sheet(item: $safariURL) { url in
                SafariView(url: url)
                    .ignoresSafeArea()
            }
    }

    private func refresh() async {
        guard let email = auth.email else { return }
        await store.load(email: email, clusterId: cluster.cluster_id)
        await store.markSeen(email: email, clusterId: cluster.cluster_id)
    }

    @ViewBuilder
    private var content: some View {
        if store.isLoading && store.articles.isEmpty {
            ProgressView().controlSize(.large)
        } else if let errorText = store.errorText, store.articles.isEmpty {
            VStack(spacing: 12) {
                Text("Kunne ikke hente artikler").font(.headline)
                Text(errorText).font(.footnote).foregroundStyle(.secondary)
                Button("Prøv igen") { Task { await refresh() } }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        } else if store.articles.isEmpty {
            ContentUnavailableView(
                "Ingen artikler endnu",
                systemImage: "doc.text",
                description: Text("Denne agent har ikke fundet noget endnu")
            )
        } else {
            List(store.articles) { article in
                ArticleRow(article: article)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let url = URL(string: article.url) {
                            safariURL = url
                            trackClick(article)
                        }
                    }
            }
            .listStyle(.plain)
        }
    }

    private func trackClick(_ article: Article) {
        guard let email = auth.email else { return }
        struct ClickBody: Encodable {
            let user_email: String
            let article_id: Int
        }
        Task {
            _ = try? await APIClient.shared.request(
                "/articles/\(article.article_id)/clicked",
                method: "PUT",
                body: ClickBody(user_email: email, article_id: article.article_id),
                as: EmptyResponse.self
            )
        }
    }
}

private struct ArticleRow: View {
    let article: Article

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let img = article.image_url, let url = URL(string: img) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color(.secondarySystemBackground)
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "newspaper")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 64, height: 64)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(article.title)
                    .font(.headline)
                    .lineLimit(3)
                HStack(spacing: 6) {
                    if let site = article.site_name {
                        Text(site)
                    }
                    if let date = article.published_at {
                        Text("·")
                        Text(formatRelative(date))
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

private func formatRelative(_ iso: String) -> String {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    guard let date = f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else {
        return iso
    }
    let rel = RelativeDateTimeFormatter()
    rel.locale = Locale(identifier: "da_DK")
    rel.unitsStyle = .short
    return rel.localizedString(for: date, relativeTo: Date())
}

extension URL: Identifiable {
    public var id: String { absoluteString }
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
