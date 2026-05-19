import SwiftUI

@MainActor
final class WorkspaceStore: ObservableObject {
    @Published var entities: [TrackedEntity] = []
    @Published var isLoading: Bool = false
    @Published var errorText: String?
    @Published var busyEntityId: Int?

    func load() async {
        isLoading = true
        errorText = nil
        do {
            entities = try await APIClient.shared.request(
                "/api/entities",
                as: [TrackedEntity].self
            )
        } catch {
            errorText = error.localizedDescription
        }
        isLoading = false
    }

    func sync(_ entity: TrackedEntity) async {
        busyEntityId = entity.id
        do {
            _ = try await APIClient.shared.request(
                "/api/entities/\(entity.id)/sync",
                method: "POST",
                as: SyncResult.self
            )
            await load()
        } catch {
            errorText = error.localizedDescription
        }
        busyEntityId = nil
    }
}

struct WorkspaceView: View {
    @EnvironmentObject var auth: AuthStore
    @StateObject private var store = WorkspaceStore()
    @State private var showingAdd: Bool = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(auth.tenantName ?? "Workspace")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingAdd = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            Button("Log ud", role: .destructive) {
                                Task { await auth.logout() }
                            }
                        } label: {
                            Image(systemName: "person.crop.circle")
                        }
                    }
                }
                .task { await store.load() }
                .refreshable { await store.load() }
                .sheet(isPresented: $showingAdd) {
                    AddEntitySheet { entity in
                        Task {
                            await store.load()
                            await store.sync(entity)
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.isLoading && store.entities.isEmpty {
            ProgressView().controlSize(.large)
        } else if let errorText = store.errorText, store.entities.isEmpty {
            VStack(spacing: 12) {
                Text("Kunne ikke hente")
                    .font(.headline)
                Text(errorText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Prøv igen") {
                    Task { await store.load() }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        } else if store.entities.isEmpty {
            ContentUnavailableView(
                "Ingen brands endnu",
                systemImage: "rectangle.stack.badge.plus",
                description: Text("Tryk på + for at tilføje dit første brand")
            )
        } else {
            List(store.entities) { entity in
                NavigationLink {
                    EntityDetailView(entity: entity)
                } label: {
                    EntityRow(
                        entity: entity,
                        isBusy: store.busyEntityId == entity.id,
                        onSync: {
                            Task { await store.sync(entity) }
                        }
                    )
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}

private struct EntityRow: View {
    let entity: TrackedEntity
    let isBusy: Bool
    let onSync: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: entity.color) ?? .accentColor)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 4) {
                Text(entity.name)
                    .font(.headline)
                Text(entity.entity_type.capitalized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entity.last_match_count)")
                    .font(.system(.title3, design: .serif, weight: .semibold))
                    .monospacedDigit()
                Text("omtaler")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if isBusy {
                ProgressView().controlSize(.small)
            }
        }
        .swipeActions(edge: .trailing) {
            Button {
                onSync()
            } label: {
                Label("Sync", systemImage: "arrow.clockwise")
            }
            .tint(.blue)
        }
    }
}

private struct AddEntitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var entityType: String = "brand"
    @State private var sponsorLink: String = ""
    @State private var color: String = "#5b6ef0"
    @State private var isWorking: Bool = false
    @State private var errorText: String?

    let onCreated: (TrackedEntity) -> Void
    private let types = ["brand", "sponsor", "sponseret", "konkurrent"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Brand") {
                    TextField("fx Aalborg Håndbold", text: $name)
                        .textInputAutocapitalization(.words)
                    Picker("Type", selection: $entityType) {
                        ForEach(types, id: \.self) { Text($0.capitalized).tag($0) }
                    }
                }
                Section("Tilknyttet sponsor (valgfri)") {
                    TextField("fx Carlsberg", text: $sponsorLink)
                        .textInputAutocapitalization(.words)
                }
                Section("Farve") {
                    ColorPickerHex(hex: $color)
                }
                if let errorText {
                    Section { Text(errorText).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Nyt brand")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annullér") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Tilføj") { submit() }
                        .disabled(name.isEmpty || isWorking)
                }
            }
        }
    }

    private func submit() {
        isWorking = true
        errorText = nil
        Task {
            do {
                let payload = EntityCreate(
                    name: name,
                    entity_type: entityType,
                    search_text: nil,
                    color: color,
                    sponsor_link: sponsorLink.isEmpty ? nil : sponsorLink
                )
                let created = try await APIClient.shared.request(
                    "/api/entities",
                    method: "POST",
                    body: payload,
                    as: TrackedEntity.self
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

private struct ColorPickerHex: View {
    @Binding var hex: String
    private let presets = ["#5b6ef0", "#c8102e", "#005f3c", "#fbb800", "#f47b20", "#16a34a"]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(presets, id: \.self) { p in
                Circle()
                    .fill(Color(hex: p) ?? .gray)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle()
                            .stroke(hex == p ? Color.primary : .clear, lineWidth: 2)
                    )
                    .onTapGesture { hex = p }
            }
        }
        .padding(.vertical, 4)
    }
}
