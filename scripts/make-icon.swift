// Renders the Feathr Desk app icon (copper quill on the dark desk) into an .iconset folder.
// Usage: swift scripts/make-icon.swift <output.iconset>
import AppKit

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: r, green: g, blue: b, alpha: a)
}

let copper = rgb(0.86, 0.48, 0.22)
let highlight = rgb(0.98, 0.72, 0.42)
let deepCopper = rgb(0.70, 0.36, 0.16)
let cream = rgb(0.99, 0.90, 0.78)

func render(_ px: Int) -> Data? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    guard let ctx = NSGraphicsContext.current?.cgContext else { return nil }
    let scale = CGFloat(px) / 1024
    ctx.scaleBy(x: scale, y: scale)

    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.4).cgColor)
    rgb(0.09, 0.08, 0.07).setFill()
    shape.fill()
    ctx.restoreGState()

    ctx.saveGState()
    shape.addClip()
    NSGradient(colors: [rgb(0.20, 0.175, 0.155), rgb(0.075, 0.065, 0.06)])?.draw(in: body, angle: -90)
    NSGradient(colors: [copper.withAlphaComponent(0.30), copper.withAlphaComponent(0)])?
        .draw(fromCenter: NSPoint(x: 600, y: 600), radius: 0, toCenter: NSPoint(x: 600, y: 600), radius: 520, options: [])

    ctx.translateBy(x: 512, y: 500)
    ctx.rotate(by: -.pi / 4.6)

    let right = NSBezierPath()
    right.move(to: NSPoint(x: 0, y: 345))
    right.curve(to: NSPoint(x: 128, y: 70), controlPoint1: NSPoint(x: 60, y: 330), controlPoint2: NSPoint(x: 128, y: 190))
    right.curve(to: NSPoint(x: 38, y: -255), controlPoint1: NSPoint(x: 128, y: -60), controlPoint2: NSPoint(x: 90, y: -195))
    right.line(to: NSPoint(x: 0, y: -292))
    right.close()

    let left = NSBezierPath()
    left.move(to: NSPoint(x: 0, y: 335))
    left.curve(to: NSPoint(x: -104, y: 128), controlPoint1: NSPoint(x: -48, y: 322), controlPoint2: NSPoint(x: -104, y: 228))
    left.line(to: NSPoint(x: -38, y: 70))
    left.line(to: NSPoint(x: -116, y: 22))
    left.curve(to: NSPoint(x: -32, y: -262), controlPoint1: NSPoint(x: -120, y: -100), controlPoint2: NSPoint(x: -74, y: -212))
    left.line(to: NSPoint(x: 0, y: -292))
    left.close()

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: NSColor.black.withAlphaComponent(0.45).cgColor)
    copper.setFill()
    right.fill()
    left.fill()
    ctx.restoreGState()

    NSGradient(colors: [highlight, copper])?.draw(in: right, angle: -70)
    NSGradient(colors: [copper, deepCopper])?.draw(in: left, angle: -70)

    ctx.saveGState()
    let vane = NSBezierPath()
    vane.append(right)
    vane.append(left)
    vane.addClip()
    rgb(0.07, 0.06, 0.05, 0.22).setStroke()
    for y in stride(from: -200, through: 260, by: 52) {
        let barbR = NSBezierPath()
        barbR.move(to: NSPoint(x: 6, y: CGFloat(y)))
        barbR.line(to: NSPoint(x: 120, y: CGFloat(y) + 70))
        barbR.lineWidth = 5
        barbR.stroke()
        let barbL = NSBezierPath()
        barbL.move(to: NSPoint(x: -6, y: CGFloat(y) - 10))
        barbL.line(to: NSPoint(x: -105, y: CGFloat(y) + 52))
        barbL.lineWidth = 5
        barbL.stroke()
    }
    ctx.restoreGState()

    let shaft = NSBezierPath()
    shaft.move(to: NSPoint(x: 0, y: -405))
    shaft.curve(to: NSPoint(x: 0, y: 330), controlPoint1: NSPoint(x: 6, y: -120), controlPoint2: NSPoint(x: 4, y: 120))
    shaft.lineWidth = 13
    shaft.lineCapStyle = .round
    cream.setStroke()
    shaft.stroke()
    ctx.restoreGState()

    ctx.saveGState()
    shape.addClip()
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.10), NSColor.white.withAlphaComponent(0)])?
        .draw(in: CGRect(x: 100, y: 620, width: 824, height: 304), angle: -90)
    ctx.restoreGState()
    NSColor.white.withAlphaComponent(0.08).setStroke()
    shape.lineWidth = 3
    shape.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

let sizes: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, px) in sizes {
    guard let data = render(px) else { fatalError("Could not render \(name)") }
    try data.write(to: URL(fileURLWithPath: output).appendingPathComponent("\(name).png"))
}
print("Wrote \(output)")
