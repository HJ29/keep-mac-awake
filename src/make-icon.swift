import AppKit

// Renders AppIcon.icns: amber squircle + white cup glyph, at Apple's standard art inset.
let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "./AppIcon.iconset"

func tinted(_ image: NSImage, _ color: NSColor) -> NSImage {
    let out = NSImage(size: image.size)
    let bounds = NSRect(origin: .zero, size: image.size)
    out.lockFocus()
    color.set()
    bounds.fill()
    image.draw(in: bounds, from: bounds, operation: .destinationIn, fraction: 1)
    out.unlockFocus()
    return out
}

func render(_ pixels: Int) -> Data {
    let size = CGFloat(pixels)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // 824/1024 art box inside the canvas, 22.37% corner radius — matches macOS app icons.
    let inset = size * 0.0977
    let art = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let squircle = NSBezierPath(roundedRect: art, xRadius: art.width * 0.2237, yRadius: art.width * 0.2237)
    NSGradient(colors: [NSColor(srgbRed: 1.00, green: 0.76, blue: 0.36, alpha: 1),
                        NSColor(srgbRed: 0.91, green: 0.45, blue: 0.09, alpha: 1)])!
        .draw(in: squircle, angle: -90)

    let config = NSImage.SymbolConfiguration(pointSize: art.width * 0.46, weight: .medium)
    if let symbol = NSImage(systemSymbolName: "cup.and.saucer.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let glyph = tinted(symbol, .white)
        let box = NSRect(x: art.midX - glyph.size.width / 2,
                         y: art.midY - glyph.size.height / 2,
                         width: glyph.size.width, height: glyph.size.height)
        glyph.draw(in: box)
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! render(base).write(to: URL(fileURLWithPath: "\(outputDir)/icon_\(base)x\(base).png"))
    try! render(base * 2).write(to: URL(fileURLWithPath: "\(outputDir)/icon_\(base)x\(base)@2x.png"))
}
print("wrote iconset to \(outputDir)")
