import MinesweeperCore

enum CursorMove {
    case up, down, left, right
}

/// The Siri Remote stands in for the mouse: the cursor sits on a cell or on the smiley above the field.
struct BoardCursor: Equatable {
    enum Target: Equatable {
        case cell(Coord)
        case smiley
    }

    let rows: Int
    let columns: Int
    private(set) var target: Target
    private var column: Int

    init(_ config: FieldConfig) {
        rows = config.height
        columns = config.width
        let centre = Coord(row: config.height / 2, col: config.width / 2)
        target = .cell(centre)
        column = centre.col
    }

    var cell: Coord? {
        guard case .cell(let c) = target else { return nil }
        return c
    }

    func fits(_ config: FieldConfig) -> Bool {
        rows == config.height && columns == config.width
    }

    mutating func move(_ move: CursorMove) {
        guard case .cell(let c) = target else {
            if move == .down { target = .cell(Coord(row: 0, col: column)) }
            return
        }
        let next: Coord
        switch move {
        case .up where c.row == 0:
            target = .smiley
            return
        case .up: next = Coord(row: c.row - 1, col: c.col)
        case .down: next = Coord(row: min(c.row + 1, rows - 1), col: c.col)
        case .left: next = Coord(row: c.row, col: max(c.col - 1, 0))
        case .right: next = Coord(row: c.row, col: min(c.col + 1, columns - 1))
        }
        target = .cell(next)
        column = next.col
    }
}

enum SelectAction: Equatable {
    case newGame
    case reveal(Coord)
    case chord(Coord)
}

extension BoardCursor {
    /// Once a game is over only the smiley still answers, as under XP.
    func canPress(in game: Game) -> Bool {
        target == .smiley || !game.isOver
    }

    /// Select on a revealed number chords: the remote has no second button for XP's two-button click.
    func selectAction(in game: Game) -> SelectAction {
        guard let cell else { return .newGame }
        if case .revealed = game.appearance(at: cell) { return .chord(cell) }
        return .reveal(cell)
    }
}
