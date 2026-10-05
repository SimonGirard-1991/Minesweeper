import CoreGraphics

enum BoardScale {
    /// Rounded down to whole device pixels: a fractional pixel would draw some sprite pixels wider than others.
    static func fitting(width: Int, height: Int, in available: CGSize, displayScale: CGFloat) -> CGFloat {
        let displayScale = max(displayScale, 1)
        let pixels = min(
            available.width * displayScale / CGFloat(width),
            available.height * displayScale / CGFloat(height))
        return max(pixels.rounded(.down), 1) / displayScale
    }
}
