import SwiftUI

struct PreferencesView: View {
    let overlay: OverlayPanelController
    let hotkeys: HotkeyManager

    @AppStorage(SettingsKey.idleHideDelay) private var idleHideDelay = 1.5
    @AppStorage(SettingsKey.actionHideDelay) private var actionHideDelay = 2.5
    @AppStorage(SettingsKey.panelScale) private var panelScale = 1.0
    @AppStorage(SettingsKey.panelOpacity) private var panelOpacity = 1.0
    @AppStorage(SettingsKey.panelTheme) private var panelThemeRaw = PanelTheme.vapor.rawValue

    // See OnboardingView's comment: @State's macro plugin isn't resolvable
    // in this CommandLineTools-only SPM build, so this binds straight to
    // SMAppService's live status instead of caching it locally.
    private var loginItemOn: Binding<Bool> {
        Binding(get: { LoginItem.isEnabled }, set: { LoginItem.setEnabled($0) })
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
