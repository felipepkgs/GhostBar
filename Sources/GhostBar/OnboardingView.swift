import SwiftUI

struct OnboardingView: View {
    let onDone: () -> Void

    // Bound straight to SMAppService's live status via a manual Binding
    // rather than cached in @State — this toolchain (CommandLineTools only,
    // no Xcode.app) can't resolve the @State macro plugin for SPM builds.
    private var loginItemOn: Binding<Bool> {
        Binding(get: { LoginItem.isEnabled }, set: { LoginItem.setEnabled($0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Welcome to GhostBar").font(.title2.bold())

            Text("GhostBar shows where you're touching on a Touch Bar whose display has failed, and flashes up brightness, volume, and media actions as you press them. No permissions to grant — it works out of the box.")
                .fixedSize(horizontal: false, vertical: true)

            Text("It lives in the menu bar — no Dock icon. Press ⌃⌥⌘T anytime to pin the panel open.")
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.secondary)

            Toggle("Launch at Login", isOn: loginItemOn)

            HStack {
                Spacer()
                Button("Get Started", action: onDone)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 380)
    }
}
