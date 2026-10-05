import Foundation

public struct Settings: Codable, Equatable, Sendable {
    public static let zoomLevels = 1...2

    public var difficulty = Difficulty.beginner
    public var customField = FieldConfig.beginner
    public var marksEnabled = true
    public var zoom = 1 {
        didSet { zoom = Self.clampedZoom(zoom) }
    }
    public var bestTimes = BestTimes()
    public var lastRecordName = BestTime.anonymousName

    public init() {}

    public var fieldConfig: FieldConfig {
        FieldConfig.preset(difficulty) ?? customField
    }

    private static func clampedZoom(_ zoom: Int) -> Int {
        min(max(zoom, zoomLevels.lowerBound), zoomLevels.upperBound)
    }

    /// Every key is optional so a settings blob from an older version keeps its best times.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Settings()
        difficulty = (try? container.decodeIfPresent(Difficulty.self, forKey: .difficulty)) ?? defaults.difficulty
        customField = (try? container.decodeIfPresent(FieldConfig.self, forKey: .customField)) ?? defaults.customField
        marksEnabled = (try? container.decodeIfPresent(Bool.self, forKey: .marksEnabled)) ?? defaults.marksEnabled
        zoom = Self.clampedZoom((try? container.decodeIfPresent(Int.self, forKey: .zoom)) ?? defaults.zoom)
        bestTimes = (try? container.decodeIfPresent(BestTimes.self, forKey: .bestTimes)) ?? defaults.bestTimes
        lastRecordName = (try? container.decodeIfPresent(String.self, forKey: .lastRecordName)) ?? defaults.lastRecordName
    }
}

public struct SettingsStore {
    public static let key = "settings.v1"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> Settings {
        guard let data = defaults.data(forKey: Self.key),
              let settings = try? JSONDecoder().decode(Settings.self, from: data)
        else { return Settings() }
        return settings
    }

    public func save(_ settings: Settings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
