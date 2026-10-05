import CoreGraphics

enum Glyphs {
    static let numbers: [Int: [String]] = [
        1: [
            "....###...",
            "...####...",
            "..#####...",
            ".######...",
            "....###...",
            "....###...",
            "....###...",
            "....###...",
            "....###...",
            ".########.",
            ".########.",
        ],
        2: [
            "..######..",
            ".########.",
            ".###..###.",
            "......###.",
            ".....####.",
            "....####..",
            "...####...",
            "..####....",
            ".###......",
            ".########.",
            ".########.",
        ],
        3: [
            ".#######..",
            ".########.",
            "......###.",
            "......###.",
            "...######.",
            "...######.",
            "......###.",
            "......###.",
            "......###.",
            ".########.",
            ".#######..",
        ],
        4: [
            ".###..###.",
            ".###..###.",
            ".###..###.",
            ".###..###.",
            ".########.",
            ".########.",
            "......###.",
            "......###.",
            "......###.",
            "......###.",
            "......###.",
        ],
        5: [
            ".########.",
            ".########.",
            ".###......",
            ".###......",
            ".#######..",
            ".########.",
            "......###.",
            "......###.",
            "......###.",
            ".########.",
            ".#######..",
        ],
        6: [
            "..#######.",
            ".########.",
            ".###......",
            ".###......",
            ".#######..",
            ".########.",
            ".###..###.",
            ".###..###.",
            ".###..###.",
            ".########.",
            "..######..",
        ],
        7: [
            ".########.",
            ".########.",
            "......###.",
            "......###.",
            ".....###..",
            ".....###..",
            "....###...",
            "....###...",
            "...###....",
            "...###....",
            "...###....",
        ],
        8: [
            "..######..",
            ".########.",
            ".###..###.",
            ".###..###.",
            "..######..",
            "..######..",
            ".###..###.",
            ".###..###.",
            ".###..###.",
            ".########.",
            "..######..",
        ],
    ]

    static let mine = PixelArt(rows: [
        "......#......",
        "......#......",
        "..#.#####.#..",
        "...#######...",
        "..##WW#####..",
        "..##WW#####..",
        "#############",
        "..#########..",
        "..#########..",
        "...#######...",
        "..#.#####.#..",
        "......#......",
        "......#......",
    ], colors: ["#": Palette.black, "W": Palette.light])

    static let flag = PixelArt(rows: [
        ".....RR.....",
        "...RRRR.....",
        "..RRRRR.....",
        "...RRRR.....",
        ".....RR.....",
        "......#.....",
        "......#.....",
        "....####....",
        "..########..",
        "..########..",
    ], colors: ["R": Palette.red, "#": Palette.black])

    static let question = PixelArt(rows: [
        "...####...",
        "..##..##..",
        "..##..##..",
        "......##..",
        ".....##...",
        "....##....",
        "....##....",
        "..........",
        "....##....",
        "....##....",
    ], colors: ["#": Palette.black])

    static let faceOutline = PixelArt(rows: [
        "......#####......",
        "....##YYYYY##....",
        "...#YYYYYYYYY#...",
        "..#YYYYYYYYYYY#..",
        ".#YYYYYYYYYYYYY#.",
        ".#YYYYYYYYYYYYY#.",
        "#YYYYYYYYYYYYYYY#",
        "#YYYYYYYYYYYYYYY#",
        "#YYYYYYYYYYYYYYY#",
        "#YYYYYYYYYYYYYYY#",
        "#YYYYYYYYYYYYYYY#",
        ".#YYYYYYYYYYYYY#.",
        ".#YYYYYYYYYYYYY#.",
        "..#YYYYYYYYYYY#..",
        "...#YYYYYYYYY#...",
        "....##YYYYY##....",
        "......#####......",
    ], colors: ["#": Palette.black, "Y": Palette.yellow])

    private static let eyes = [(5, 5), (5, 6), (6, 5), (6, 6), (5, 10), (5, 11), (6, 10), (6, 11)]
    private static let smile = [(10, 4), (10, 12), (11, 5), (11, 11), (12, 6), (12, 7), (12, 8), (12, 9), (12, 10)]

    /// Black pixels drawn over `faceOutline`, as (row, column).
    static let faceFeatures: [Face: [(Int, Int)]] = [
        .smile: eyes + smile,
        .oh: eyes + [(10, 7), (10, 8), (10, 9), (11, 6), (11, 10), (12, 6), (12, 10), (13, 7), (13, 8), (13, 9)],
        .cool: smile
            + (3...13).map { (5, $0) }
            + [4, 5, 6, 7, 9, 10, 11, 12].map { (6, $0) }
            + [5, 6, 10, 11].map { (7, $0) },
        .dead: [(5, 5), (6, 6), (7, 7), (5, 7), (7, 5), (5, 9), (6, 10), (7, 11), (5, 11), (7, 9)]
            + (6...10).map { (11, $0) }
            + [(12, 5), (12, 11), (13, 4), (13, 12)],
    ]
}

enum Face: CaseIterable, Sendable {
    case smile, oh, cool, dead
}

enum TileKind: Hashable, Sendable {
    case hidden
    case pressed
    case number(Int)
    case flag
    case question
    case questionPressed
    case mine
    case explodedMine
    case wrongFlag
}

enum LEDGlyph: Hashable, Sendable {
    case digit(Int)
    case minus

    /// Segments a…g, clockwise from the top with g in the middle.
    var segments: Set<Character> {
        switch self {
        case .minus: ["g"]
        case .digit(let d):
            switch d {
            case 0: ["a", "b", "c", "d", "e", "f"]
            case 1: ["b", "c"]
            case 2: ["a", "b", "g", "e", "d"]
            case 3: ["a", "b", "g", "c", "d"]
            case 4: ["f", "g", "b", "c"]
            case 5: ["a", "f", "g", "c", "d"]
            case 6: ["a", "f", "g", "e", "c", "d"]
            case 7: ["a", "b", "c"]
            case 8: ["a", "b", "c", "d", "e", "f", "g"]
            default: ["a", "b", "c", "d", "f", "g"]
            }
        }
    }

    /// Three glyphs for the XP counters, which clamp to -99…999.
    static func display(_ value: Int) -> [LEDGlyph] {
        let clamped = min(max(value, -99), 999)
        let magnitude = abs(clamped)
        let digits = [magnitude / 100, magnitude / 10 % 10, magnitude % 10].map(LEDGlyph.digit)
        return clamped < 0 ? [.minus] + digits.dropFirst() : digits
    }
}

/// Every image the game draws, rendered once at one pixel per point.
final class SpriteSheet {
    static let tileSize = 16
    static let faceSize = 26
    static let ledSize = (width: 13, height: 23)

    private var tiles: [TileKind: CGImage] = [:]
    private var faces: [Face: (up: CGImage, down: CGImage)] = [:]
    private var leds: [LEDGlyph: CGImage] = [:]

    init() {
        let kinds: [TileKind] = [.hidden, .pressed, .flag, .question, .questionPressed, .mine, .explodedMine, .wrongFlag]
            + (1...8).map(TileKind.number)
        for kind in kinds { tiles[kind] = Self.renderTile(kind) }
        for face in Face.allCases {
            faces[face] = (Self.renderFace(face, pressed: false), Self.renderFace(face, pressed: true))
        }
        for glyph in (0...9).map(LEDGlyph.digit) + [.minus] { leds[glyph] = Self.renderLED(glyph) }
    }

    func tile(_ kind: TileKind) -> CGImage { tiles[kind]! }
    func face(_ face: Face, pressed: Bool) -> CGImage { pressed ? faces[face]!.down : faces[face]!.up }
    func led(_ glyph: LEDGlyph) -> CGImage { leds[glyph]! }

    static func renderTile(_ kind: TileKind) -> CGImage {
        let size = tileSize
        let ctx = CGContext.pixelCanvas(width: size, height: size)
        func raised() {
            ctx.fillPixels(0, 0, size, size, Palette.face)
            ctx.drawBevel(0, 0, size, size, thickness: 2, raised: true)
        }
        func opened(background: RGB = Palette.face) {
            ctx.fillPixels(0, 0, size, size, background)
            ctx.fillPixels(0, 0, size, 1, Palette.shadow)
            ctx.fillPixels(0, 0, 1, size, Palette.shadow)
        }
        switch kind {
        case .hidden:
            raised()
        case .pressed:
            opened()
        case .number(let n):
            opened()
            ctx.paint(PixelArt(rows: Glyphs.numbers[n] ?? [], colors: ["#": Palette.numbers[n] ?? Palette.black]), at: 3, 3)
        case .flag:
            raised()
            ctx.paint(Glyphs.flag, at: 2, 3)
        case .question:
            raised()
            ctx.paint(Glyphs.question, at: 3, 3)
        case .questionPressed:
            opened()
            ctx.paint(Glyphs.question, at: 4, 4)
        case .mine:
            opened()
            ctx.paint(Glyphs.mine, at: 2, 2)
        case .explodedMine:
            opened()
            ctx.fillPixels(1, 1, size - 1, size - 1, Palette.red)
            ctx.paint(Glyphs.mine, at: 2, 2)
        case .wrongFlag:
            opened()
            ctx.paint(Glyphs.mine, at: 2, 2)
            for i in 0..<12 {
                ctx.fillPixels(2 + i, 2 + i, 2, 1, Palette.red)
                ctx.fillPixels(13 - i, 2 + i, 2, 1, Palette.red)
            }
        }
        return ctx.makeImage()!
    }

    static func renderFace(_ face: Face, pressed: Bool) -> CGImage {
        let size = faceSize
        let ctx = CGContext.pixelCanvas(width: size, height: size)
        ctx.fillPixels(0, 0, size, size, Palette.shadow)
        ctx.fillPixels(1, 1, size - 2, size - 2, Palette.face)
        let offset: Int
        if pressed {
            ctx.fillPixels(1, 1, size - 2, 1, Palette.shadow)
            ctx.fillPixels(1, 1, 1, size - 2, Palette.shadow)
            offset = 5
        } else {
            ctx.drawBevel(1, 1, size - 2, size - 2, thickness: 2, raised: true)
            offset = 4
        }
        ctx.paint(Glyphs.faceOutline, at: offset, offset)
        for (row, col) in Glyphs.faceFeatures[face] ?? [] {
            ctx.fillPixels(offset + col, offset + row, 1, 1, Palette.black)
        }
        return ctx.makeImage()!
    }

    static func renderLED(_ glyph: LEDGlyph) -> CGImage {
        let (width, height) = ledSize
        let ctx = CGContext.pixelCanvas(width: width, height: height)
        ctx.fillPixels(0, 0, width, height, Palette.black)
        let lit = glyph.segments
        func color(_ segment: Character) -> RGB { lit.contains(segment) ? Palette.ledOn : Palette.ledOff }
        // Each segment is three pixels thick and tapers by one pixel per side toward the digit's inside.
        for i in 0..<3 {
            ctx.fillPixels(2 + i, 1 + i, 9 - 2 * i, 1, color("a"))
            ctx.fillPixels(2 + i, 21 - i, 9 - 2 * i, 1, color("d"))
            ctx.fillPixels(1 + i, 2 + i, 1, 9 - 2 * i, color("f"))
            ctx.fillPixels(11 - i, 2 + i, 1, 9 - 2 * i, color("b"))
            ctx.fillPixels(1 + i, 12 + i, 1, 9 - 2 * i, color("e"))
            ctx.fillPixels(11 - i, 12 + i, 1, 9 - 2 * i, color("c"))
        }
        ctx.fillPixels(3, 10, 7, 1, color("g"))
        ctx.fillPixels(2, 11, 9, 1, color("g"))
        ctx.fillPixels(3, 12, 7, 1, color("g"))
        return ctx.makeImage()!
    }
}
