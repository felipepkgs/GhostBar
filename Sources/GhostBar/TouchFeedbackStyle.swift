import Foundation

/// Preferences > Touch Feedback's style picker. Each case's actual
/// animation lives in Resources/overlay/style.css (the .fx-* classes) and
/// Resources/overlay/app.js (spawnTouchFx) — this enum only owns the
/// display name and the rawValue string pushed to JS via
/// OverlayPanelController's window.setTouchFeedback(...) call.
enum TouchFeedbackStyle: String, CaseIterable, Identifiable {
    case none, ripple, radialFill, sonar, pressBounce, flashBurst

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: "None"
        case .ripple: "Ripple"
        case .radialFill: "Radial Fill"
        case .sonar: "Sonar"
        case .pressBounce: "Press Bounce"
        case .flashBurst: "Flash Burst"
        }
    }
}
