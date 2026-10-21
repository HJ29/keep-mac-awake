import AppKit

// Renders AppIcon.icns: a gibbous moon on a charcoal squircle, at Apple's standard art inset.
let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "./AppIcon.iconset"

func hex(_ v: Int) -> NSColor {
    NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1)
}

let tile = hex(0x1E2128)
let litColor = hex(0xF3F1EA), litCrater = hex(0xDCD8CD)
let shadowColor = hex(0x4A505A), shadowCrater = hex(0x3D424B)

// (x, y, r) in moon radii: separate craters, a few cut by the edge, one across the terminator.
let craters: [(CGFloat, CGFloat, CGFloat)] = [
    (-0.35, 0.30, 0.20), (-0.10, -0.40, 0.19), (0.15, 0.48, 0.12), (-0.45, -0.22, 0.13),
    (0.12, 0.02, 0.07), (-0.65, 0.12, 0.06), (0.30, -0.12, 0.05),
    (-0.80, -0.48, 0.14), (0.05, -0.88, 0.10),
    (0.75, 0.25, 0.10), (0.68, -0.40, 0.07), (0.50, 0.62, 0.11),
]

func disk(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> NSBezierPath {
    NSBezierPath(ovalIn: NSRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
}

/// Draws the moon in 1024-unit space; `lit` is the lit fraction of the width (0.5 = half moon).
func drawMoon(cx: CGFloat = 512, cy: CGFloat = 512, r: CGFloat = 310, lit: CGFloat = 0.78) {
    let a = r * (lit - 0.5) * 2
    let litPath = NSBezierPath()
    litPath.appendArc(withCenter: NSPoint(x: cx, y: cy), radius: r, startAngle: 90, endAngle: 270)
    litPath.close()
    litPath.append(NSBezierPath(ovalIn: NSRect(x: cx - a, y: cy - r, width: a * 2, height: r * 2)))

    let shadowPath = NSBezierPath(rect: NSRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
    shadowPath.append(litPath)
    shadowPath.windingRule = .evenOdd

    for (region, fill, crater) in [(shadowPath, shadowColor, shadowCrater), (litPath, litColor, litCrater)] {
        NSGraphicsContext.saveGraphicsState()
        disk(cx, cy, r).addClip()
        region.addClip()
        fill.setFill()
        NSRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2).fill()
        crater.setFill()
        for (x, y, cr) in craters { disk(cx + x * r, cy + y * r, cr * r).fill() }
        NSGraphicsContext.restoreGraphicsState()
    }
}

func render(_ pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)

    // 824/1024 art box, 22.37% corner radius — matches macOS app icons.
    let squircle = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 184, yRadius: 184)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(white: 0, alpha: 0.28)
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.shadowBlurRadius = 24
    shadow.set()
    tile.setFill()
    squircle.fill()
    NSGraphicsContext.restoreGraphicsState()

    drawMoon()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! render(base).write(to: URL(fileURLWithPath: "\(outputDir)/icon_\(base)x\(base).png"))
    try! render(base * 2).write(to: URL(fileURLWithPath: "\(outputDir)/icon_\(base)x\(base)@2x.png"))
}
print("wrote iconset to \(outputDir)")
