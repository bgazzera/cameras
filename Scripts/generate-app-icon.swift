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
    let radius = CGFloat(size) * 0.23
    let shellStart = NSColor(calibratedRed: 0.05, green: 0.09, blue: 0.12, alpha: 1.0)
    let shellEnd = NSColor(calibratedRed: 0.16, green: 0.22, blue: 0.26, alpha: 1.0)
    let accentBright = NSColor(calibratedRed: 0.47, green: 0.86, blue: 0.98, alpha: 1.0)
    let accentMid = NSColor(calibratedRed: 0.15, green: 0.68, blue: 0.86, alpha: 1.0)
    let accentDeep = NSColor(calibratedRed: 0.07, green: 0.28, blue: 0.43, alpha: 1.0)

    let shellPath = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    shellPath.addClip()
    NSGradient(colors: [shellStart, shellEnd])?.draw(in: rect, angle: -90)

    let glowRect = CGRect(
        x: rect.minX + CGFloat(size) * 0.08,
        y: rect.midY,
        width: CGFloat(size) * 0.84,
        height: CGFloat(size) * 0.56
    )
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(ovalIn: glowRect).addClip()
    NSGradient(colors: [accentBright.withAlphaComponent(0.55), accentMid.withAlphaComponent(0.08)])?.draw(in: glowRect, angle: 90)
    NSGraphicsContext.restoreGraphicsState()

    let bodyRect = CGRect(
        x: rect.minX + CGFloat(size) * 0.15,
        y: rect.minY + CGFloat(size) * 0.24,
        width: CGFloat(size) * 0.70,
        height: CGFloat(size) * 0.46
    )
    let bodyRadius = CGFloat(size) * 0.14
    let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: bodyRadius, yRadius: bodyRadius)
    NSGradient(colors: [NSColor(calibratedWhite: 0.16, alpha: 1.0), NSColor(calibratedWhite: 0.09, alpha: 1.0)])?.draw(in: bodyPath, angle: -90)

    let topBarRect = CGRect(
        x: bodyRect.minX + CGFloat(size) * 0.07,
        y: bodyRect.maxY - CGFloat(size) * 0.05,
        width: CGFloat(size) * 0.26,
        height: CGFloat(size) * 0.10
    )
    let topBarPath = NSBezierPath(roundedRect: topBarRect, xRadius: CGFloat(size) * 0.04, yRadius: CGFloat(size) * 0.04)
    NSGradient(colors: [accentMid, accentDeep])?.draw(in: topBarPath, angle: -90)

    let badgeRect = CGRect(
        x: bodyRect.minX + CGFloat(size) * 0.09,
        y: bodyRect.midY + CGFloat(size) * 0.09,
        width: CGFloat(size) * 0.12,
        height: CGFloat(size) * 0.12
    )
    accentBright.setFill()
    NSBezierPath(ovalIn: badgeRect).fill()

    let lensOuterRect = CGRect(
        x: rect.midX - CGFloat(size) * 0.21,
        y: rect.midY - CGFloat(size) * 0.21,
        width: CGFloat(size) * 0.42,
        height: CGFloat(size) * 0.42
    )
    let lensMidRect = lensOuterRect.insetBy(dx: CGFloat(size) * 0.035, dy: CGFloat(size) * 0.035)
    let lensInnerRect = lensOuterRect.insetBy(dx: CGFloat(size) * 0.105, dy: CGFloat(size) * 0.105)
    let lensCoreRect = lensOuterRect.insetBy(dx: CGFloat(size) * 0.165, dy: CGFloat(size) * 0.165)

    let ringShadow = NSShadow()
    ringShadow.shadowBlurRadius = CGFloat(size) * 0.035
    ringShadow.shadowOffset = NSSize(width: 0, height: -CGFloat(size) * 0.012)
    ringShadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
    NSGraphicsContext.saveGraphicsState()
    ringShadow.set()
    NSGradient(colors: [NSColor(calibratedWhite: 0.72, alpha: 1.0), NSColor(calibratedWhite: 0.34, alpha: 1.0)])?.draw(in: NSBezierPath(ovalIn: lensOuterRect), angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    NSGradient(colors: [accentBright, accentDeep])?.draw(in: NSBezierPath(ovalIn: lensMidRect), angle: -50)
    NSGradient(colors: [NSColor(calibratedRed: 0.02, green: 0.08, blue: 0.14, alpha: 1.0), NSColor(calibratedRed: 0.13, green: 0.50, blue: 0.66, alpha: 1.0)])?.draw(in: NSBezierPath(ovalIn: lensInnerRect), angle: -60)
    NSGradient(colors: [NSColor(calibratedWhite: 0.04, alpha: 1.0), NSColor(calibratedRed: 0.08, green: 0.30, blue: 0.44, alpha: 1.0)])?.draw(in: NSBezierPath(ovalIn: lensCoreRect), angle: -90)

    let highlightRect = CGRect(
        x: lensInnerRect.minX + CGFloat(size) * 0.035,
        y: lensInnerRect.midY,
        width: CGFloat(size) * 0.12,
        height: CGFloat(size) * 0.08
    )
    NSColor.white.withAlphaComponent(0.30).setFill()
    NSBezierPath(ovalIn: highlightRect).fill()

    let innerHighlightRect = CGRect(
        x: lensCoreRect.minX + CGFloat(size) * 0.045,
        y: lensCoreRect.minY + CGFloat(size) * 0.055,
        width: CGFloat(size) * 0.06,
        height: CGFloat(size) * 0.06
    )
    NSColor.white.withAlphaComponent(0.20).setFill()
    NSBezierPath(ovalIn: innerHighlightRect).fill()

    let focusMarkRect = CGRect(
        x: bodyRect.maxX - CGFloat(size) * 0.17,
        y: bodyRect.minY + CGFloat(size) * 0.08,
        width: CGFloat(size) * 0.08,
        height: CGFloat(size) * 0.08
    )
    accentBright.withAlphaComponent(0.9).setFill()
    NSBezierPath(ovalIn: focusMarkRect).fill()

    NSColor.white.withAlphaComponent(0.14).setStroke()
    let shellStroke = NSBezierPath(roundedRect: rect.insetBy(dx: CGFloat(size) * 0.01, dy: CGFloat(size) * 0.01), xRadius: radius * 0.96, yRadius: radius * 0.96)
    shellStroke.lineWidth = max(1, CGFloat(size) * 0.012)
    shellStroke.stroke()

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