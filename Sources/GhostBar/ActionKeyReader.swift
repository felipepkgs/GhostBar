import AppKit

/// Catches system-defined "media key" events (brightness, volume, mute,
/// playback, keyboard illumination). Physical F-keys and their Touch Bar
/// equivalents both synthesize these same events — this is public API
/// (NSEvent + the standard NX_KEYTYPE_* constants from IOKit/hidsystem),
/// unlike the rest of this app. It only covers the standard Fn-row/media
/// actions, not custom per-app Touch Bar buttons (those never leave the
/// owning app's process, so no system-wide event exists for them).
final class ActionKeyReader {
    var onAction: ((_ label: String) -> Void)?

    private var monitor: Any?

    // NX_KEYTYPE_* values from IOKit/hidsystem/ev_keymap.h
    private let labels: [Int16: String] = [
        0: "Volume Up",
        1: "Volume Down",
        2: "Brightness Up",
        3: "Brightness Down",
        7: "Mute",
        14: "Eject",
        16: "Play / Pause",
        17: "Next",
        18: "Previous",
        19: "Fast Forward",
        20: "Rewind",
        21: "Keyboard Brightness Up",
        22: "Keyboard Brightness Down",
        23: "Keyboard Brightness Toggle",
    ]

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) { [weak self] event in
            self?.handle(event)
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    private func handle(_ event: NSEvent) {
        guard event.subtype.rawValue == 8 else { return } // AUX_CONTROL_BUTTONS
        let data1 = event.data1
        let keyCode = Int16((data1 & 0xFFFF0000) >> 16)
        let keyState = (data1 & 0x0000FF00) >> 8
        guard keyState == 0xA else { return } // 0xA = key down, 0xB = key up
        guard let label = labels[keyCode] else { return }
        onAction?(label)
    }
}
