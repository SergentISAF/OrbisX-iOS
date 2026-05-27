import SwiftUI

struct CreateClusterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var auth: AuthStore

    let onCreated: (Cluster) -> Void

    @State private var title: String = ""
    @State private var searchText: String = ""
    @State private var type: ClusterKind = .keyword
    @State private var country: String = "dk"
    @State private var score: Double = 0.4
    @State private var backfill: Bool = true
    @State private var isWorking: Bool = false
    @State private var errorText: String?

    enum ClusterKind: String, CaseIterable, Identifiable {
        case keyword
        case contextual
        var id: String { rawValue }
        var label: String {
            switch self {
            case .keyword: return "Nøgleord"
            case .contextual: return "Semantisk"
            }
        }
        var help: String {
            switch self {
            case .keyword: return "Eksakt match — fx 'Carlsberg' eller 'klimaforandringer'"
            case .contextual: return "AI finder lignende artikler — beskriv emnet i en sætning"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Navn på agent", text: $title)
                        .textInputAutocapitalization(.words)
                } footer: {
                    Text("Vises som titel i listen")
                }

                Section {
                    Picker("Type", selection: $type) {
                        ForEach(ClusterKind.allCases) { kind in
                            Text(kind.label).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text(type.help)
                }

                Section("Søgning") {
                    TextField(
                        type == .keyword ? "fx Carlsberg" : "fx artikler om bæredygtig emballage",
                        text: $searchText,
                        axis: .vertical
                    )
                    .lineLimit(2...5)
                }

                Section("Land") {
                    Picker("Land", selection: $country) {
                        Text("🇩🇰 Danmark").tag("dk")
                        Text("🇬🇧 Storbritannien").tag("gb")
                        Text("🇳🇴 Norge").tag("no")
                        Text("🇸🇪 Sverige").tag("se")
                    }
                }

                if type == .contextual {
                    Section {
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Match-præcision")
                                Spacer()
                                Text(String(format: "%.2f", score))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $score, in: 0.2...0.8, step: 0.05)
                        }
                    } footer: {
                        Text("Højere = strengere match, færre artikler")
                    }
                }

                Section {
                    Toggle("Hent tidligere artikler", isOn: $backfill)
                } footer: {
                    Text("Backfill artikler fra de seneste 30 dage ved oprettelse")
                }

                if let errorText {
                    Section { Text(errorText).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Ny agent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annullér") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Opret") { submit() }
                        .disabled(!canSubmit || isWorking)
                }
            }
            .overlay {
                if isWorking {
                    ProgressView()
                        .controlSize(.large)
                        .padding(24)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func submit() {
        guard let email = auth.email else { return }
        isWorking = true
        errorText = nil
        Task {
            do {
                let body = CreateClusterRequest(
                    user_email: email,
                    title: title.trimmingCharacters(in: .whitespaces),
                    search_text: searchText.trimmingCharacters(in: .whitespaces),
                    cluster_type: type.rawValue,
                    country: country,
                    score: type == .contextual ? score : nil,
                    limit: nil,
                    site_names: nil,
                    backfill: backfill
                )
                let resp = try await APIClient.shared.request(
                    "/clusters",
                    method: "POST",
                    body: body,
                    as: CreateClusterResponse.self
                )
                let created = Cluster(
                    cluster_id: resp.cluster_id,
                    user_cluster_id: resp.user_cluster_id,
                    title: body.title,
                    search_text: body.search_text,
                    cluster_type: body.cluster_type,
                    country: body.country,
                    score: body.score,
                    limit: body.limit,
                    site_names: body.site_names,
                    article_count: nil,
                    unseen_count: nil,
                    last_article_at: nil,
                    created_at: nil
                )
                onCreated(created)
                dismiss()
            } catch {
                errorText = error.localizedDescription
                isWorking = false
            }
        }
    }
}
