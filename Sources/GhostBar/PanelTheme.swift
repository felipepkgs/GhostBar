import AppKit

/// The five visual directions pitched in the "GhostBar, Five Ways" design
/// exploration, built for real. Each case owns both its native chrome
/// (the NSVisualEffectView's corner radius/border, which the WebView content
/// can't reach — that shape is clipped by the native layer) and its display
/// name; the actual color/type treatment per theme lives in
/// Resources/overlay/style.css, scoped under `body[data-theme="..."]`.
///
/// ponytail: the design pitch used five different Google Fonts (one per
/// theme) for real typographic distinction. The shipped app stays on
/// -apple-system for all five instead — loading web fonts into the overlay
/// would mean a network fetch (or a bundled font file) on the critical path
/// of "appear instantly when you touch the Touch Bar," which this project
/// has otherwise kept dependency-free. Differentiation here comes from
/// weight/case/spacing instead of family.
enum PanelTheme: String, CaseIterable, Identifiable {
    case vapor, meniscus, ulm, instrument, unibody
    // Material finishes on Vapor's own glass shape (same silhouette/blur
    // language) rather than new silhouettes of their own — see style.css's
    // comment above the "Vapor materials" block for why they don't get
    // their own cornerRadius/border treatment either.
    case vaporGold, vaporSilver, vaporCarbon

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vapor: "Vapor"
        case .meniscus: "Meniscus"
        case .ulm: "Ulm"
        case .instrument: "Instrument"
        case .unibody: "Unibody"
        case .vaporGold: "Vapor — Gold"
        case .vaporSilver: "Vapor — Silver"
        case .vaporCarbon: "Vapor — Carbon Fiber"
        }
    }

    /// The native glass's outer corner radius — the WebView's own CSS can
    /// round its inner elements, but the panel's actual silhouette is
    /// clipped by this layer, not by anything the page draws.
    var cornerRadius: CGFloat {
        switch self {
        case .vapor, .vaporGold, .vaporSilver, .vaporCarbon: 22
        case .meniscus: 32
        case .ulm: 4
        case .instrument: 10
        case .unibody: 16
        }
    }

    var borderColor: NSColor {
        switch self {
        case .vapor: NSColor(white: 1, alpha: 0.12)
        case .meniscus: NSColor(white: 1, alpha: 0.16)
        case .ulm: NSColor(white: 0, alpha: 0.16)
        case .instrument: NSColor(white: 0, alpha: 0.10)
        case .unibody: NSColor(white: 1, alpha: 0.08)
        case .vaporGold: NSColor(calibratedRed: 0.96, green: 0.82, blue: 0.51, alpha: 0.22)
        case .vaporSilver: NSColor(white: 0.87, alpha: 0.20)
        case .vaporCarbon: NSColor(white: 0, alpha: 0.4)
        }
    }
}
