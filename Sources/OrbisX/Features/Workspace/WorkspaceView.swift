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
    @State private var showingSettings: Bool = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(auth.relationshipType.workspaceTitle)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingAdd = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "person.crop.circle")
                        }
                    }
                }
                .task { await store.load() }
                .refreshable { await store.load() }
                .sheet(isPresented: $showingAdd) {
                    AddEntitySheet(
                        relationshipType: auth.relationshipType,
                        ownBrandName: auth.ownBrandName ?? auth.tenantName ?? ""
                    ) { entity in
                        Task {
                            await store.load()
                            await store.sync(entity)
                        }
                    }
                }
                .sheet(isPresented: $showingSettings) {
                    SettingsSheet()
                        .environmentObject(auth)
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
        HStack(alignment: .center, spacing: 14) {
            Circle()
                .fill(Color(hex: entity.color) ?? .accentColor)
                .frame(width: 14, height: 14)

            VStack(alignment: .leading, spacing: 4) {
                Text(entity.name)
                    .font(.headline)
                HStack(spacing: 6) {
                    Text(entity.entity_type.capitalized)
                    Text("·")
                    Text("\(entity.last_match_count) omtaler")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if entity.last_ave_dkk > 0 {
                    Text(formatCompactKr(entity.last_ave_dkk))
                        .font(.system(.title3, design: .serif, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color(hex: entity.color) ?? .primary)
                    Text("annonceværdi")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("—")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("sync for tal")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if isBusy {
                ProgressView().controlSize(.small)
            }
        }
        .padding(.vertical, 4)
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

/// Kort kr-format: 1.234.567 -> "1,2 mio kr", 12.345 -> "12.345 kr".
private func formatCompactKr(_ value: Int) -> String {
    let nf = NumberFormatter()
    nf.locale = Locale(identifier: "da_DK")
    nf.numberStyle = .decimal
    if value >= 1_000_000_000 {
        nf.maximumFractionDigits = 1
        let v = Double(value) / 1_000_000_000.0
        return "\(nf.string(from: NSNumber(value: v)) ?? "\(v)") mia kr"
    }
    if value >= 1_000_000 {
        nf.maximumFractionDigits = 1
        let v = Double(value) / 1_000_000.0
        return "\(nf.string(from: NSNumber(value: v)) ?? "\(v)") mio kr"
    }
    return "\(nf.string(from: NSNumber(value: value)) ?? "\(value)") kr"
}

private struct AddEntitySheet: View {
    @Environment(\.dismiss) private var dismiss
    let relationshipType: RelationshipType
    let ownBrandName: String
    let onCreated: (TrackedEntity) -> Void

    @State private var name: String = ""
    @State private var color: String = "#5b6ef0"
    @State private var isWorking: Bool = false
    @State private var errorText: String?

    private var sponsorLink: String? {
        // Hvis jeg ER sponsor: hver entity jeg tilføjer er en SPONSORERET ting,
        // og min egen virksomhed er auto sponsor.
        // Hvis jeg ER sponseret: hver entity jeg tilføjer er en sponsor, og min
        // egen virksomhed er auto den sponserede part.
        return ownBrandName.isEmpty ? nil : ownBrandName
    }

    private var entityType: String {
        switch relationshipType {
        case .sponsor: return "sponseret"   // jeg sponsorerer ⇒ entity = sponseret
        case .sponseret: return "sponsor"   // jeg er sponsoreret ⇒ entity = sponsor
        case .mixed: return "brand"
        }
    }

    private var title: String { relationshipType.addLabel }
    private var fieldLabel: String {
        switch relationshipType {
        case .sponsor: return "Hvem sponsorerer du?"
        case .sponseret: return "Hvilken sponsor?"
        case .mixed: return "Brand"
        }
    }
    private var placeholder: String {
        switch relationshipType {
        case .sponsor: return "fx Aalborg Håndbold"
        case .sponseret: return "fx Carlsberg"
        case .mixed: return "fx Aalborg Håndbold"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(fieldLabel) {
                    TextField(placeholder, text: $name)
                        .textInputAutocapitalization(.words)
                }
                Section("Farve") {
                    ColorPickerHex(hex: $color)
                }
                if !ownBrandName.isEmpty {
                    Section {
                        HStack {
                            Text(relationshipType == .sponsor ? "Sponsoreret af" : "Sponsoreret part")
                            Spacer()
                            Text(ownBrandName).foregroundStyle(.secondary)
                        }
                    } footer: {
                        Text("Auto-tagged fra dine indstillinger")
                    }
                }
                if let errorText {
                    Section { Text(errorText).foregroundStyle(.red) }
                }
            }
            .navigationTitle(title)
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
                    sponsor_link: sponsorLink
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

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var auth: AuthStore

    @State private var selectedRole: RelationshipType = .sponsor
    @State private var ownBrand: String = ""
    @State private var tenantName: String = ""
    @State private var isWorking: Bool = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Jeg er") {
                    Picker("Rolle", selection: $selectedRole) {
                        Text("Sponsor (jeg sponsorerer)").tag(RelationshipType.sponsor)
                        Text("Sponsoreret (jeg modtager sponsorater)").tag(RelationshipType.sponseret)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section(selectedRole == .sponsor ? "Min virksomhed" : "Mit hold/firma") {
                    TextField(
                        selectedRole == .sponsor ? "fx Carlsberg" : "fx Aalborg Håndbold",
                        text: $ownBrand
                    )
                    .textInputAutocapitalization(.words)
                }

                Section("Workspace-navn") {
                    TextField("Workspace", text: $tenantName)
                        .textInputAutocapitalization(.words)
                }

                Section {
                    Button("Log ud", role: .destructive) {
                        Task {
                            await auth.logout()
                            dismiss()
                        }
                    }
                }

                if let errorText {
                    Section { Text(errorText).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Indstillinger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annullér") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gem") { save() }.disabled(isWorking)
                }
            }
            .onAppear {
                selectedRole = auth.relationshipType
                ownBrand = auth.ownBrandName ?? ""
                tenantName = auth.tenantName ?? ""
            }
        }
    }

    private func save() {
        isWorking = true
        errorText = nil
        Task {
            do {
                try await auth.updateTenant(
                    relationshipType: selectedRole,
                    ownBrandName: ownBrand,
                    name: tenantName
                )
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
