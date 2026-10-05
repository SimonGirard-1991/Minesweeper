import AppKit
import MinesweeperCore

@MainActor
enum MainMenu {
    private static let difficultyOrder: [Difficulty] = [.beginner, .intermediate, .expert, .custom]

    static func difficulty(for item: NSMenuItem) -> Difficulty? {
        difficultyOrder.indices.contains(item.tag) ? difficultyOrder[item.tag] : nil
    }

    static func build() -> NSMenu {
        let main = NSMenu()
        main.addItem(submenu(appMenu()))
        main.addItem(submenu(gameMenu()))
        main.addItem(submenu(viewMenu()))
        let window = windowMenu()
        main.addItem(submenu(window))
        NSApp.windowsMenu = window
        return main
    }

    private static func appMenu() -> NSMenu {
        let menu = NSMenu(title: "Minesweeper")
        menu.addItem(item("About Minesweeper", #selector(NSApplication.orderFrontStandardAboutPanel(_:))))
        menu.addItem(.separator())
        menu.addItem(item("Hide Minesweeper", #selector(NSApplication.hide(_:)), key: "h"))
        menu.addItem(item("Hide Others", #selector(NSApplication.hideOtherApplications(_:)), key: "h", modifiers: [.command, .option]))
        menu.addItem(item("Show All", #selector(NSApplication.unhideAllApplications(_:))))
        menu.addItem(.separator())
        menu.addItem(item("Quit Minesweeper", #selector(NSApplication.terminate(_:)), key: "q"))
        return menu
    }

    private static func gameMenu() -> NSMenu {
        let menu = NSMenu(title: "Game")
        let f2 = String(utf16CodeUnits: [unichar(NSF2FunctionKey)], count: 1)
        menu.addItem(item("New", #selector(GameWindowController.newGame(_:)), key: f2, modifiers: []))
        let commandN = item("New", #selector(GameWindowController.newGame(_:)), key: "n")
        commandN.isHidden = true
        commandN.allowsKeyEquivalentWhenHidden = true
        menu.addItem(commandN)
        menu.addItem(.separator())
        for (tag, difficulty) in difficultyOrder.enumerated() {
            let title = Dialogs.title(of: difficulty) + (difficulty == .custom ? "…" : "")
            let entry = item(title, #selector(GameWindowController.selectDifficulty(_:)))
            entry.tag = tag
            menu.addItem(entry)
        }
        menu.addItem(.separator())
        menu.addItem(item("Marks (?)", #selector(GameWindowController.toggleMarks(_:))))
        menu.addItem(.separator())
        menu.addItem(item("Best Times…", #selector(GameWindowController.showBestTimes(_:))))
        return menu
    }

    private static func viewMenu() -> NSMenu {
        let menu = NSMenu(title: "View")
        for zoom in Settings.zoomLevels {
            let entry = item("Zoom \(zoom)×", #selector(GameWindowController.selectZoom(_:)), key: String(zoom))
            entry.tag = zoom
            menu.addItem(entry)
        }
        return menu
    }

    private static func windowMenu() -> NSMenu {
        let menu = NSMenu(title: "Window")
        menu.addItem(item("Minimize", #selector(NSWindow.performMiniaturize(_:)), key: "m"))
        return menu
    }

    private static func submenu(_ menu: NSMenu) -> NSMenuItem {
        let holder = NSMenuItem(title: menu.title, action: nil, keyEquivalent: "")
        holder.submenu = menu
        return holder
    }

    private static func item(
        _ title: String, _ action: Selector, key: String = "", modifiers: NSEvent.ModifierFlags = .command
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        return item
    }
}
