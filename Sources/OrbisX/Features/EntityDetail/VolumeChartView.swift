import SwiftUI

@MainActor
final class VolumeStore: ObservableObject {
    @Published var data: VolumeResponse?
    @Published var isLoading: Bool = false
    @Published var errorText: String?

    func load(entityId: Int, days: Int = 30) async {
        isLoading = true
        errorText = nil
        do {
            data = try await APIClient.shared.request(
                "/api/entities/\(entityId)/volume?days=\(days)",
                as: VolumeResponse.self
            )
        } catch {
            errorText = error.localizedDescription
        }
        isLoading = false
    }
}

struct VolumeChartView: View {
    let entityId: Int
    let accent: Color
    var days: Int = 30

    @StateObject private var store = VolumeStore()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("OMTALER OVER TID")
                    .font(.caption2)
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                Spacer()
                if let d = store.data {
                    Text("\(formatNumber(d.total_articles)) på \(days)d")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            Group {
                if let d = store.data, !d.daily.isEmpty {
                    bars(daily: d.daily)
                } else if store.isLoading {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("Henter volume...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(height: 60)
                } else if store.errorText != nil {
                    Text("Kunne ikke hente volume")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(height: 60)
                } else {
                    Text("Ingen data sidste \(days) dage")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(height: 60)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task { await store.load(entityId: entityId, days: days) }
    }

    private func bars(daily: [VolumePoint]) -> some View {
        let maxCount = max(daily.map(\.articles).max() ?? 1, 1)
        return GeometryReader { geo in
            let count = max(daily.count, 1)
            let barW = geo.size.width / CGFloat(count)
            ZStack(alignment: .bottomLeading) {
                ForEach(Array(daily.enumerated()), id: \.element.id) { idx, point in
                    let h = CGFloat(point.articles) / CGFloat(maxCount) * geo.size.height
                    Rectangle()
                        .fill(accent.opacity(0.85))
                        .frame(width: max(barW - 1, 1), height: h)
                        .offset(x: CGFloat(idx) * barW)
                }
            }
        }
        .frame(height: 60)
    }
}
