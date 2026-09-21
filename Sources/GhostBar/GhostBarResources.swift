import Foundation

/// Replaces SPM's generated `Bundle.module`. That accessor hardcodes ONE
/// candidate layout for the package's resource bundle, and calls
/// `fatalError()` (uncatchable — crashes the whole process) if it isn't
/// found there.
///
/// That one layout has been observed to differ between toolchains for the
/// exact same source: a local CommandLineTools-only `swift build -c
/// release` nests resources under `GhostBar_GhostBar.bundle/Contents/
/// Resources/`; the GitHub Actions macos-14 runner's toolchain produced a
/// flat `GhostBar_GhostBar.bundle/` with no `Contents/Resources` wrapper —
/// confirmed by building the identical commit on both and diffing the
/// output. `Bundle.module` only ever checked the nested form, so every
/// CI-built release crashed instantly on launch (`OverlayPanelController
/// .init()` -> `loadOverlay()` -> `Bundle.module`'s fatalError) while local
/// dev builds looked fine — this is what actually shipped as v0.2.7 and
/// crashed for every Homebrew user who upgraded.
///
/// This checks both known layouts (plus the bare-binary `swift run` case,
/// where resources sit next to the executable with no app bundle at all)
/// instead of assuming one.
enum GhostBarResources {
    static func url(forResource name: String, withExtension ext: String, subdirectory: String) -> URL? {
        let bundleName = "GhostBar_GhostBar.bundle"
        let bases = [Bundle.main.resourceURL, Bundle.main.bundleURL].compactMap { $0 }
        let layouts = [bundleName, "\(bundleName)/Contents/Resources"]

        for base in bases {
            for layout in layouts {
                let candidate = base
                    .appendingPathComponent(layout)
                    .appendingPathComponent(subdirectory)
                    .appendingPathComponent(name)
                    .appendingPathExtension(ext)
                if FileManager.default.fileExists(atPath: candidate.path) {
                    return candidate
                }
            }
        }
        return nil
    }
}
