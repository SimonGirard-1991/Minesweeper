import MinesweeperCore
import UIKit

@MainActor
enum TVDialogs {
    static let difficultyOrder: [Difficulty] = [.beginner, .intermediate, .expert, .custom]

    struct GameMenuActions {
        let newGame: () -> Void
        let selectDifficulty: (Difficulty) -> Void
        let toggleMarks: () -> Void
        let showBestTimes: () -> Void
    }

    static func gameMenu(settings: Settings, _ actions: GameMenuActions) -> UIAlertController {
        let menu = UIAlertController(title: "Game", message: nil, preferredStyle: .actionSheet)
        menu.addAction(UIAlertAction(title: "New", style: .default) { _ in actions.newGame() })
        for difficulty in difficultyOrder {
            let title = title(of: difficulty) + (difficulty == .custom ? "…" : "")
            let checked = difficulty == settings.difficulty ? "✓ " : ""
            menu.addAction(UIAlertAction(title: checked + title, style: .default) { _ in
                actions.selectDifficulty(difficulty)
            })
        }
        let marks = settings.marksEnabled ? "On" : "Off"
        menu.addAction(UIAlertAction(title: "Marks (?): \(marks)", style: .default) { _ in actions.toggleMarks() })
        menu.addAction(UIAlertAction(title: "Best Times…", style: .default) { _ in actions.showBestTimes() })
        menu.addAction(UIAlertAction(title: "Resume", style: .cancel))
        return menu
    }

    static func customField(current: FieldConfig, completion: @escaping (FieldConfig) -> Void) -> UIAlertController {
        let alert = UIAlertController(title: "Custom Field", message: nil, preferredStyle: .alert)
        let values = [("Height", current.height), ("Width", current.width), ("Mines", current.mines)]
        for (name, value) in values {
            alert.addTextField { field in
                field.placeholder = name
                field.text = String(value)
                field.keyboardType = .numberPad
            }
        }
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak alert] _ in
            let typed = zip(alert?.textFields ?? [], values).map { field, entry in Int(field.text ?? "") ?? entry.1 }
            guard typed.count == values.count else { return }
            completion(FieldConfig(width: typed[1], height: typed[0], mines: typed[2]))
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        return alert
    }

    static func recordName(
        for difficulty: Difficulty, suggested: String, completion: @escaping (String) -> Void
    ) -> UIAlertController {
        let alert = UIAlertController(
            title: "You have the fastest time for \(title(of: difficulty).lowercased()) level.",
            message: "Please type your name:", preferredStyle: .alert)
        alert.addTextField { field in
            field.text = suggested
            field.autocapitalizationType = .words
        }
        let submit = { [weak alert] in completion(alert?.textFields?.first?.text ?? suggested) }
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in submit() })
        // The Menu button dismisses through the cancel action, so cancelling still records, under the suggested name.
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completion(suggested) })
        return alert
    }

    static func bestTimes(_ times: BestTimes, onReset: @escaping () -> Void) -> UIAlertController {
        let rows = BestTimes.rankedDifficulties.map { difficulty in
            let best = times[difficulty]
            return "\(title(of: difficulty)):   \(best.seconds) seconds   \(best.name)"
        }
        let alert = UIAlertController(
            title: "Fastest Mine Sweepers", message: rows.joined(separator: "\n"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        alert.addAction(UIAlertAction(title: "Reset Scores", style: .destructive) { _ in onReset() })
        return alert
    }

    static func title(of difficulty: Difficulty) -> String {
        switch difficulty {
        case .beginner: "Beginner"
        case .intermediate: "Intermediate"
        case .expert: "Expert"
        case .custom: "Custom"
        }
    }
}
