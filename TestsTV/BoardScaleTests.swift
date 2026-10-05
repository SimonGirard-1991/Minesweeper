import CoreGraphics
import MinesweeperCore
import Testing

struct BoardScaleTests {
    private let tvSafeArea = CGSize(width: 1760, height: 900)

    @Test func expertFillsA1080pScreenAtWholePoints() {
        // Arrange
        let layout = BoardLayout(.expert)

        // Act
        let zoom = BoardScale.fitting(width: layout.width, height: layout.height, in: tvSafeArea, displayScale: 1)

        // Assert
        #expect(zoom == 2)
    }

    @Test func a4KScreenAllowsHalfPointSteps() {
        // Arrange
        let layout = BoardLayout(.expert)

        // Act
        let zoom = BoardScale.fitting(width: layout.width, height: layout.height, in: tvSafeArea, displayScale: 2)

        // Assert
        #expect(zoom == 2.5)
        #expect(CGFloat(layout.height) * zoom <= tvSafeArea.height)
    }

    @Test func neverDropsBelowOneDevicePixel() {
        // Act
        let zoom = BoardScale.fitting(width: 500, height: 500, in: CGSize(width: 100, height: 100), displayScale: 2)

        // Assert
        #expect(zoom == 0.5)
    }

    @Test func anUnsetDisplayScaleCountsAsOne() {
        // Act
        let zoom = BoardScale.fitting(width: 100, height: 100, in: CGSize(width: 350, height: 350), displayScale: 0)

        // Assert
        #expect(zoom == 3)
    }
}
