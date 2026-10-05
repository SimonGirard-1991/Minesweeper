import MinesweeperCore
import Testing

struct SelectActionTests {
    private static let mine = Coord(row: 0, col: 1)

    /// Mines wall in the top-left cell, so opening the centre floods the middle without winning.
    private static func openedGame() -> Game {
        var game = Game(config: .beginner) { _, _ in
            Set([mine, Coord(row: 1, col: 0), Coord(row: 1, col: 1)] + (0..<7).map { Coord(row: 8, col: $0) })
        }
        game.reveal(Coord(row: 4, col: 4))
        return game
    }

    @Test func selectOnTheSmileyStartsANewGame() {
        // Arrange
        var sut = BoardCursor(.beginner)
        for _ in 0..<5 { sut.move(.up) }

        // Act + Assert
        #expect(sut.selectAction(in: Self.openedGame()) == .newGame)
    }

    @Test func selectOnAHiddenCellReveals() {
        // Arrange
        let sut = BoardCursor(.beginner)

        // Act + Assert
        #expect(sut.selectAction(in: Game(config: .beginner)) == .reveal(Coord(row: 4, col: 4)))
    }

    @Test func selectOnARevealedCellChords() {
        // Arrange
        let sut = BoardCursor(.beginner)

        // Act + Assert
        #expect(sut.selectAction(in: Self.openedGame()) == .chord(Coord(row: 4, col: 4)))
    }

    @Test func aFinishedGameIgnoresTheField() {
        // Arrange
        var game = Self.openedGame()
        game.reveal(Self.mine)
        let sut = BoardCursor(.beginner)

        // Act + Assert
        #expect(!sut.canPress(in: game))
    }

    @Test func aFinishedGameStillAnswersOnTheSmiley() {
        // Arrange
        var game = Self.openedGame()
        game.reveal(Self.mine)
        var sut = BoardCursor(.beginner)
        for _ in 0..<5 { sut.move(.up) }

        // Act + Assert
        #expect(sut.canPress(in: game))
    }

    @Test func aGameInPlayAnswersOnTheField() {
        // Act + Assert
        #expect(BoardCursor(.beginner).canPress(in: Self.openedGame()))
    }
}
