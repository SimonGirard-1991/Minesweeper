public enum Difficulty: String, Codable, CodingKeyRepresentable, CaseIterable, Sendable {
    case beginner, intermediate, expert, custom
}

public struct FieldConfig: Codable, Equatable, Sendable {
    public static let beginner = FieldConfig(uncheckedWidth: 9, height: 9, mines: 10)
    public static let intermediate = FieldConfig(uncheckedWidth: 16, height: 16, mines: 40)
    public static let expert = FieldConfig(uncheckedWidth: 30, height: 16, mines: 99)

    public static let widthRange = 9...30
    public static let heightRange = 9...24
    public static let minimumMines = 10

    public let width: Int
    public let height: Int
    public let mines: Int

    public var cellCount: Int { width * height }

    /// Clamps every value into range the way the XP Custom Field dialog does, so any input is accepted.
    public init(width: Int, height: Int, mines: Int) {
        let width = min(max(width, Self.widthRange.lowerBound), Self.widthRange.upperBound)
        let height = min(max(height, Self.heightRange.lowerBound), Self.heightRange.upperBound)
        let maxMines = (width - 1) * (height - 1)
        self.init(uncheckedWidth: width, height: height, mines: min(max(mines, Self.minimumMines), maxMines))
    }

    private init(uncheckedWidth width: Int, height: Int, mines: Int) {
        self.width = width
        self.height = height
        self.mines = mines
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            width: try container.decode(Int.self, forKey: .width),
            height: try container.decode(Int.self, forKey: .height),
            mines: try container.decode(Int.self, forKey: .mines))
    }

    public static func preset(_ difficulty: Difficulty) -> FieldConfig? {
        switch difficulty {
        case .beginner: .beginner
        case .intermediate: .intermediate
        case .expert: .expert
        case .custom: nil
        }
    }
}
