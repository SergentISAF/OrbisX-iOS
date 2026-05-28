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
                "/users/\(encoded)/clusters/\(clusterId)/articles?page=0&limit=50",
                as: ClusterArticlesResponse.self
            )
            articles = resp.results
        } catch {
            errorText = error.localizedDescription
        }
        isLoading = false
    }
}

struct ClusterDetailView: View {
    let cluster: Cluster

    @EnvironmentObject var auth: AuthStore
    @StateObject private var store = ArticlesStore()
    @State private var safariURL: URL?

    var body: some View {
        content
            .navigationTitle(cluster.displayTitle)
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
        await store.load(email: email, clusterId: cluster.user_cluster_id)
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
                        if let url = article.last_article_url.flatMap(URL.init) {
                            safariURL = url
                        }
                    }
            }
            .listStyle(.plain)
        }
    }
}

private struct ArticleRow: View {
    let article: Article

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(article.displayTitle)
                .font(.headline)
                .lineLimit(3)

            if !article.article_extract.isEmpty {
                Text(article.article_extract.joined(separator: " "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 6) {
                if let site = article.displaySite {
                    Text(site)
                }
                if article.total_articles > 1 {
                    Text("·")
                    Text("\(article.total_articles) artikler")
                }
                if let date = article.last_article_created_at {
                    Text("·")
                    Text(formatRelative(date))
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
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
