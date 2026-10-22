// Draws the app icon (🎭 on a rounded gradient tile) into an .iconset folder.
import AppKit

let out = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

for (size, scale) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)] {
    let px = size * scale
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    let tile = NSRect(x: s * 0.1, y: s * 0.1, width: s * 0.8, height: s * 0.8)
    let path = NSBezierPath(roundedRect: tile, xRadius: s * 0.18, yRadius: s * 0.18)
    NSGradient(starting: NSColor(calibratedRed: 0.47, green: 0.33, blue: 0.95, alpha: 1),
               ending: NSColor(calibratedRed: 0.95, green: 0.38, blue: 0.62, alpha: 1))!
        .draw(in: path, angle: -60)
    let emoji = "🎭" as NSString
    let font = NSFont.systemFont(ofSize: s * 0.48)
    let attrs: [NSAttributedString.Key: Any] = [.font: font]
    let textSize = emoji.size(withAttributes: attrs)
    emoji.draw(at: NSPoint(x: (s - textSize.width) / 2, y: (s - textSize.height) / 2), withAttributes: attrs)
    NSGraphicsContext.restoreGraphicsState()
    let name = scale == 1 ? "icon_\(size)x\(size).png" : "icon_\(size)x\(size)@2x.png"
    try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/\(name)"))
}
