#!/usr/bin/env swift
// Draws the GhostBar app icon (the same Icons8 "Glyph Neue" ghost glyph as
// the menu bar icon, on the overlay's dark glass gradient) and exports every
// size iconutil needs for an .icns. Run via Scripts/generate_icon.sh, not
// directly — that script also invokes iconutil afterwards.
//
// Previously a pill+glow-dot motif unrelated to the menu bar icon — Finder/
// Dock/Raycast/Spotlight all showed a different "app identity" than the
// status bar glyph. Source ghost at assets/ghost-source.png (Icons8
// glyph-neue, 800px, white) — see README's Credits section.

import AppKit

let masterSize: CGFloat = 1024
let outDir = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let scriptDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
guard let ghost = NSImage(contentsOf: scriptDir.appendingPathComponent("assets/ghost-source.png")) else {
    fatalError("assets/ghost-source.png missing")
}

func makeMaster() -> NSImage {
    let size = NSSize(width: masterSize, height: masterSize)
    let image = NSImage(size: size)
    image.lockFocus()

    // Full-bleed background — macOS applies its own squircle mask + drop
    // shadow to icns art, so this deliberately fills edge to edge unrounded.
    let bgRect = NSRect(origin: .zero, size: size)
    let gradient = NSGradient(colors: [
        NSColor(calibratedWhite: 0.13, alpha: 1),
        NSColor(calibratedWhite: 0.035, alpha: 1),
    ])
    gradient?.draw(in: bgRect, angle: -60)

    // The ghost itself, generously padded so it doesn't compete with
    // macOS's own squircle mask right at the edge.
    let inset = masterSize * 0.24
    let ghostRect = NSRect(x: inset, y: inset, width: masterSize - inset * 2, height: masterSize - inset * 2)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(calibratedWhite: 1, alpha: 0.25)
    shadow.shadowBlurRadius = masterSize * 0.04
    shadow.shadowOffset = .zero
    shadow.set()
    ghost.draw(in: ghostRect, from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, side: CGFloat, to url: URL) {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(side), pixelsHigh: Int(side),
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: side, height: side)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: side, height: side), from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else { return }
    try? data.write(to: url)
}

let master = makeMaster()
let sizes: [(name: String, points: CGFloat, scale: Int)] = [
    ("icon_16x16", 16, 1), ("icon_16x16@2x", 16, 2),
    ("icon_32x32", 32, 1), ("icon_32x32@2x", 32, 2),
    ("icon_128x128", 128, 1), ("icon_128x128@2x", 128, 2),
    ("icon_256x256", 256, 1), ("icon_256x256@2x", 256, 2),
    ("icon_512x512", 512, 1), ("icon_512x512@2x", 512, 2),
]

for entry in sizes {
    let side = entry.points * CGFloat(entry.scale)
    writePNG(master, side: side, to: outDir.appendingPathComponent("\(entry.name).png"))
}

print("Wrote \(sizes.count) icon sizes to \(outDir.path)")
