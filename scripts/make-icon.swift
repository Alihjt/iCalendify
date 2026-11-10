// Run from the repository root: xcrun swift scripts/make-icon.swift
// Uses only AppKit to generate the app icon; no downloaded fonts or artwork.
import AppKit

let output = URL(fileURLWithPath: "Assets", isDirectory: true)
let iconset = URL(fileURLWithPath: "build/AppIcon.iconset", isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func rounded(_ rect: NSRect, _ radius: CGFloat, fill: NSColor) {
    fill.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

func label(_ text: String, in rect: NSRect, size: CGFloat, weight: NSFont.Weight, ink: NSColor) {
    let system = NSFont.systemFont(ofSize: size, weight: weight)
    let descriptor = system.fontDescriptor.withDesign(.rounded) ?? system.fontDescriptor
    let font = NSFont(descriptor: descriptor, size: size) ?? system
    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: ink]
    let bounds = (text as NSString).size(withAttributes: attributes)
    (text as NSString).draw(at: NSPoint(x: rect.midX - bounds.width / 2,
                                      y: rect.midY - bounds.height / 2), withAttributes: attributes)
}

func png(pixels: Int) -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    context.setAllowsAntialiasing(true)

    let tile = NSBezierPath(roundedRect: NSRect(x: 36, y: 36, width: 952, height: 952), xRadius: 208, yRadius: 208)
    NSGradient(starting: color(23, 145, 131), ending: color(10, 77, 76))!.draw(in: tile, angle: -55)
    color(255, 255, 255, 0.17).setStroke()
    tile.lineWidth = 3
    tile.stroke()

    let paper = NSBezierPath(roundedRect: NSRect(x: 176, y: 196, width: 672, height: 628), xRadius: 72, yRadius: 72)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color(0, 35, 34, 0.26)
    shadow.shadowBlurRadius = 30
    shadow.shadowOffset = NSSize(width: 0, height: -14)
    shadow.set()
    color(248, 251, 246).setFill()
    paper.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    paper.addClip()
    color(211, 235, 224).setFill()
    NSRect(x: 176, y: 690, width: 672, height: 134).fill()
    NSGraphicsContext.restoreGraphicsState()

    for x: CGFloat in [304, 664] {
        NSGraphicsContext.saveGraphicsState()
        let bindingShadow = NSShadow()
        bindingShadow.shadowColor = color(12, 66, 59, 0.2)
        bindingShadow.shadowBlurRadius = 5
        bindingShadow.shadowOffset = NSSize(width: 0, height: -4)
        bindingShadow.set()
        rounded(NSRect(x: x, y: 746, width: 56, height: 132), 28, fill: color(253, 254, 250))
        NSGraphicsContext.restoreGraphicsState()
    }

    let ink = color(12, 96, 89)
    label("iC", in: NSRect(x: 200, y: 230, width: 624, height: 450), size: 360, weight: .bold, ink: ink)
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

try png(pixels: 1024).write(to: output.appendingPathComponent("AppIcon.png"))
for points in [16, 32, 128, 256, 512] {
    try png(pixels: points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try png(pixels: points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["--convert", "icns", iconset.path, "--output", output.appendingPathComponent("AppIcon.icns").path]
try task.run()
task.waitUntilExit()
guard task.terminationStatus == 0 else {
    fputs("Could not package the icon. Run this script from a normal Terminal session.\n", stderr)
    exit(task.terminationStatus)
}
print("Generated Assets/AppIcon.png and Assets/AppIcon.icns")
