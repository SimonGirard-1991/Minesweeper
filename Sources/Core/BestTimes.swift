import Foundation

public struct BestTime: Codable, Equatable, Sendable {
    public static let anonymousName = "Anonymous"
    public static let unset = BestTime(seconds: Game.maxSeconds, name: anonymousName)
    public static let maxNameLength = 32

    public let seconds: Int
    public let name: String

    public init(seconds: Int, name: String) {
        self.seconds = min(max(seconds, 1), Game.maxSeconds)
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.name = trimmed.isEmpty ? Self.anonymousName : String(trimmed.prefix(Self.maxNameLength))
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            seconds: try container.decode(Int.self, forKey: .seconds),
            name: try container.decode(String.self, forKey: .name))
    }
}

public struct BestTimes: Codable, Equatable, Sendable {
    public static let rankedDifficulties: [Difficulty] = [.beginner, .intermediate, .expert]

    private var times: [Difficulty: BestTime] = [:]

    public init() {}

    /// Levels this build does not know are dropped instead of failing the decode and losing every record.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let stored = try container.decode([String: BestTime].self, forKey: .times)
        for (key, time) in stored {
            guard let difficulty = Difficulty(rawValue: key) else { continue }
            times[difficulty] = time
        }
    }

    public subscript(difficulty: Difficulty) -> BestTime {
        times[difficulty] ?? .unset
    }

    public func isRecord(seconds: Int, for difficulty: Difficulty) -> Bool {
        Self.rankedDifficulties.contains(difficulty) && seconds < self[difficulty].seconds
    }

    public mutating func record(seconds: Int, name: String, for difficulty: Difficulty) {
        guard isRecord(seconds: seconds, for: difficulty) else { return }
        times[difficulty] = BestTime(seconds: seconds, name: name)
    }

    public mutating func reset() {
        times = [:]
    }
}
