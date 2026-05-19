import SwiftUI

extension Color {
    /// Init med hex-streng som "#5b6ef0" eller "5b6ef0".
    init?(hex: String?) {
        guard let hex else { return nil }
        var raw = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.hasPrefix("#") { raw.removeFirst() }
        guard raw.count == 6, let v = UInt32(raw, radix: 16) else { return nil }
        let r = Double((v >> 16) & 0xFF) / 255.0
        let g = Double((v >> 8) & 0xFF) / 255.0
        let b = Double(v & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
