public struct Coord: Hashable, Sendable {
    public let row: Int
    public let col: Int

    public init(row: Int, col: Int) {
        self.row = row
        self.col = col
    }
}

public enum Mark: Sendable {
    case none, flag, question
}

public struct Cell: Equatable, Sendable {
    public var isMine = false
    public var isRevealed = false
    public var mark = Mark.none
    public var adjacentMines = 0
}

struct Board: Sendable {
    let width: Int
    let height: Int
    private var cells: [Cell]

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        cells = Array(repeating: Cell(), count: width * height)
    }

    var allCoords: [Coord] {
        (0..<height).flatMap { row in (0..<width).map { Coord(row: row, col: $0) } }
    }

    func contains(_ c: Coord) -> Bool {
        (0..<height).contains(c.row) && (0..<width).contains(c.col)
    }

    subscript(_ c: Coord) -> Cell {
        get { cells[c.row * width + c.col] }
        set { cells[c.row * width + c.col] = newValue }
    }

    func neighbours(of c: Coord) -> [Coord] {
        (-1...1).flatMap { dr in
            (-1...1).compactMap { dc -> Coord? in
                guard dr != 0 || dc != 0 else { return nil }
                let n = Coord(row: c.row + dr, col: c.col + dc)
                return contains(n) ? n : nil
            }
        }
    }

    mutating func layMines(at mines: Set<Coord>) {
        for c in mines { self[c].isMine = true }
        for c in allCoords {
            self[c].adjacentMines = neighbours(of: c).filter { self[$0].isMine }.count
        }
    }
}
