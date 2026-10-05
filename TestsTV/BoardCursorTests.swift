import MinesweeperCore
import Testing

struct BoardCursorTests {
    @Test func startsOnTheCentreCell() {
        // Act
        let sut = BoardCursor(.expert)

        // Assert
        #expect(sut.target == .cell(Coord(row: 8, col: 15)))
    }

    @Test func stopsAtTheFieldEdges() {
        // Arrange
        var sut = BoardCursor(.beginner)

        // Act
        for _ in 0..<20 {
            sut.move(.down)
            sut.move(.right)
        }

        // Assert
        #expect(sut.cell == Coord(row: 8, col: 8))
    }

    @Test func upFromTheTopRowSelectsTheSmiley() {
        // Arrange
        var sut = BoardCursor(.beginner)

        // Act
        for _ in 0..<5 { sut.move(.up) }

        // Assert
        #expect(sut.target == .smiley)
        #expect(sut.cell == nil)
    }

    @Test func downFromTheSmileyReturnsToTheColumnItLeft() {
        // Arrange
        var sut = BoardCursor(.intermediate)
        sut.move(.left)
        sut.move(.left)
        for _ in 0..<9 { sut.move(.up) }

        // Act
        sut.move(.left)
        sut.move(.right)
        sut.move(.down)

        // Assert
        #expect(sut.cell == Coord(row: 0, col: 6))
    }

    @Test func fitsOnlyAFieldOfTheSameSize() {
        // Arrange
        let sut = BoardCursor(.beginner)

        // Act + Assert
        #expect(sut.fits(FieldConfig(width: 9, height: 9, mines: 30)))
        #expect(!sut.fits(.intermediate))
    }
}
