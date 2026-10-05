import AppKit
import MinesweeperCore

@MainActor
enum Dialogs {
    enum BestTimesChoice {
        case ok, resetScores
    }

    static func customField(current: FieldConfig) -> FieldConfig? {
        let height = numberField(current.height)
        let width = numberField(current.width)
        let mines = numberField(current.mines)
        let grid = NSGridView(views: [
            [label("Height:"), height],
            [label("Width:"), width],
            [label("Mines:"), mines],
        ])
        grid.rowSpacing = 8
        grid.column(at: 0).xPlacement = .trailing
        grid.frame.size = grid.fittingSize

        let alert = NSAlert()
        alert.messageText = "Custom Field"
        alert.accessoryView = grid
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = height
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return FieldConfig(width: width.integerValue, height: height.integerValue, mines: mines.integerValue)
    }

    static func recordName(for difficulty: Difficulty, suggested: String) -> String {
        let name = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        name.stringValue = suggested

        let alert = NSAlert()
        alert.messageText = "You have the fastest time for \(title(of: difficulty).lowercased()) level."
        alert.informativeText = "Please type your name:"
        alert.accessoryView = name
        alert.addButton(withTitle: "OK")
        alert.window.initialFirstResponder = name
        alert.runModal()
        return name.stringValue
    }

    static func bestTimes(_ times: BestTimes) -> BestTimesChoice {
        let rows = BestTimes.rankedDifficulties.map { difficulty -> [NSView] in
            let best = times[difficulty]
            return [label("\(title(of: difficulty)):"), label("\(best.seconds) seconds"), label(best.name)]
        }
        let grid = NSGridView(views: rows)
        grid.rowSpacing = 6
        grid.columnSpacing = 16
        grid.frame.size = grid.fittingSize

        let alert = NSAlert()
        alert.messageText = "Fastest Mine Sweepers"
        alert.accessoryView = grid
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Reset Scores")
        return alert.runModal() == .alertSecondButtonReturn ? .resetScores : .ok
    }

    static func title(of difficulty: Difficulty) -> String {
        switch difficulty {
        case .beginner: "Beginner"
        case .intermediate: "Intermediate"
        case .expert: "Expert"
        case .custom: "Custom"
        }
    }

    private static func label(_ text: String) -> NSTextField {
        NSTextField(labelWithString: text)
    }

    private static func numberField(_ value: Int) -> NSTextField {
        let field = NSTextField(string: String(value))
        field.alignment = .right
        field.widthAnchor.constraint(equalToConstant: 60).isActive = true
        return field
    }
}
