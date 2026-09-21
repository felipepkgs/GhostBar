import AppKit
import SwiftUI

struct PreferencesView: View {
    let overlay: OverlayPanelController
    let hotkeys: HotkeyManager

    @AppStorage(SettingsKey.idleHideDelay) private var idleHideDelay = 1.5
    @AppStorage(SettingsKey.actionHideDelay) private var actionHideDelay = 2.5
    @AppStorage(SettingsKey.panelScale) private var panelScale = 1.0
    @AppStorage(SettingsKey.panelOpacity) private var panelOpacity = 1.0
    @AppStorage(SettingsKey.panelTheme) private var panelThemeRaw = PanelTheme.vapor.rawValue
    @AppStorage(SettingsKey.playTouchSound) private var playTouchSound = false
    @AppStorage(SettingsKey.touchFeedbackStyle) private var touchFeedbackStyleRaw = TouchFeedbackStyle.none.rawValue
    @AppStorage(SettingsKey.flashTouchedSegment) private var flashTouchedSegment = false
    @AppStorage(SettingsKey.touchFeedbackColorHex) private var touchFeedbackColorHex = "#FFFFFF"

    // See OnboardingView's comment: @State's macro plugin isn't resolvable
    // in this CommandLineTools-only SPM build, so this binds straight to
    // SMAppService's live status instead of caching it locally.
    private var loginItemOn: Binding<Bool> {
        Binding(get: { LoginItem.isEnabled }, set: { LoginItem.setEnabled($0) })
    }

    // ColorPicker needs a Color binding, but @AppStorage only stores
    // primitives — stored as a hex string instead (also what's pushed to
    // the overlay's CSS custom property, see OverlayPanelController), with
    // this as the SwiftUI-facing view onto it.
    private var touchFeedbackColor: Binding<Color> {
        Binding(
            get: { Color(hex: touchFeedbackColorHex) },
            set: { touchFeedbackColorHex = $0.hexString }
        )
    }

    var body: some View {
        Form {
            Section("Behavior") {
                LabeledSlider(label: "Hide after touch", value: $idleHideDelay, range: 0.5...4) {
                    String(format: "%.1fs", $0)
                }
                LabeledSlider(label: "Hide after action", value: $actionHideDelay, range: 0.5...5) {
                    String(format: "%.1fs", $0)
                }
                Toggle("Play sound on touch", isOn: $playTouchSound)
            }

            Section("Touch Feedback") {
                Picker("Style", selection: $touchFeedbackStyleRaw) {
                    ForEach(TouchFeedbackStyle.allCases) { style in
                        Text(style.displayName).tag(style.rawValue)
                    }
                }
                Toggle("Flash touched segment", isOn: $flashTouchedSegment)
                ColorPicker("Color", selection: touchFeedbackColor, supportsOpacity: false)
            }

            Section("Appearance") {
                Picker("Theme", selection: $panelThemeRaw) {
                    ForEach(PanelTheme.allCases) { theme in
                        Text(theme.displayName).tag(theme.rawValue)
                    }
                }
                LabeledSlider(label: "Panel size", value: $panelScale, range: 0.75...1.5) {
                    String(format: "%.0f%%", $0 * 100)
                }
                LabeledSlider(label: "Panel opacity", value: $panelOpacity, range: 0.4...1.0) {
                    String(format: "%.0f%%", $0 * 100)
                }
                Button("Preview") { overlay.preview() }
            }

            Section("Position") {
                Button("Reset Position") { overlay.resetPosition() }
            }

            Section("Global Hotkey") {
                HStack {
                    Text("Toggle Overlay")
                    Spacer()
                    HotkeyRecorderButton(hotkeys: hotkeys)
                }
            }

            Section {
                Toggle("Launch at Login", isOn: loginItemOn)
            }
        }
        .padding(20)
        .frame(width: 340)
    }
}

// @AppStorage only stores primitives, and the color needs to travel to the
// overlay's CSS as a hex string anyway (see OverlayPanelController), so
// hex is the one representation used everywhere instead of converting
// back and forth between it and some other format.
private extension Color {
    init(hex: String) {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized.removeAll { $0 == "#" }
        var rgb: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&rgb)
        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255,
            green: Double((rgb & 0x00FF00) >> 8) / 255,
            blue: Double(rgb & 0x0000FF) / 255
        )
    }

    var hexString: String {
        let color = NSColor(self).usingColorSpace(.deviceRGB) ?? NSColor(self)
        return String(
            format: "#%02X%02X%02X",
            Int(round(color.redComponent * 255)),
            Int(round(color.greenComponent * 255)),
            Int(round(color.blueComponent * 255))
        )
    }
}

private struct LabeledSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                Spacer()
                Text(format(value))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: $value, in: range)
        }
    }
}
