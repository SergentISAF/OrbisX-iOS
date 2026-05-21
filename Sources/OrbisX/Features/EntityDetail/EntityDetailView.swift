import SwiftUI

@MainActor
final class EntityDetailStore: ObservableObject {
    @Published var report: SponsorshipReport?
    @Published var isLoading: Bool = false
    @Published var errorText: String?

    func load(entity: TrackedEntity) async {
        isLoading = true
        errorText = nil
        do {
            var path = "/api/sponsorship/report?sponsored=\(encode(entity.name))&sample_size=200"
            if let sponsor = entity.sponsor_link, !sponsor.isEmpty {
                path += "&sponsor=\(encode(sponsor))"
            }
            report = try await APIClient.shared.request(path, as: SponsorshipReport.self)
        } catch {
            errorText = error.localizedDescription
        }
        isLoading = false
    }

    private func encode(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s
    }
}

struct EntityDetailView: View {
    let entity: TrackedEntity
    @StateObject private var store = EntityDetailStore()
    @State private var shareURL: URL?
    @State private var isCreatingShareLink: Bool = false
    @State private var shareError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let report = store.report {
                    aveBanner(report: report)
                    statRow(report: report)
                    topStories(report: report)
                    topOutlets(report: report)
                } else if store.isLoading {
                    ProgressView().controlSize(.large)
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let errorText = store.errorText {
                    VStack(spacing: 8) {
                        Text("Kunne ikke hente").font(.headline)
                        Text(errorText).font(.footnote).foregroundStyle(.secondary)
                    }
                    .padding()
                }
            }
            .padding(20)
        }
        .navigationTitle(entity.name)
        .navigationBarTitleDisplayMode(.large)
        .task { await store.load(entity: entity) }
        .refreshable { await store.load(entity: entity) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        Task { await createShareLink() }
                    } label: {
                        Label(isCreatingShareLink ? "Opretter link..." : "Del rapport-link", systemImage: "link")
                    }
                    .disabled(isCreatingShareLink)

                    ShareLink(item: shareText) {
                        Label("Del kort opsummering", systemImage: "text.quote")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(item: shareURLBinding) { sheet in
            ShareSheet(url: sheet.url, entityName: entity.name)
        }
        .alert("Kunne ikke oprette link", isPresented: shareErrorBinding) {
            Button("OK") { shareError = nil }
        } message: {
            Text(shareError ?? "")
        }
    }

    private var shareURLBinding: Binding<ShareURLWrapper?> {
        Binding(
            get: { shareURL.map(ShareURLWrapper.init) },
            set: { shareURL = $0?.url }
        )
    }

    private var shareErrorBinding: Binding<Bool> {
        Binding(
            get: { shareError != nil },
            set: { if !$0 { shareError = nil } }
        )
    }

    @MainActor
    private func createShareLink() async {
        isCreatingShareLink = true
        defer { isCreatingShareLink = false }
        do {
            let resp = try await APIClient.shared.request(
                "/api/entities/\(entity.id)/share",
                method: "POST",
                as: ShareLinkResponse.self
            )
            // Backend returnerer relativ URL "/shared?t=..." — vi prepender base
            let base = await APIClient.shared.baseURLString
            if let url = URL(string: base + resp.url) {
                shareURL = url
            }
        } catch {
            shareError = error.localizedDescription
        }
    }

    private var accent: Color {
        Color(hex: entity.color) ?? .accentColor
    }

    private var shareText: String {
        guard let r = store.report else { return entity.name }
        let nf = NumberFormatter()
        nf.locale = Locale(identifier: "da_DK")
        nf.numberStyle = .decimal
        let kr = nf.string(from: NSNumber(value: r.ave_extrapolated_dkk)) ?? "\(r.ave_extrapolated_dkk)"
        return "Mediedækning for \(r.sponsored):\nAnnonceværdi: \(kr) kr\n\(r.total_matches) omtaler i \(r.unique_outlets) medier"
    }

    @ViewBuilder
    private func aveBanner(report: SponsorshipReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SAMLET ANNONCEVÆRDI")
                .font(.caption2)
                .tracking(1.2)
                .foregroundStyle(accent)
            Text(formatKr(report.ave_extrapolated_dkk))
                .font(.system(size: 40, weight: .semibold, design: .serif))
            Text("Hvad medieomtalen ville have kostet som købte annoncer")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(accent.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(accent.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func statRow(report: SponsorshipReport) -> some View {
        HStack(spacing: 12) {
            statTile(value: "\(formatNumber(report.total_matches))", label: "Omtaler")
            statTile(value: "\(report.unique_outlets)", label: "Medier")
            statTile(value: "\(Int(report.avg_time_on_frontpage))t", label: "Forsidetid")
        }
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(.title2, design: .serif, weight: .semibold))
                .monospacedDigit()
            Text(label.uppercased())
                .font(.caption2)
                .tracking(0.8)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func topStories(report: SponsorshipReport) -> some View {
        if !report.top_stories.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Top historier")
                    .font(.system(.title3, design: .serif, weight: .semibold))
                ForEach(Array(report.top_stories.enumerated()), id: \.element.id) { idx, story in
                    storyRow(index: idx + 1, story: story)
                }
            }
        }
    }

    private func storyRow(index: Int, story: PublicArticle) -> some View {
        Link(destination: URL(string: story.article_url) ?? URL(string: "https://orbisx.ai")!) {
            HStack(alignment: .top, spacing: 14) {
                Text(String(format: "%02d", index))
                    .font(.system(.title2, design: .serif, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(accent)
                    .frame(width: 32, alignment: .leading)
                VStack(alignment: .leading, spacing: 6) {
                    if let availability = story.availability {
                        AvailabilityBadge(value: availability)
                    }
                    Text(story.article_title ?? "(uden titel)")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 6) {
                        Text(story.site_name)
                            .font(.caption2.weight(.semibold))
                        if let created = story.article_created {
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text(created)
                        }
                        if let t = story.time_on_frontpage {
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text("\(t)t").monospacedDigit()
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private func topOutlets(report: SponsorshipReport) -> some View {
        if !report.top_outlets.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Top medier")
                    .font(.system(.title3, design: .serif, weight: .semibold))

                let maxCount = report.top_outlets.first?.count ?? 1
                VStack(spacing: 8) {
                    ForEach(Array(report.top_outlets.prefix(10).enumerated()), id: \.element.id) { _, outlet in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(outlet.site_name)
                                    .font(.callout.weight(.medium))
                                GeometryReader { geo in
                                    Capsule()
                                        .fill(Color(.tertiarySystemBackground))
                                        .overlay(
                                            HStack {
                                                Capsule()
                                                    .fill(accent)
                                                    .frame(width: geo.size.width * CGFloat(outlet.count) / CGFloat(maxCount))
                                                Spacer(minLength: 0)
                                            }
                                        )
                                }
                                .frame(height: 6)
                            }
                            Text("\(outlet.count)")
                                .font(.callout.weight(.semibold).monospacedDigit())
                                .frame(width: 40, alignment: .trailing)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

private struct AvailabilityBadge: View {
    let value: String
    var body: some View {
        let isFree = value.lowercased() == "free"
        Text(isFree ? "Gratis" : "Betalingsvæg")
            .font(.system(size: 9, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(isFree ? Color.green : Color.blue)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background((isFree ? Color.green : Color.blue).opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Helpers

func formatKr(_ value: Int) -> String {
    let nf = NumberFormatter()
    nf.locale = Locale(identifier: "da_DK")
    nf.numberStyle = .decimal
    let number = nf.string(from: NSNumber(value: value)) ?? "\(value)"
    return "\(number) kr"
}

func formatNumber(_ value: Int) -> String {
    let nf = NumberFormatter()
    nf.locale = Locale(identifier: "da_DK")
    nf.numberStyle = .decimal
    return nf.string(from: NSNumber(value: value)) ?? "\(value)"
}
