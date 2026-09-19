#!/usr/bin/env swift
// Draws the GhostBar app icon (a dark card with the same pill+glow-dot motif
// as the overlay itself) and exports every size iconutil needs for an .icns.
// Run via Scripts/generate_icon.sh, not directly — that script also invokes
// iconutil afterwards.

import AppKit

let masterSize: CGFloat = 1024
let outDir = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

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

    // The Control Strip pill, echoing the overlay's own visual language.
    let pillRect = NSRect(x: masterSize * 0.16, y: masterSize * 0.44, width: masterSize * 0.68, height: masterSize * 0.145)
    let pill = NSBezierPath(roundedRect: pillRect, xRadius: pillRect.height / 2, yRadius: pillRect.height / 2)
    NSColor(calibratedWhite: 1, alpha: 0.12).setFill()
    pill.fill()
    NSColor(calibratedWhite: 1, alpha: 0.22).setStroke()
    pill.lineWidth = masterSize * 0.004
    pill.stroke()

    // Faint segment dividers inside the pill.
    NSColor(calibratedWhite: 1, alpha: 0.08).setStroke()
    for i in 1..<4 {
        let x = pillRect.minX + pillRect.width * CGFloat(i) / 4
        let line = NSBezierPath()
        line.move(to: NSPoint(x: x, y: pillRect.minY + pillRect.height * 0.18))
        line.line(to: NSPoint(x: x, y: pillRect.maxY - pillRect.height * 0.18))
        line.lineWidth = masterSize * 0.0025
        line.stroke()
    }

    // Glowing touch dot, off-center like a finger mid-press.
    let dotRadius = masterSize * 0.058
    let dotCenter = NSPoint(x: pillRect.minX + pillRect.width * 0.64, y: pillRect.midY)
    let dotColor = NSColor(calibratedRed: 0.19, green: 0.82, blue: 0.345, alpha: 1)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = dotColor.withAlphaComponent(0.95)
    shadow.shadowBlurRadius = masterSize * 0.075
    shadow.shadowOffset = .zero
    shadow.set()

    let dotPath = NSBezierPath(ovalIn: NSRect(
        x: dotCenter.x - dotRadius, y: dotCenter.y - dotRadius,
        width: dotRadius * 2, height: dotRadius * 2
    ))
    dotColor.setFill()
    dotPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Glossy highlight on the dot for a bit of dimensionality.
    let highlight = NSBezierPath(ovalIn: NSRect(
        x: dotCenter.x - dotRadius * 0.45, y: dotCenter.y + dotRadius * 0.1,
        width: dotRadius * 0.9, height: dotRadius * 0.7
    ))
    NSColor(calibratedWhite: 1, alpha: 0.35).setFill()
    highlight.fill()

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
