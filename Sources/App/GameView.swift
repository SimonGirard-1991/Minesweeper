import AppKit
import MinesweeperCore

@MainActor
protocol GameViewDelegate: AnyObject {
    func gameView(_ view: GameView, revealAt cell: Coord)
    func gameView(_ view: GameView, chordAt cell: Coord)
    func gameView(_ view: GameView, cycleMarkAt cell: Coord)
    func gameViewRequestsNewGame(_ view: GameView)
}

/// Like XP, a reveal or chord happens on button release, so a press can be dragged off and cancelled.
final class GameView: NSView {
    private enum Gesture {
        case none, reveal, chord, smiley
    }

    weak var delegate: GameViewDelegate?

    var game: Game {
        didSet { needsDisplay = true }
    }

    var zoom: Int {
        didSet { needsDisplay = true }
    }

    private let sprites = SpriteSheet()
    private var gesture = Gesture.none
    private var pressedCell: Coord?
    private var smileyHeld = false

    init(game: Game, zoom: Int) {
        self.game = game
        self.zoom = zoom
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("GameView is built in code") }

    private var layout: BoardLayout { BoardLayout(game.config) }

    var preferredSize: NSSize {
        NSSize(width: layout.width * zoom, height: layout.height * zoom)
    }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let layout = layout
        ctx.saveGState()
        defer { ctx.restoreGState() }
        ctx.scaleBy(x: CGFloat(zoom), y: CGFloat(zoom))
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
        ctx.drawSprite(sprites.face(face, pressed: gesture == .smiley && smileyHeld), at: smiley.x, smiley.y)

        for row in 0..<layout.rows {
            for col in 0..<layout.columns {
                let c = Coord(row: row, col: col)
                let origin = layout.origin(of: c)
                ctx.drawSprite(sprites.tile(tileKind(at: c)), at: origin.x, origin.y)
            }
        }
    }

    private func drawCounter(_ value: Int, in r: PixelRect, _ ctx: CGContext) {
        ctx.drawBevel(r.x, r.y, r.width, r.height, thickness: 1, raised: false)
        for (i, glyph) in LEDGlyph.display(value).enumerated() {
            ctx.drawSprite(sprites.led(glyph), at: r.x + 1 + i * SpriteSheet.ledSize.width, r.y + 1)
        }
    }

    private var face: Face {
        switch game.state {
        case .won: .cool
        case .lost: .dead
        case .ready, .playing: gesture == .reveal || gesture == .chord ? .oh : .smile
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

    private func isPressed(_ c: Coord) -> Bool {
        guard let pressedCell, !game.isOver else { return false }
        switch gesture {
        case .reveal: return c == pressedCell
        case .chord: return abs(c.row - pressedCell.row) <= 1 && abs(c.col - pressedCell.col) <= 1
        case .none, .smiley: return false
        }
    }

    // MARK: Mouse

    /// Read live rather than tracked: a modal dialog swallows the mouse-up, which would leave a stored flag stuck.
    private var isRightButtonDown: Bool { NSEvent.pressedMouseButtons & (1 << 1) != 0 }

    private func unzoomedPoint(_ event: NSEvent) -> CGPoint {
        let p = convert(event.locationInWindow, from: nil)
        return CGPoint(x: p.x / CGFloat(zoom), y: p.y / CGFloat(zoom))
    }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            rightMouseDown(with: event)
            return
        }
        let point = unzoomedPoint(event)
        if layout.smiley.contains(point) && !isRightButtonDown {
            gesture = .smiley
            smileyHeld = true
        } else if !game.isOver {
            gesture = isRightButtonDown || event.modifierFlags.contains(.option) ? .chord : .reveal
            pressedCell = layout.cell(at: point)
        }
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) { track(event) }

    override func mouseUp(with event: NSEvent) { finishGesture() }

    override func rightMouseDown(with event: NSEvent) {
        switch gesture {
        case .reveal:
            gesture = .chord
            needsDisplay = true
        case .none:
            if let cell = layout.cell(at: unzoomedPoint(event)) {
                delegate?.gameView(self, cycleMarkAt: cell)
            }
        case .chord, .smiley:
            break
        }
    }

    override func rightMouseDragged(with event: NSEvent) { track(event) }

    override func rightMouseUp(with event: NSEvent) {
        if gesture == .chord { finishGesture() }
    }

    override func otherMouseDown(with event: NSEvent) {
        guard event.buttonNumber == 2, gesture == .none, !game.isOver else { return }
        gesture = .chord
        pressedCell = layout.cell(at: unzoomedPoint(event))
        needsDisplay = true
    }

    override func otherMouseDragged(with event: NSEvent) { track(event) }

    override func otherMouseUp(with event: NSEvent) {
        if gesture == .chord { finishGesture() }
    }

    private func track(_ event: NSEvent) {
        let point = unzoomedPoint(event)
        switch gesture {
        case .smiley: smileyHeld = layout.smiley.contains(point)
        case .reveal, .chord: pressedCell = layout.cell(at: point)
        case .none: return
        }
        needsDisplay = true
    }

    private func finishGesture() {
        let finished = gesture
        let cell = pressedCell
        let onSmiley = smileyHeld
        gesture = .none
        pressedCell = nil
        smileyHeld = false
        needsDisplay = true

        switch finished {
        case .smiley where onSmiley: delegate?.gameViewRequestsNewGame(self)
        case .reveal: if let cell { delegate?.gameView(self, revealAt: cell) }
        case .chord: if let cell { delegate?.gameView(self, chordAt: cell) }
        case .none, .smiley: break
        }
    }
}

private extension CGContext {
    /// `draw(_:in:)` assumes a bottom-left origin, so in a flipped view each sprite is flipped back.
    func drawSprite(_ image: CGImage, at x: Int, _ y: Int) {
        saveGState()
        translateBy(x: CGFloat(x), y: CGFloat(y + image.height))
        scaleBy(x: 1, y: -1)
        draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        restoreGState()
    }
}
