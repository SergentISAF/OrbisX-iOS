import SwiftUI

@MainActor
final class TrendingStore: ObservableObject {
    @Published var data: TrendingResponse?
    @Published var isLoading: Bool = false
    @Published var errorText: String?

    func load(days: Int = 2, limit: Int = 15) async {
        isLoading = true
        errorText = nil
        do {
            data = try await APIClient.shared.request(
                "/api/trending?days=\(days)&limit=\(limit)",
                as: TrendingResponse.self
            )
        } catch {
            errorText = error.localizedDescription
        }
        isLoading = false
    }
}

struct TrendingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = TrendingStore()
    @State private var days: Int = 2

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Trender lige nu")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Luk") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Sidste døgn") { Task { await reload(days: 1) } }
                            Button("Sidste 2 dage") { Task { await reload(days: 2) } }
                            Button("Sidste uge") { Task { await reload(days: 7) } }
                        } label: {
                            Image(systemName: "clock")
                        }
                    }
                }
                .task { await store.load(days: days) }
                .refreshable { await store.load(days: days) }
        }
    }

    private func reload(days: Int) async {
        self.days = days
        await store.load(days: days)
    }

    @ViewBuilder
    private var content: some View {
        if let d = store.data, !d.stories.isEmpty {
            List {
                Section {
                    ForEach(Array(d.stories.enumerated()), id: \.element.id) { idx, story in
                        TrendingRow(index: idx + 1, story: story)
                    }
                } footer: {
                    Text(periodLabel(days: d.timerange_days))
                }
            }
            .listStyle(.insetGrouped)
        } else if store.isLoading {
            ProgressView().controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorText = store.errorText {
            VStack(spacing: 8) {
                Text("Kunne ikke hente").font(.headline)
                Text(errorText).font(.footnote).foregroundStyle(.secondary)
            }
            .padding()
        } else {
            ContentUnavailableView("Ingen trending stories", systemImage: "chart.line.uptrend.xyaxis")
        }
    }

    private func periodLabel(days: Int) -> String {
        switch days {
        case 1: return "Sidste døgn"
        case 7: return "Sidste uge"
        default: return "Sidste \(days) dage"
        }
    }
}

private struct TrendingRow: View {
    let index: Int
    let story: TrendingStory

    var body: some View {
        Link(destination: URL(string: story.url ?? "") ?? URL(string: "https://orbisx.ai")!) {
            HStack(alignment: .top, spacing: 14) {
                Text(String(format: "%02d", index))
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.tint)
                    .frame(width: 32, alignment: .leading)
                VStack(alignment: .leading, spacing: 6) {
                    Text(story.title ?? "(uden titel)")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                    HStack(spacing: 8) {
                        if let n = story.article_count {
                            Label(compactNumber(n), systemImage: "newspaper")
                        }
                        if let n = story.site_count {
                            Label(compactNumber(n), systemImage: "globe")
                        }
                        if let n = story.expected_views {
                            Label(compactNumber(n), systemImage: "eye")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func compactNumber(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fk", Double(n) / 1_000) }
        return "\(n)"
    }
}
