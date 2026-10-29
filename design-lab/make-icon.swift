import AppKit

// Use the same licensed Lucide shield as the About window, at all Dock sizes.
let directory = URL(fileURLWithPath: CommandLine.arguments[1])
let svg = try String(contentsOfFile: CommandLine.arguments[2])
    .replacingOccurrences(of: "stroke=\"currentColor\"", with: "stroke=\"#ffffff\"")
guard let glyph = NSImage(data: Data(svg.utf8)) else { fatalError("Lucide shield cannot be decoded") }
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        let size = CGFloat(pixels)
        let box = NSRect(x: size * 0.07, y: size * 0.07, width: size * 0.86, height: size * 0.86)
        let path = NSBezierPath(roundedRect: box, xRadius: size * 0.2, yRadius: size * 0.2)
        NSGradient(starting: .systemBlue, ending: .systemIndigo)!.draw(in: path, angle: -45)
        glyph.draw(in: NSRect(x: size * 0.27, y: size * 0.27, width: size * 0.46, height: size * 0.46))
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { fatalError("Icon rendering failed") }
        let suffix = scale == 2 ? "@2x" : ""
        try png.write(to: directory.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
    }
}
