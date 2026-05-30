import SwiftUI

/// Sammenligningsside (placeholder).
///
/// Skal genskabe orbisx.ai/dashboard sammenlignings-funktionen: vælg lister af companies,
/// sammenlign totalExpectedViews + totalQualityViews mellem to perioder.
/// Mikkels v2 API mangler endpoint for det — afventer afklaring om vi skal kalde
/// orbisx.ai/api/entitiesCompare/summary (NextJS-routes) eller en v2 equivalent.
struct CompareView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Sammenligning", systemImage: "chart.bar.xaxis")
            } description: {
                Text("Funktionen er på vej — sammenlign omtaler og kvalitetsvisninger på tværs af lister og perioder, som på orbisx.ai.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            } actions: {
                Link("Brug funktionen på orbisx.ai", destination: URL(string: "https://orbisx.ai/dk/da/dashboard")!)
                    .buttonStyle(.borderedProminent)
            }
            .navigationTitle("Sammenligning")
        }
    }
}
