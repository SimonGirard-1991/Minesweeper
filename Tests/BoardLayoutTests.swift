import CoreGraphics
import MinesweeperCore
import Testing

struct BoardLayoutTests {
    @Test func windowSizeFollowsTheXPMargins() {
        // Act
        let sut = BoardLayout(.beginner)

        // Assert
        #expect(sut.width == 9 * 16 + 24)
        #expect(sut.height == 9 * 16 + 67)
        #expect(sut.timer.x + sut.timer.width == sut.width - 16)
    }

    @Test func hitTestingMapsTheFieldEdgesToCells() {
        // Arrange
        let sut = BoardLayout(.expert)
        let field = sut.field

        // Act
        let topLeft = sut.cell(at: CGPoint(x: field.x, y: field.y))
        let bottomRight = sut.cell(at: CGPoint(x: field.x + field.width - 1, y: field.y + field.height - 1))
        let pastRight = sut.cell(at: CGPoint(x: field.x + field.width, y: field.y))
        let aboveField = sut.cell(at: CGPoint(x: field.x, y: field.y - 1))

        // Assert
        #expect(topLeft == Coord(row: 0, col: 0))
        #expect(bottomRight == Coord(row: 15, col: 29))
        #expect(pastRight == nil)
        #expect(aboveField == nil)
    }

    @Test func smileyIsCentredAndOutsideTheField() {
        // Act
        let sut = BoardLayout(.intermediate)

        // Assert
        #expect(sut.smiley.x * 2 + sut.smiley.width == sut.width)
        #expect(sut.cell(at: CGPoint(x: sut.smiley.x + 13, y: sut.smiley.y + 13)) == nil)
    }
}
