import AppKit
import MinesweeperCore

final class GameWindowController: NSWindowController, NSWindowDelegate, NSMenuItemValidation {
    private static let frameName = "MinesweeperWindow"

    private let store: SettingsStore
    private var settings: Settings
    private let gameView: GameView
    private var timer: Timer?

    private var game: Game {
        didSet {
            gameView.game = game
            syncTimer()
        }
    }

    init(store: SettingsStore = SettingsStore()) {
        self.store = store
        settings = store.load()
        game = Game(config: settings.fieldConfig, marksEnabled: settings.marksEnabled)
        gameView = GameView(game: game, zoom: settings.zoom)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: gameView.preferredSize),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered, defer: false)
        window.title = "Minesweeper"
        window.contentView = gameView
        super.init(window: window)

        window.delegate = self
        gameView.delegate = self
        let restored = window.setFrameUsingName(Self.frameName)
        window.setFrameAutosaveName(Self.frameName)
        fitWindowToBoard()
        if !restored { window.center() }
        window.makeFirstResponder(gameView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("GameWindowController is built in code") }

    // MARK: Menu actions

    @objc func newGame(_ sender: Any?) {
        startNewGame()
    }

    @objc func selectDifficulty(_ sender: NSMenuItem) {
        guard let difficulty = MainMenu.difficulty(for: sender) else { return }
        if difficulty == .custom {
            guard let field = Dialogs.customField(current: settings.fieldConfig) else { return }
            settings.customField = field
        }
        settings.difficulty = difficulty
        store.save(settings)
        startNewGame()
    }

    @objc func toggleMarks(_ sender: Any?) {
        settings.marksEnabled.toggle()
        store.save(settings)
        game.marksEnabled = settings.marksEnabled
    }

    @objc func showBestTimes(_ sender: Any?) {
        while Dialogs.bestTimes(settings.bestTimes) == .resetScores {
            settings.bestTimes.reset()
            store.save(settings)
        }
    }

    @objc func selectZoom(_ sender: NSMenuItem) {
        settings.zoom = sender.tag
        store.save(settings)
        gameView.zoom = settings.zoom
        fitWindowToBoard()
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(selectDifficulty(_:)):
            item.state = MainMenu.difficulty(for: item) == settings.difficulty ? .on : .off
        case #selector(toggleMarks(_:)):
            item.state = settings.marksEnabled ? .on : .off
        case #selector(selectZoom(_:)):
            item.state = item.tag == settings.zoom ? .on : .off
        default:
            break
        }
        return true
    }

    // MARK: Game flow

    private func startNewGame() {
        game = Game(config: settings.fieldConfig, marksEnabled: settings.marksEnabled)
        fitWindowToBoard()
    }

    private func apply(_ action: (inout Game) -> Void) {
        let wasWon = game.state == .won
        action(&game)
        guard !wasWon, game.state == .won else { return }
        let seconds = game.elapsedSeconds
        let difficulty = settings.difficulty
        guard settings.bestTimes.isRecord(seconds: seconds, for: difficulty) else { return }
        // Run the modal prompt after the mouse event that won, not nested inside GameView's mouseUp.
        Task { @MainActor [weak self] in self?.recordBestTime(seconds: seconds, difficulty: difficulty) }
    }

    private func recordBestTime(seconds: Int, difficulty: Difficulty) {
        let name = Dialogs.recordName(for: difficulty, suggested: settings.lastRecordName)
        settings.bestTimes.record(seconds: seconds, name: name, for: difficulty)
        settings.lastRecordName = settings.bestTimes[difficulty].name
        store.save(settings)
        showBestTimes(nil)
    }

    private func syncTimer() {
        guard game.state == .playing, window?.isMiniaturized != true else {
            timer?.invalidate()
            timer = nil
            return
        }
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.game.tick() }
        }
        // .common keeps the clock running while a menu, dialog or window drag is active.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Resizes the window around the board while keeping its top-left corner still and on screen.
    private func fitWindowToBoard() {
        guard let window else { return }
        let size = gameView.preferredSize
        var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: size))
        frame.origin = NSPoint(x: window.frame.minX, y: window.frame.maxY - frame.height)
        if let visible = (window.screen ?? NSScreen.main)?.visibleFrame {
            frame.origin.x = max(visible.minX, min(frame.origin.x, visible.maxX - frame.width))
            // Clamping the top last keeps the title bar reachable when the window is taller than the screen.
            frame.origin.y = min(max(frame.origin.y, visible.minY), visible.maxY - frame.height)
        }
        window.setFrame(frame, display: true)
    }

    func windowWillClose(_ notification: Notification) {
        timer?.invalidate()
    }

    // XP paused the clock while the window was minimized.
    func windowDidMiniaturize(_ notification: Notification) { syncTimer() }

    func windowDidDeminiaturize(_ notification: Notification) { syncTimer() }
}

extension GameWindowController: GameViewDelegate {
    func gameView(_ view: GameView, revealAt cell: Coord) {
        apply { $0.reveal(cell) }
    }

    func gameView(_ view: GameView, chordAt cell: Coord) {
        apply { $0.chord(cell) }
    }

    func gameView(_ view: GameView, cycleMarkAt cell: Coord) {
        apply { $0.cycleMark(cell) }
    }

    func gameViewRequestsNewGame(_ view: GameView) {
        startNewGame()
    }
}
