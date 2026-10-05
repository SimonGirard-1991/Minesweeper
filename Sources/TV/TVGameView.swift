import MinesweeperCore
import UIKit

final class TVGameView: UIView {
    private static let ringOutline = Palette.black
    private static let ring = Palette.yellow

    var game: Game {
        didSet { setNeedsDisplay() }
    }

    var cursor: BoardCursor {
        didSet { setNeedsDisplay() }
    }

    /// Select is held down; XP's mouse-down look, committed on release.
    var isPressing = false {
        didSet { setNeedsDisplay() }
    }

    private let sprites = SpriteSheet()

    init(game: Game, cursor: BoardCursor) {
        self.game = game
        self.cursor = cursor
        super.init(frame: .zero)
        isOpaque = true
        contentMode = .redraw
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("TVGameView is built in code") }

    var layout: BoardLayout { BoardLayout(game.config) }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let layout = layout
        let zoom = bounds.width / CGFloat(layout.width)
        ctx.saveGState()
        defer { ctx.restoreGState() }
        ctx.scaleBy(x: zoom, y: zoom)
        ctx.interpolationQuality = .none
        ctx.setShouldAntialias(false)

        ctx.fillPixels(0, 0, layout.width, layout.height, Palette.face)
        ctx.drawBevel(0, 0, layout.width, layout.height, thickness: 3, raised: true)
        let header = layout.header
        ctx.drawBevel(header.x, header.y, header.width, header.height, thickness: 2, raised: false)
        let field = layout.field
        ctx.drawBevel(field.x - 3, field.y - 3, field.width + 6, field.height + 6, thickness: 3, raised: false)

        drawCounter(game.minesRemaining, in: layout.mineCounter, ctx)
        drawCounter(game.elapsedSeconds, in: layout.timer, ctx)
        let smiley = layout.smiley
        ctx.drawSprite(sprites.face(face, pressed: isPressing && cursor.target == .smiley), at: smiley.x, smiley.y)

        for row in 0..<layout.rows {
            for col in 0..<layout.columns {
                let c = Coord(row: row, col: col)
                let origin = layout.origin(of: c)
                ctx.drawSprite(sprites.tile(tileKind(at: c)), at: origin.x, origin.y)
            }
        }
        drawRing(around: cursorRect(layout), ctx)
    }

    private func drawCounter(_ value: Int, in r: PixelRect, _ ctx: CGContext) {
        ctx.drawBevel(r.x, r.y, r.width, r.height, thickness: 1, raised: false)
        for (i, glyph) in LEDGlyph.display(value).enumerated() {
            ctx.drawSprite(sprites.led(glyph), at: r.x + 1 + i * SpriteSheet.ledSize.width, r.y + 1)
        }
    }

    private func cursorRect(_ layout: BoardLayout) -> PixelRect {
        guard let cell = cursor.cell else { return layout.smiley }
        let origin = layout.origin(of: cell)
        return PixelRect(x: origin.x, y: origin.y, width: BoardLayout.cell, height: BoardLayout.cell)
    }

    /// Yellow inside a black outline, so the ring reads on the grey tiles, the white bevels and a black mine alike.
    private func drawRing(around r: PixelRect, _ ctx: CGContext) {
        ctx.strokePixels(r.x - 1, r.y - 1, r.width + 2, r.height + 2, thickness: 1, Self.ringOutline)
        ctx.strokePixels(r.x, r.y, r.width, r.height, thickness: 2, Self.ring)
        ctx.strokePixels(r.x + 2, r.y + 2, r.width - 4, r.height - 4, thickness: 1, Self.ringOutline)
    }

    private var face: Face {
        switch game.state {
        case .won: .cool
        case .lost: .dead
        case .ready, .playing: isPressing && cursor.cell != nil ? .oh : .smile
        }
    }

    private func tileKind(at c: Coord) -> TileKind {
        let pressed = isPressed(c)
        switch game.appearance(at: c) {
        case .hidden: return pressed ? .pressed : .hidden
        case .question: return pressed ? .questionPressed : .question
        case .flag: return .flag
        case .revealed(let n): return n == 0 ? .pressed : .number(n)
        case .mine: return .mine
        case .explodedMine: return .explodedMine
        case .wrongFlag: return .wrongFlag
        }
    }

    /// Select on a revealed number chords, so the whole 3×3 block goes down, as under XP's two-button press.
    private func isPressed(_ c: Coord) -> Bool {
        guard isPressing, let pressed = cursor.cell, !game.isOver else { return false }
        guard case .revealed = game.appearance(at: pressed) else { return c == pressed }
        return abs(c.row - pressed.row) <= 1 && abs(c.col - pressed.col) <= 1
    }
}

private extension CGContext {
    /// `draw(_:in:)` assumes a bottom-left origin, so in UIKit's top-left space each sprite is flipped back.
    func drawSprite(_ image: CGImage, at x: Int, _ y: Int) {
        saveGState()
        translateBy(x: CGFloat(x), y: CGFloat(y + image.height))
        scaleBy(x: 1, y: -1)
        draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        restoreGState()
    }

    func strokePixels(_ x: Int, _ y: Int, _ width: Int, _ height: Int, thickness t: Int, _ color: RGB) {
        fillPixels(x, y, width, t, color)
        fillPixels(x, y + height - t, width, t, color)
        fillPixels(x, y + t, t, height - 2 * t, color)
        fillPixels(x + width - t, y + t, t, height - 2 * t, color)
    }
}
