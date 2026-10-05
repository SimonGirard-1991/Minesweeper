import CoreGraphics
import MinesweeperCore

struct PixelRect: Equatable {
    let x: Int
    let y: Int
    let width: Int
    let height: Int

    func contains(_ point: CGPoint) -> Bool {
        point.x >= CGFloat(x) && point.x < CGFloat(x + width)
            && point.y >= CGFloat(y) && point.y < CGFloat(y + height)
    }
}

/// The Windows XP window geometry in unzoomed pixels, origin top-left.
struct BoardLayout: Equatable {
    static let cell = SpriteSheet.tileSize
    private static let counterSize = (width: 41, height: 25)
    private static let fieldOrigin = (x: 12, y: 55)

    let columns: Int
    let rows: Int

    init(_ config: FieldConfig) {
        columns = config.width
        rows = config.height
    }

    var width: Int { columns * Self.cell + 2 * Self.fieldOrigin.x }
    var height: Int { rows * Self.cell + Self.fieldOrigin.y + Self.fieldOrigin.x }

    var header: PixelRect { PixelRect(x: 9, y: 9, width: width - 18, height: 37) }
    var field: PixelRect {
        PixelRect(x: Self.fieldOrigin.x, y: Self.fieldOrigin.y, width: columns * Self.cell, height: rows * Self.cell)
    }
    var mineCounter: PixelRect {
        PixelRect(x: 16, y: 15, width: Self.counterSize.width, height: Self.counterSize.height)
    }
    var timer: PixelRect {
        PixelRect(x: width - 16 - Self.counterSize.width, y: 15, width: Self.counterSize.width, height: Self.counterSize.height)
    }
    var smiley: PixelRect {
        PixelRect(x: (width - SpriteSheet.faceSize) / 2, y: 15, width: SpriteSheet.faceSize, height: SpriteSheet.faceSize)
    }

    func origin(of c: Coord) -> (x: Int, y: Int) {
        (field.x + c.col * Self.cell, field.y + c.row * Self.cell)
    }

    func cell(at point: CGPoint) -> Coord? {
        guard field.contains(point) else { return nil }
        return Coord(
            row: Int(point.y - CGFloat(field.y)) / Self.cell,
            col: Int(point.x - CGFloat(field.x)) / Self.cell)
    }
}
