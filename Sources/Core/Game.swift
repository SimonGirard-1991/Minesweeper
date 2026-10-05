public enum GameState: Equatable, Sendable {
    case ready
    case playing
    case won
    case lost(exploded: Coord)
}

public enum CellAppearance: Equatable, Sendable {
    case hidden
    case flag
    case question
    case revealed(Int)
    case mine
    case explodedMine
    case wrongFlag
}

/// Picks the mine positions once the first cell is opened; the result must not contain that cell.
public typealias MineLayout = @Sendable (FieldConfig, _ firstClick: Coord) -> Set<Coord>

public struct Game: Sendable {
    public static let maxSeconds = 999

    public static let randomLayout: MineLayout = { config, firstClick in
        var candidates = (0..<config.height).flatMap { row in
            (0..<config.width).map { Coord(row: row, col: $0) }
        }
        candidates.removeAll { $0 == firstClick }
        return Set(candidates.shuffled().prefix(config.mines))
    }

    public let config: FieldConfig
    public var marksEnabled: Bool
    public private(set) var state = GameState.ready
    public private(set) var elapsedSeconds = 0
    public private(set) var flagCount = 0
    public private(set) var mineCount: Int

    private var board: Board
    private var revealedCount = 0
    private let layout: MineLayout

    public init(config: FieldConfig, marksEnabled: Bool = true, layout: @escaping MineLayout = Game.randomLayout) {
        self.config = config
        self.marksEnabled = marksEnabled
        self.layout = layout
        mineCount = config.mines
        board = Board(width: config.width, height: config.height)
    }

    public var minesRemaining: Int { mineCount - flagCount }

    public var isOver: Bool {
        switch state {
        case .won, .lost: true
        case .ready, .playing: false
        }
    }

    public func contains(_ c: Coord) -> Bool { board.contains(c) }

    public func cell(at c: Coord) -> Cell { board[c] }

    public func appearance(at c: Coord) -> CellAppearance {
        let cell = board[c]
        if cell.isRevealed { return .revealed(cell.adjacentMines) }
        if case .lost(let exploded) = state {
            if c == exploded { return .explodedMine }
            if cell.mark == .flag { return cell.isMine ? .flag : .wrongFlag }
            if cell.isMine { return .mine }
        }
        switch cell.mark {
        case .none: return .hidden
        case .flag: return .flag
        case .question: return .question
        }
    }

    public mutating func reveal(_ c: Coord) {
        guard !isOver, board.contains(c), !board[c].isRevealed, board[c].mark != .flag else { return }
        if state == .ready { start(firstClick: c) }
        if board[c].isMine {
            state = .lost(exploded: c)
            return
        }
        floodReveal(from: c)
        checkForWin()
    }

    /// Opens every unflagged neighbour of a revealed number once enough flags surround it, as XP's two-button click does.
    public mutating func chord(_ c: Coord) {
        guard state == .playing, board.contains(c) else { return }
        let cell = board[c]
        guard cell.isRevealed, cell.adjacentMines > 0 else { return }
        let neighbours = board.neighbours(of: c)
        guard neighbours.filter({ board[$0].mark == .flag }).count == cell.adjacentMines else { return }

        let toOpen = neighbours.filter { !board[$0].isRevealed && board[$0].mark != .flag }
        if let mine = toOpen.first(where: { board[$0].isMine }) {
            state = .lost(exploded: mine)
            return
        }
        for n in toOpen { floodReveal(from: n) }
        checkForWin()
    }

    public mutating func cycleMark(_ c: Coord) {
        guard !isOver, board.contains(c), !board[c].isRevealed else { return }
        switch board[c].mark {
        case .none:
            board[c].mark = .flag
            flagCount += 1
        case .flag:
            board[c].mark = marksEnabled ? .question : .none
            flagCount -= 1
        case .question:
            board[c].mark = .none
        }
    }

    public mutating func tick() {
        guard state == .playing, elapsedSeconds < Self.maxSeconds else { return }
        elapsedSeconds += 1
    }

    private mutating func start(firstClick: Coord) {
        let mines = layout(config, firstClick)
        board.layMines(at: mines)
        mineCount = mines.count
        state = .playing
        elapsedSeconds = 1
    }

    private mutating func floodReveal(from start: Coord) {
        var pending = [start]
        while let c = pending.popLast() {
            guard !board[c].isRevealed, board[c].mark != .flag else { continue }
            board[c].isRevealed = true
            board[c].mark = .none
            revealedCount += 1
            if board[c].adjacentMines == 0 {
                pending.append(contentsOf: board.neighbours(of: c))
            }
        }
    }

    private mutating func checkForWin() {
        guard revealedCount == config.cellCount - mineCount else { return }
        state = .won
        for c in board.allCoords where board[c].isMine {
            board[c].mark = .flag
        }
        flagCount = mineCount
    }
}
