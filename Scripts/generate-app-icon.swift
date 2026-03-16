import AppKit
import Foundation

let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
let iconDirectory = repoRoot.appendingPathComponent("Sources/HikvisionViewer/Assets.xcassets/AppIcon.appiconset", isDirectory: true)

let iconFiles: [(filename: String, size: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

func makeImage(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    let rect = CGRect(origin: .zero, size: CGSize(width: size, height: size))
    let radius = CGFloat(size) * 0.22
    let shellColor = NSColor(calibratedRed: 0.07, green: 0.17, blue: 0.23, alpha: 1.0)
    let accentStart = NSColor(calibratedRed: 0.13, green: 0.68, blue: 0.73, alpha: 1.0)
    let accentEnd = NSColor(calibratedRed: 0.52, green: 0.89, blue: 0.84, alpha: 1.0)

    shellColor.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()

    let gradientRect = rect.insetBy(dx: CGFloat(size) * 0.04, dy: CGFloat(size) * 0.04)
    let gradientPath = NSBezierPath(roundedRect: gradientRect, xRadius: radius * 0.9, yRadius: radius * 0.9)
    NSGradient(colors: [accentStart, accentEnd])?.draw(in: gradientPath, angle: -45)

    let panelRect = rect.insetBy(dx: CGFloat(size) * 0.12, dy: CGFloat(size) * 0.17)
    let panelPath = NSBezierPath(roundedRect: panelRect, xRadius: radius * 0.55, yRadius: radius * 0.55)
    NSColor(calibratedWhite: 0.98, alpha: 0.95).setFill()
    panelPath.fill()

    let tileGap = CGFloat(size) * 0.045
    let tileWidth = (panelRect.width - tileGap * 4) / 3
    let tileHeight = (panelRect.height - tileGap * 4) / 3
    let tileColor = NSColor(calibratedRed: 0.08, green: 0.21, blue: 0.26, alpha: 0.94)
    let tileHighlight = NSColor(calibratedRed: 0.46, green: 0.91, blue: 0.88, alpha: 0.88)

    for row in 0..<3 {
        for column in 0..<3 {
            let tileRect = CGRect(
                x: panelRect.minX + tileGap + CGFloat(column) * (tileWidth + tileGap),
                y: panelRect.minY + tileGap + CGFloat(row) * (tileHeight + tileGap),
                width: tileWidth,
                height: tileHeight
            )

            tileColor.setFill()
            NSBezierPath(
                roundedRect: tileRect,
                xRadius: CGFloat(size) * 0.045,
                yRadius: CGFloat(size) * 0.045
            ).fill()

            let insetRect = tileRect.insetBy(dx: tileWidth * 0.18, dy: tileHeight * 0.18)
            tileHighlight.setFill()
            NSBezierPath(
                roundedRect: insetRect,
                xRadius: CGFloat(size) * 0.025,
                yRadius: CGFloat(size) * 0.025
            ).fill()
        }
    }

    let lensRect = CGRect(
        x: rect.maxX - CGFloat(size) * 0.34,
        y: rect.minY + CGFloat(size) * 0.10,
        width: CGFloat(size) * 0.18,
        height: CGFloat(size) * 0.18
    )
    let lensOutline = NSBezierPath(ovalIn: lensRect)
    NSColor(calibratedWhite: 1.0, alpha: 0.9).setStroke()
    lensOutline.lineWidth = CGFloat(size) * 0.04
    lensOutline.stroke()
    NSColor(calibratedWhite: 1.0, alpha: 0.3).setFill()
    NSBezierPath(ovalIn: lensRect.insetBy(dx: CGFloat(size) * 0.035, dy: CGFloat(size) * 0.035)).fill()

    return image
}

for iconFile in iconFiles {
    let image = makeImage(size: iconFile.size)
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Failed to render icon \(iconFile.filename)")
    }

    try pngData.write(to: iconDirectory.appendingPathComponent(iconFile.filename), options: .atomic)
}

print("Generated \(iconFiles.count) app icon files in \(iconDirectory.path)")