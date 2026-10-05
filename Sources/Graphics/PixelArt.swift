import CoreGraphics

struct RGB: Hashable, Sendable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8

    init(_ hex: UInt32) {
        red = UInt8((hex >> 16) & 0xFF)
        green = UInt8((hex >> 8) & 0xFF)
        blue = UInt8(hex & 0xFF)
    }

    var cgColor: CGColor {
        CGColor(srgbRed: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: 1)
    }
}

enum Palette {
    static let face = RGB(0xC0C0C0)
    static let light = RGB(0xFFFFFF)
    static let shadow = RGB(0x808080)
    static let black = RGB(0x000000)
    static let red = RGB(0xFF0000)
    static let yellow = RGB(0xFFFF00)
    static let ledOn = RGB(0xFF0000)
    static let ledOff = RGB(0x420000)

    static let numbers: [Int: RGB] = [
        1: RGB(0x0000FF), 2: RGB(0x008000), 3: RGB(0xFF0000), 4: RGB(0x000080),
        5: RGB(0x800000), 6: RGB(0x008080), 7: RGB(0x000000), 8: RGB(0x808080),
    ]
}

/// A sprite drawn as text, one character per pixel; characters with no colour are transparent.
struct PixelArt: Sendable {
    let rows: [String]
    let colors: [Character: RGB]

    var width: Int { rows.first?.count ?? 0 }
    var height: Int { rows.count }
}

extension CGContext {
    /// A bitmap whose user space has its origin top-left, one unit per pixel, like the sprite maps.
    static func pixelCanvas(width: Int, height: Int) -> CGContext {
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { fatalError("Cannot allocate a \(width)x\(height) bitmap") }
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.setShouldAntialias(false)
        return context
    }

    func fillPixels(_ x: Int, _ y: Int, _ width: Int, _ height: Int, _ color: RGB) {
        guard width > 0, height > 0 else { return }
        setFillColor(color.cgColor)
        fill(CGRect(x: x, y: y, width: width, height: height))
    }

    /// The Windows 3D edge: light on the top and left, shadow on the bottom and right (swapped when sunken).
    /// The light band stops one pixel short per ring, which gives the diagonal split in the corners.
    func drawBevel(_ x: Int, _ y: Int, _ width: Int, _ height: Int, thickness: Int, raised: Bool) {
        let topLeft = raised ? Palette.light : Palette.shadow
        let bottomRight = raised ? Palette.shadow : Palette.light
        for i in 0..<thickness {
            fillPixels(x, y + height - 1 - i, width, 1, bottomRight)
            fillPixels(x + width - 1 - i, y, 1, height, bottomRight)
        }
        for i in 0..<thickness {
            fillPixels(x, y + i, width - 1 - i, 1, topLeft)
            fillPixels(x + i, y, 1, height - 1 - i, topLeft)
        }
    }

    func paint(_ art: PixelArt, at x: Int, _ y: Int) {
        for (row, line) in art.rows.enumerated() {
            for (col, char) in line.enumerated() {
                guard let color = art.colors[char] else { continue }
                fillPixels(x + col, y + row, 1, 1, color)
            }
        }
    }
}
