import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let usage = """
    usage: icon-exporter [--dry-run] <AppIcon.appiconset directory>

    Renders the Minesweeper app icon at every macOS size and writes the PNGs
    plus Contents.json into the given asset-catalog folder, replacing them.

      --dry-run   list the files that would be written, write nothing
      -h, --help  show this help
    """

struct IconSize {
    let points: Int
    let scale: Int

    var pixels: Int { points * scale }
    var filename: String { "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png" }
}

let sizes = [16, 32, 128, 256, 512].flatMap { [IconSize(points: $0, scale: 1), IconSize(points: $0, scale: 2)] }

func fail(_ message: String, status: Int32) -> Never {
    FileHandle.standardError.write(Data("icon-exporter: \(message)\n".utf8))
    exit(status)
}

func image(of art: PixelArt) -> CGImage {
    let ctx = CGContext.pixelCanvas(width: art.width, height: art.height)
    ctx.paint(art, at: 0, 0)
    return ctx.makeImage()!
}

func renderIcon(pixels: Int) -> CGImage {
    let ctx = CGContext.pixelCanvas(width: pixels, height: pixels)
    let unit = CGFloat(pixels) / 1024
    let body = CGRect(x: 100 * unit, y: 100 * unit, width: 824 * unit, height: 824 * unit)
    let outline = CGPath(roundedRect: body, cornerWidth: 185 * unit, cornerHeight: 185 * unit, transform: nil)
    ctx.saveGState()
    ctx.setShouldAntialias(true)
    ctx.addPath(outline)
    ctx.clip()
    ctx.setShouldAntialias(false)
    ctx.interpolationQuality = .none
    let edge = (x: Int(body.minX), y: Int(body.minY), size: Int(body.width))
    ctx.fillPixels(edge.x, edge.y, edge.size, edge.size, Palette.face)
    ctx.drawBevel(edge.x, edge.y, edge.size, edge.size, thickness: max(1, edge.size * 6 / 100), raised: true)

    func draw(_ image: CGImage, in rect: CGRect) {
        ctx.saveGState()
        ctx.translateBy(x: rect.minX, y: rect.maxY)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(image, in: CGRect(origin: .zero, size: rect.size))
        ctx.restoreGState()
    }
    draw(image(of: Glyphs.mine), in: body.insetBy(dx: body.width * 0.2, dy: body.height * 0.2))
    ctx.restoreGState()

    ctx.setShouldAntialias(true)
    ctx.addPath(outline)
    ctx.setStrokeColor(Palette.shadow.cgColor)
    ctx.setLineWidth(max(1, 6 * unit))
    ctx.strokePath()
    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { fail("cannot create \(url.path)", status: 1) }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fail("cannot write \(url.path)", status: 1) }
}

func contentsJSON() throws -> Data {
    let images = sizes.map { size in
        ["filename": size.filename, "idiom": "mac", "scale": "\(size.scale)x", "size": "\(size.points)x\(size.points)"]
    }
    let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
    return try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
}

var dryRun = false
var target: String?
for argument in CommandLine.arguments.dropFirst() {
    switch argument {
    case "-h", "--help":
        print(usage)
        exit(0)
    case "--dry-run":
        dryRun = true
    case _ where argument.hasPrefix("-"):
        fail("unknown option \(argument)\n\(usage)", status: 2)
    default:
        guard target == nil else { fail("expected one directory\n\(usage)", status: 2) }
        target = argument
    }
}
guard let target else { fail("missing directory\n\(usage)", status: 2) }

let directory = URL(fileURLWithPath: target, isDirectory: true)
guard directory.lastPathComponent.hasSuffix(".appiconset") else {
    fail("\(target) is not an .appiconset folder", status: 2)
}
if !dryRun {
    do {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    } catch {
        fail("cannot create \(directory.path): \(error.localizedDescription)", status: 1)
    }
}

for size in sizes {
    let url = directory.appendingPathComponent(size.filename)
    if dryRun {
        print("would write \(url.path) (\(size.pixels)x\(size.pixels))")
    } else {
        writePNG(renderIcon(pixels: size.pixels), to: url)
        print("wrote \(url.path)")
    }
}
let contentsURL = directory.appendingPathComponent("Contents.json")
if dryRun {
    print("would write \(contentsURL.path)")
} else {
    do {
        try contentsJSON().write(to: contentsURL)
        print("wrote \(contentsURL.path)")
    } catch {
        fail("cannot write \(contentsURL.path): \(error.localizedDescription)", status: 1)
    }
}
