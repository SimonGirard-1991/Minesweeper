import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let usage = """
    usage: tv-icon-exporter [--dry-run] <AppIcon.brandassets directory>

    Renders the Minesweeper tvOS app icon (a back and a front parallax layer) and
    the Top Shelf images, then writes the PNGs plus every Contents.json into the
    given brand-asset folder, replacing them.

      --dry-run   list the files that would be written, write nothing
      -h, --help  show this help
    """

let info: [String: Any] = ["author": "xcode", "version": 1]

enum Layer: String, CaseIterable {
    case front = "Front"
    case back = "Back"
}

struct Stack {
    let name: String
    let size: String
    let width: Int
    let height: Int
    let scales: [Int]
}

struct Shelf {
    let name: String
    let role: String
    let width: Int
    let height: Int
}

let stacks = [
    Stack(name: "App Icon", size: "400x240", width: 400, height: 240, scales: [1, 2]),
    Stack(name: "App Icon - App Store", size: "1280x768", width: 1280, height: 768, scales: [1]),
]
let shelves = [
    Shelf(name: "Top Shelf Image", role: "top-shelf-image", width: 1920, height: 720),
    Shelf(name: "Top Shelf Image Wide", role: "top-shelf-image-wide", width: 2320, height: 720),
]

enum Content {
    case json([String: Any])
    case png(width: Int, height: Int, render: () -> CGImage)
}

func fail(_ message: String, status: Int32) -> Never {
    FileHandle.standardError.write(Data("tv-icon-exporter: \(message)\n".utf8))
    exit(status)
}

func image(of art: PixelArt) -> CGImage {
    let ctx = CGContext.pixelCanvas(width: art.width, height: art.height)
    ctx.paint(art, at: 0, 0)
    return ctx.makeImage()!
}

func draw(_ image: CGImage, in rect: CGRect, on ctx: CGContext) {
    ctx.saveGState()
    ctx.interpolationQuality = .none
    ctx.translateBy(x: rect.minX, y: rect.maxY)
    ctx.scaleBy(x: 1, y: -1)
    ctx.draw(image, in: CGRect(origin: .zero, size: rect.size))
    ctx.restoreGState()
}

/// tvOS masks the corners and adds the shine itself, so the back layer is a plain opaque raised panel.
func renderBack(width: Int, height: Int) -> CGImage {
    let ctx = CGContext.pixelCanvas(width: width, height: height)
    ctx.fillPixels(0, 0, width, height, Palette.face)
    ctx.drawBevel(0, 0, width, height, thickness: max(1, height * 5 / 100), raised: true)
    return ctx.makeImage()!
}

func renderFront(width: Int, height: Int) -> CGImage {
    let ctx = CGContext.pixelCanvas(width: width, height: height)
    let mine = Glyphs.mine
    let side = max(1, height * 6 / 10 / mine.height) * mine.height
    let rect = CGRect(x: (width - side) / 2, y: (height - side) / 2, width: side, height: side)
    draw(image(of: mine), in: rect, on: ctx)
    return ctx.makeImage()!
}

/// A real game on a fixed mine layout, so the numbers add up and every run renders the same banner.
func shelfGame() -> Game {
    let config = FieldConfig(width: 30, height: 10, mines: 45)
    let seed: UInt64 = 0x5EED
    let openings = [Coord(row: 5, col: 15), Coord(row: 4, col: 5), Coord(row: 5, col: 25)]
    let layout: MineLayout = { config, firstClick in
        var mines = Set<Coord>()
        var state = seed
        while mines.count < config.mines {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let c = Coord(row: Int(state >> 40) % config.height, col: Int(state >> 20 & 0xFFFFF) % config.width)
            if abs(c.row - firstClick.row) > 1 || abs(c.col - firstClick.col) > 1 { mines.insert(c) }
        }
        return mines
    }
    var game = Game(config: config, layout: layout)
    for opening in openings { game.reveal(opening) }
    for row in 0..<config.height {
        for col in 0..<config.width where (row + col) % 3 != 0 {
            let c = Coord(row: row, col: col)
            if game.cell(at: c).isMine && bordersOpenCell(c, in: game) { game.cycleMark(c) }
        }
    }
    return game
}

func bordersOpenCell(_ c: Coord, in game: Game) -> Bool {
    (-1...1).contains { dr in
        (-1...1).contains { dc in
            let n = Coord(row: c.row + dr, col: c.col + dc)
            return game.contains(n) && game.cell(at: n).isRevealed
        }
    }
}

func renderShelf(width: Int, height: Int, scale: Int) -> CGImage {
    let ctx = CGContext.pixelCanvas(width: width, height: height)
    let game = shelfGame()
    let tile = max(1, height / scale / 128) * SpriteSheet.tileSize * scale
    let origin = (x: (width - game.config.width * tile) / 2, y: (height - game.config.height * tile) / 2)
    for row in 0..<game.config.height {
        for col in 0..<game.config.width {
            let kind: TileKind = switch game.appearance(at: Coord(row: row, col: col)) {
            case .revealed(let n): n == 0 ? .pressed : .number(n)
            case .flag: .flag
            default: .hidden
            }
            let rect = CGRect(x: origin.x + col * tile, y: origin.y + row * tile, width: tile, height: tile)
            draw(SpriteSheet.renderTile(kind), in: rect, on: ctx)
        }
    }
    return ctx.makeImage()!
}

func pngName(_ base: String, scale: Int) -> String {
    "\(base)\(scale == 2 ? "@2x" : "").png"
}

@MainActor func plannedFiles() -> [(path: String, content: Content)] {
    var files: [(String, Content)] = []
    var assets: [[String: Any]] = []

    for stack in stacks {
        let stackDir = "\(stack.name).imagestack"
        assets.append(["filename": stackDir, "idiom": "tv", "role": "primary-app-icon", "size": stack.size])
        files.append(("\(stackDir)/Contents.json", .json([
            "info": info, "layers": Layer.allCases.map { ["filename": "\($0.rawValue).imagestacklayer"] },
        ])))
        for layer in Layer.allCases {
            let layerDir = "\(stackDir)/\(layer.rawValue).imagestacklayer"
            let base = layer.rawValue.lowercased()
            files.append(("\(layerDir)/Contents.json", .json(["info": info])))
            files.append(("\(layerDir)/Content.imageset/Contents.json", .json([
                "info": info,
                "images": stack.scales.map { ["filename": pngName(base, scale: $0), "idiom": "tv", "scale": "\($0)x"] },
            ])))
            for scale in stack.scales {
                let (width, height) = (stack.width * scale, stack.height * scale)
                let render = layer == .front ? renderFront : renderBack
                files.append(("\(layerDir)/Content.imageset/\(pngName(base, scale: scale))", .png(
                    width: width, height: height, render: { render(width, height) })))
            }
        }
    }

    for shelf in shelves {
        let setDir = "\(shelf.name).imageset"
        let base = shelf.role
        assets.append(["filename": setDir, "idiom": "tv", "role": shelf.role, "size": "\(shelf.width)x\(shelf.height)"])
        files.append(("\(setDir)/Contents.json", .json([
            "info": info,
            "images": [1, 2].map { ["filename": pngName(base, scale: $0), "idiom": "tv", "scale": "\($0)x"] },
        ])))
        for scale in [1, 2] {
            let (width, height) = (shelf.width * scale, shelf.height * scale)
            files.append(("\(setDir)/\(pngName(base, scale: scale))", .png(
                width: width, height: height, render: { renderShelf(width: width, height: height, scale: scale) })))
        }
    }

    files.append(("Contents.json", .json(["assets": assets, "info": info])))
    return files
}

func write(_ content: Content, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    switch content {
    case .json(let object):
        try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]).write(to: url)
    case .png(_, _, let render):
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { fail("cannot create \(url.path)", status: 1) }
        CGImageDestinationAddImage(destination, render(), nil)
        guard CGImageDestinationFinalize(destination) else { fail("cannot write \(url.path)", status: 1) }
    }
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
guard directory.lastPathComponent.hasSuffix(".brandassets") else {
    fail("\(target) is not a .brandassets folder", status: 2)
}

for (path, content) in plannedFiles() {
    let url = directory.appendingPathComponent(path)
    let detail = if case .png(let width, let height, _) = content { " (\(width)x\(height))" } else { "" }
    if dryRun {
        print("would write \(url.path)\(detail)")
        continue
    }
    do {
        try write(content, to: url)
    } catch {
        fail("cannot write \(url.path): \(error.localizedDescription)", status: 1)
    }
    print("wrote \(url.path)\(detail)")
}
