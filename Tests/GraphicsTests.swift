import CoreGraphics
import Testing

private func pixel(_ image: CGImage, _ x: Int, _ y: Int) -> RGB {
    var rgba = [UInt8](repeating: 0, count: 4)
    let ctx = CGContext(
        data: &rgba, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.draw(image, in: CGRect(x: -x, y: y - image.height + 1, width: image.width, height: image.height))
    return RGB(UInt32(rgba[0]) << 16 | UInt32(rgba[1]) << 8 | UInt32(rgba[2]))
}

struct SpriteMapTests {
    @Test func everyNumberGlyphIsRectangular() {
        // Act + Assert
        for (n, rows) in Glyphs.numbers {
            #expect(Set(rows.map(\.count)) == [10], "number \(n)")
            #expect(rows.count == 11, "number \(n)")
        }
    }

    @Test(arguments: [Glyphs.mine, Glyphs.flag, Glyphs.question, Glyphs.faceOutline])
    func pixelArtIsRectangularAndUsesOnlyItsColours(art: PixelArt) {
        // Act
        let widths = Set(art.rows.map(\.count))
        let unknown = Set(art.rows.joined()).subtracting(art.colors.keys).subtracting(["."])

        // Assert
        #expect(widths.count == 1)
        #expect(unknown.isEmpty)
    }

    @Test func faceFeaturesStayInsideTheFace() {
        // Act + Assert
        for (face, pixels) in Glyphs.faceFeatures {
            for (row, col) in pixels {
                let line = Array(Glyphs.faceOutline.rows[row])
                #expect(line[col] == "Y", "\(face) pixel \(row),\(col)")
            }
        }
    }
}

struct LEDDisplayTests {
    @Test(arguments: [
        (0, [LEDGlyph.digit(0), .digit(0), .digit(0)]),
        (10, [.digit(0), .digit(1), .digit(0)]),
        (999, [.digit(9), .digit(9), .digit(9)]),
        (1500, [.digit(9), .digit(9), .digit(9)]),
        (-8, [.minus, .digit(0), .digit(8)]),
        (-150, [.minus, .digit(9), .digit(9)]),
    ])
    func formatsLikeTheXPCounters(value: Int, expected: [LEDGlyph]) {
        // Act + Assert
        #expect(LEDGlyph.display(value) == expected)
    }
}

struct RenderingTests {
    @Test func hiddenTileIsLitTopLeftWithADiagonalCorner() {
        // Act
        let tile = SpriteSheet.renderTile(.hidden)

        // Assert
        #expect(tile.width == 16 && tile.height == 16)
        #expect(pixel(tile, 0, 0) == Palette.light)
        #expect(pixel(tile, 14, 0) == Palette.light)
        #expect(pixel(tile, 15, 0) == Palette.shadow)
        #expect(pixel(tile, 0, 15) == Palette.shadow)
        #expect(pixel(tile, 15, 15) == Palette.shadow)
        #expect(pixel(tile, 8, 8) == Palette.face)
    }

    @Test func openedTileHasItsGridLineOnTopAndLeft() {
        // Act
        let tile = SpriteSheet.renderTile(.pressed)

        // Assert
        #expect(pixel(tile, 8, 0) == Palette.shadow)
        #expect(pixel(tile, 0, 8) == Palette.shadow)
        #expect(pixel(tile, 15, 15) == Palette.face)
    }

    @Test func flagPoleIsUprightNotMirrored() {
        // Act
        let tile = SpriteSheet.renderTile(.flag)

        // Assert
        #expect(pixel(tile, 7, 3) == Palette.red)
        #expect(pixel(tile, 5, 12) == Palette.black)
    }

    @Test func ledLightsOnlyTheMiddleSegmentForMinus() {
        // Act
        let image = SpriteSheet.renderLED(.minus)

        // Assert
        #expect(pixel(image, 6, 11) == Palette.ledOn)
        #expect(pixel(image, 6, 1) == Palette.ledOff)
        #expect(pixel(image, 0, 0) == Palette.black)
    }

    @Test func sheetRendersEverySprite() {
        // Act
        let sheet = SpriteSheet()

        // Assert
        #expect(sheet.face(.dead, pressed: true).width == SpriteSheet.faceSize)
        #expect(sheet.tile(.number(8)).height == SpriteSheet.tileSize)
        #expect(sheet.led(.digit(7)).height == SpriteSheet.ledSize.height)
    }
}
