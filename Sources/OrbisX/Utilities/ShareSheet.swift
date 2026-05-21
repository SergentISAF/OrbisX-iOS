import SwiftUI
import UIKit

/// Wrapper så `URL` kan bruges som `Identifiable` til `.sheet(item:)`-binding.
struct ShareURLWrapper: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

/// UIKit-wrapped UIActivityViewController. SwiftUI's ShareLink fungerer fint i
/// de fleste tilfælde, men her vil vi præsentere efter en async-operation, så vi
/// bruger den klassiske UIActivityViewController.
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    let entityName: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let items: [Any] = [
            "Mediedækningsrapport for \(entityName)",
            url,
        ]
        return UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
