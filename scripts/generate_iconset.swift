import AppKit
import Foundation

if CommandLine.arguments.count < 2 {
    fputs("Usage: generate_iconset.swift <iconset-output-dir>\n", stderr)
    exit(1)
}

let outputDir = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let fm = FileManager.default
try? fm.removeItem(at: outputDir)
try fm.createDirectory(at: outputDir, withIntermediateDirectories: true)

let iconSpecs: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

for (size, name) in iconSpecs {
    let canvas = NSImage(size: NSSize(width: size, height: size))
    canvas.lockFocus()
    NSColor.clear.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()

    let symbolPointSize = CGFloat(size) * 0.82
    let config = NSImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .bold)
    guard let symbol = NSImage(systemSymbolName: "leaf.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(config)
    else {
        fputs("Failed to load SF Symbol leaf.fill\n", stderr)
        exit(2)
    }

    let iconColor = NSColor(calibratedRed: 0.20, green: 0.64, blue: 0.43, alpha: 1.0)
    let tinted = symbol.copy() as! NSImage
    tinted.isTemplate = false

    let symbolRect = NSRect(
        x: (CGFloat(size) - symbolPointSize) / 2,
        y: (CGFloat(size) - symbolPointSize) / 2,
        width: symbolPointSize,
        height: symbolPointSize
    )

    iconColor.set()
    symbolRect.fill(using: .sourceOver)
    tinted.draw(in: symbolRect, from: .zero, operation: .destinationIn, fraction: 1.0)

    canvas.unlockFocus()

    guard
        let tiff = canvas.tiffRepresentation,
        let rep = NSBitmapImageRep(data: tiff),
        let png = rep.representation(using: .png, properties: [:])
    else {
        fputs("Failed to encode \(name)\n", stderr)
        exit(3)
    }

    try png.write(to: outputDir.appendingPathComponent(name))
}
