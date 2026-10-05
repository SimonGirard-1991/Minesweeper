import MinesweeperCore
import Testing

private func game(
    width: Int = 9, height: Int = 9, mines: Set<Coord>, marksEnabled: Bool = true
) -> Game {
    let config = FieldConfig(width: width, height: height, mines: max(mines.count, FieldConfig.minimumMines))
    return Game(config: config, marksEnabled: marksEnabled) { _, _ in mines }
}

private func at(_ row: Int, _ col: Int) -> Coord { Coord(row: row, col: col) }

struct FirstClickTests {
    @Test(arguments: [Difficulty.beginner, .intermediate, .expert])
    func randomLayoutPlacesExactlyTheMineCountAndNeverOnTheFirstClick(difficulty: Difficulty) throws {
        // Arrange
        let config = try #require(FieldConfig.preset(difficulty))
        let firstClick = at(config.height / 2, config.width / 2)

        for _ in 0..<200 {
            // Act
            let mines = Game.randomLayout(config, firstClick)

            // Assert
            #expect(mines.count == config.mines)
            #expect(!mines.contains(firstClick))
            #expect(mines.allSatisfy { (0..<config.height).contains($0.row) && (0..<config.width).contains($0.col) })
        }
    }

    @Test func firstRevealNeverLosesAndStartsTheTimerAtOne() {
        // Arrange
        var sut = Game(config: .expert)

        // Act
        sut.reveal(at(0, 0))

        // Assert
        #expect(sut.state == .playing || sut.state == .won)
        #expect(sut.elapsedSeconds == 1)
    }

    @Test func minesArePlacedOnlyWhenTheFirstCellIsOpened() {
        // Arrange
        var sut = Game(config: .beginner) { _, first in [at(first.row, 0)] }
        sut.cycleMark(at(1, 1))

        // Act
        sut.reveal(at(4, 4))

        // Assert
        #expect(sut.cell(at: at(4, 0)).isMine)
        #expect(!sut.cell(at: at(1, 0)).isMine)
    }
}

struct RevealTests {
    @Test func openingAZeroFloodFillsUpToTheNumbersAroundIt() {
        // Arrange
        var sut = game(mines: [at(8, 8)])

        // Act
        sut.reveal(at(0, 0))

        // Assert
        #expect(sut.appearance(at: at(0, 0)) == .revealed(0))
        #expect(sut.appearance(at: at(7, 7)) == .revealed(1))
        #expect(sut.appearance(at: at(8, 8)) == .flag)
        #expect(sut.state == .won)
    }

    @Test func floodFillStopsAtFlagsAndClearsQuestionMarks() {
        // Arrange
        var sut = game(mines: [at(8, 8), at(8, 0)])
        sut.cycleMark(at(4, 4))
        sut.cycleMark(at(4, 4))
        sut.cycleMark(at(0, 4))

        // Act
        sut.reveal(at(0, 0))

        // Assert
        #expect(sut.appearance(at: at(4, 4)) == .revealed(0))
        #expect(sut.cell(at: at(4, 4)).mark == .none)
        #expect(sut.appearance(at: at(0, 4)) == .flag)
    }

    @Test func revealingAMineLosesAndExposesTheBoard() {
        // Arrange
        var sut = game(mines: [at(0, 0), at(0, 2), at(5, 5)])
        sut.reveal(at(8, 8))
        sut.cycleMark(at(0, 2))
        sut.cycleMark(at(0, 1))

        // Act
        sut.reveal(at(0, 0))

        // Assert
        #expect(sut.state == .lost(exploded: at(0, 0)))
        #expect(sut.appearance(at: at(0, 0)) == .explodedMine)
        #expect(sut.appearance(at: at(0, 2)) == .flag)
        #expect(sut.appearance(at: at(0, 1)) == .wrongFlag)
        #expect(sut.appearance(at: at(5, 5)) == .mine)
    }

    @Test func flaggedCellsCannotBeOpened() {
        // Arrange
        var sut = game(mines: [at(0, 0)])
        sut.cycleMark(at(0, 0))

        // Act
        sut.reveal(at(0, 0))

        // Assert
        #expect(sut.state == .ready)
    }

    @Test func revealsOutsideTheFieldOrAfterTheGameAreIgnored() {
        // Arrange
        var sut = game(mines: [at(0, 1), at(1, 0), at(1, 1)])
        sut.reveal(at(8, 8))
        sut.reveal(at(0, 1))

        // Act
        sut.reveal(at(0, 0))
        sut.reveal(at(-1, 3))
        sut.reveal(at(3, 9))

        // Assert
        #expect(sut.state == .lost(exploded: at(0, 1)))
        #expect(sut.appearance(at: at(0, 0)) == .hidden)
    }
}

struct ChordTests {
    private func playing() -> Game {
        var sut = game(mines: [at(0, 0), at(0, 2), at(7, 8), at(8, 7)])
        sut.reveal(at(1, 1))
        return sut
    }

    @Test func opensTheNeighboursWhenTheFlagsMatchTheNumber() {
        // Arrange
        var sut = playing()
        sut.cycleMark(at(0, 0))
        sut.cycleMark(at(0, 2))

        // Act
        sut.chord(at(1, 1))

        // Assert
        #expect(sut.appearance(at: at(0, 1)) == .revealed(2))
        #expect(sut.appearance(at: at(2, 2)) == .revealed(0))
        #expect(sut.state == .playing)
    }

    @Test func doesNothingWithTooFewFlags() {
        // Arrange
        var sut = playing()
        sut.cycleMark(at(0, 0))

        // Act
        sut.chord(at(1, 1))

        // Assert
        #expect(sut.appearance(at: at(0, 1)) == .hidden)
        #expect(sut.state == .playing)
    }

    @Test func losesOnAWrongFlag() {
        // Arrange
        var sut = playing()
        sut.cycleMark(at(0, 0))
        sut.cycleMark(at(0, 1))

        // Act
        sut.chord(at(1, 1))

        // Assert
        #expect(sut.state == .lost(exploded: at(0, 2)))
        #expect(sut.appearance(at: at(0, 1)) == .wrongFlag)
    }

    @Test func ignoredOnHiddenCellsAndZeros() {
        // Arrange
        var sut = playing()
        sut.reveal(at(5, 0))

        // Act
        sut.chord(at(0, 1))
        sut.chord(at(5, 0))

        // Assert
        #expect(sut.appearance(at: at(0, 1)) == .hidden)
        #expect(sut.state == .playing)
    }
}

struct MarkTests {
    @Test func cyclesFlagQuestionBlankWithMarksOn() {
        // Arrange
        var sut = game(mines: [at(0, 0)])
        var seen: [CellAppearance] = []

        // Act
        for _ in 0..<3 {
            sut.cycleMark(at(4, 4))
            seen.append(sut.appearance(at: at(4, 4)))
        }

        // Assert
        #expect(seen == [.flag, .question, .hidden])
        #expect(sut.flagCount == 0)
    }

    @Test func skipsTheQuestionMarkWithMarksOff() {
        // Arrange
        var sut = game(mines: [at(0, 0)], marksEnabled: false)

        // Act
        sut.cycleMark(at(4, 4))
        sut.cycleMark(at(4, 4))

        // Assert
        #expect(sut.appearance(at: at(4, 4)) == .hidden)
    }

    @Test func mineCounterCanGoNegative() {
        // Arrange
        var sut = Game(config: .beginner)

        // Act
        for col in 0..<9 {
            sut.cycleMark(at(0, col))
            sut.cycleMark(at(1, col))
        }

        // Assert
        #expect(sut.minesRemaining == -8)
    }

    @Test func revealedCellsCannotBeMarked() {
        // Arrange
        var sut = game(mines: [at(7, 8), at(8, 7)])
        sut.reveal(at(0, 0))

        // Act
        sut.cycleMark(at(0, 0))

        // Assert
        #expect(sut.flagCount == 0)
    }
}

struct WinAndTimerTests {
    @Test func winningFlagsEveryMineAndZeroesTheCounter() {
        // Arrange
        var sut = game(mines: [at(0, 0), at(8, 8)])
        sut.cycleMark(at(4, 4))
        sut.cycleMark(at(4, 4))

        // Act
        sut.reveal(at(4, 0))

        // Assert
        #expect(sut.state == .won)
        #expect(sut.appearance(at: at(0, 0)) == .flag)
        #expect(sut.appearance(at: at(8, 8)) == .flag)
        #expect(sut.minesRemaining == 0)
    }

    @Test func timerTicksOnlyWhilePlayingAndStopsAt999() {
        // Arrange
        var sut = game(mines: [at(0, 0), at(8, 8)])
        sut.tick()
        let beforeStart = sut.elapsedSeconds
        sut.reveal(at(0, 1))

        // Act
        for _ in 0..<2000 { sut.tick() }

        // Assert
        #expect(beforeStart == 0)
        #expect(sut.elapsedSeconds == Game.maxSeconds)
    }

    @Test func timerStopsWhenTheGameEnds() {
        // Arrange
        var sut = game(mines: [at(0, 0), at(8, 8)])
        sut.reveal(at(0, 1))
        sut.tick()
        sut.reveal(at(0, 0))

        // Act
        sut.tick()

        // Assert
        #expect(sut.elapsedSeconds == 2)
    }
}
