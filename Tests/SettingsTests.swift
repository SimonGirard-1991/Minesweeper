import Foundation
import MinesweeperCore
import Testing

struct FieldConfigTests {
    @Test func presetsMatchWindowsXP() {
        // Act + Assert
        #expect(FieldConfig.preset(.beginner) == FieldConfig(width: 9, height: 9, mines: 10))
        #expect(FieldConfig.preset(.intermediate) == FieldConfig(width: 16, height: 16, mines: 40))
        #expect(FieldConfig.preset(.expert) == FieldConfig(width: 30, height: 16, mines: 99))
        #expect(FieldConfig.preset(.custom) == nil)
    }

    @Test(arguments: [
        ((5, 5, 1), (9, 9, 10)),
        ((50, 50, 9999), (30, 24, 667)),
        ((12, 10, 200), (12, 10, 99)),
        ((20, 15, 50), (20, 15, 50)),
    ])
    func customFieldClampsLikeXP(input: (Int, Int, Int), expected: (Int, Int, Int)) {
        // Act
        let config = FieldConfig(width: input.0, height: input.1, mines: input.2)

        // Assert
        #expect(config.width == expected.0)
        #expect(config.height == expected.1)
        #expect(config.mines == expected.2)
    }
}

struct BestTimesTests {
    @Test func startsAt999Anonymous() {
        // Act
        let sut = BestTimes()

        // Assert
        #expect(sut[.expert] == BestTime(seconds: 999, name: "Anonymous"))
    }

    @Test func recordsOnlyStrictlyFasterTimesOnRankedLevels() {
        // Arrange
        var sut = BestTimes()
        sut.record(seconds: 42, name: "Ada", for: .beginner)

        // Act
        sut.record(seconds: 42, name: "Bob", for: .beginner)
        sut.record(seconds: 10, name: "Cy", for: .custom)

        // Assert
        #expect(sut[.beginner] == BestTime(seconds: 42, name: "Ada"))
        #expect(!sut.isRecord(seconds: 1, for: .custom))
        #expect(sut.isRecord(seconds: 41, for: .beginner))
    }

    @Test func blankNamesBecomeAnonymousAndLongOnesAreCut() {
        // Act
        let blank = BestTime(seconds: 5, name: "   ")
        let long = BestTime(seconds: 5, name: String(repeating: "x", count: 50))

        // Assert
        #expect(blank.name == "Anonymous")
        #expect(long.name.count == BestTime.maxNameLength)
    }

    @Test func decodingCleansStoredRecordsAndSkipsUnknownLevels() throws {
        // Arrange
        let json = #"{"times": {"beginner": {"seconds": -5, "name": "   "}, "legend": {"seconds": 3, "name": "Zed"}, "expert": {"seconds": 88, "name": "Ada"}}}"#

        // Act
        let sut = try JSONDecoder().decode(BestTimes.self, from: Data(json.utf8))

        // Assert
        #expect(sut[.beginner] == BestTime(seconds: 1, name: "Anonymous"))
        #expect(sut[.expert] == BestTime(seconds: 88, name: "Ada"))
    }

    @Test func resetForgetsEveryRecord() {
        // Arrange
        var sut = BestTimes()
        sut.record(seconds: 30, name: "Ada", for: .expert)

        // Act
        sut.reset()

        // Assert
        #expect(sut == BestTimes())
    }
}

struct SettingsStoreTests {
    private func withStore(_ body: (SettingsStore, UserDefaults) throws -> Void) rethrows {
        let suite = "minesweeper.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(SettingsStore(defaults: defaults), defaults)
    }

    @Test func roundTripsEverySetting() {
        withStore { sut, _ in
            // Arrange
            var settings = Settings()
            settings.difficulty = .custom
            settings.customField = FieldConfig(width: 20, height: 12, mines: 33)
            settings.marksEnabled = false
            settings.zoom = 2
            settings.bestTimes.record(seconds: 77, name: "Ada", for: .intermediate)
            settings.lastRecordName = "Ada"

            // Act
            sut.save(settings)
            let loaded = sut.load()

            // Assert
            #expect(loaded == settings)
            #expect(loaded.fieldConfig == FieldConfig(width: 20, height: 12, mines: 33))
        }
    }

    @Test func missingOrCorruptDataFallsBackToDefaults() {
        withStore { sut, defaults in
            // Arrange
            let empty = sut.load()
            defaults.set(Data("not json".utf8), forKey: SettingsStore.key)

            // Act
            let corrupt = sut.load()

            // Assert
            #expect(empty == Settings())
            #expect(corrupt == Settings())
        }
    }

    @Test func unknownAndMissingKeysKeepTheRest() {
        withStore { sut, defaults in
            // Arrange
            let json = #"{"zoom": 7, "future": true, "bestTimes": {"times": {"expert": {"seconds": 120, "name": "Ada"}}}}"#
            defaults.set(Data(json.utf8), forKey: SettingsStore.key)

            // Act
            let loaded = sut.load()

            // Assert
            #expect(loaded.zoom == 2)
            #expect(loaded.marksEnabled)
            #expect(loaded.bestTimes[.expert] == BestTime(seconds: 120, name: "Ada"))
        }
    }
}
