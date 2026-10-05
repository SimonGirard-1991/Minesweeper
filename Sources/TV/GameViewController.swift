import MinesweeperCore
import UIKit

final class GameViewController: UIViewController {
    private static let desktop = UIColor(red: 0, green: 0.5, blue: 0.5, alpha: 1)
    private static let hintSpacing: CGFloat = 24
    private static let repeatDelay: TimeInterval = 0.4
    private static let repeatInterval: TimeInterval = 0.08

    private let store: SettingsStore
    private var settings: Settings
    private let gameView: TVGameView
    private let hint = UILabel()
    private var timer: Timer?
    private var arrowRepeat: Timer?
    private var isInBackground = false

    private var game: Game {
        didSet {
            gameView.game = game
            syncTimer()
        }
    }

    private var cursor: BoardCursor {
        didSet { gameView.cursor = cursor }
    }

    init(store: SettingsStore = SettingsStore()) {
        self.store = store
        settings = store.load()
        game = Game(config: settings.fieldConfig, marksEnabled: settings.marksEnabled)
        cursor = BoardCursor(settings.fieldConfig)
        gameView = TVGameView(game: game, cursor: cursor)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("GameViewController is built in code") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Self.desktop
        view.addSubview(gameView)

        hint.text = "Click: open  ·  Play/Pause: flag  ·  Menu: game options"
        hint.font = .preferredFont(forTextStyle: .callout)
        hint.textColor = .white
        hint.textAlignment = .center
        view.addSubview(hint)

        for direction: UISwipeGestureRecognizer.Direction in [.up, .down, .left, .right] {
            let swipe = UISwipeGestureRecognizer(target: self, action: #selector(swiped(_:)))
            swipe.direction = direction
            view.addGestureRecognizer(swipe)
        }

        registerForTraitChanges([UITraitDisplayScale.self]) { (controller: GameViewController, _: UITraitCollection) in
            controller.view.setNeedsLayout()
        }

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(sceneDidEnterBackground), name: UIScene.didEnterBackgroundNotification, object: nil)
        center.addObserver(self, selector: #selector(sceneWillEnterForeground), name: UIScene.willEnterForegroundNotification, object: nil)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let safe = view.bounds.inset(by: view.safeAreaInsets)
        let hintHeight = hint.intrinsicContentSize.height
        let layout = gameView.layout
        let zoom = BoardScale.fitting(
            width: layout.width, height: layout.height,
            in: CGSize(width: safe.width, height: safe.height - hintHeight - Self.hintSpacing),
            displayScale: traitCollection.displayScale)
        let size = CGSize(width: CGFloat(layout.width) * zoom, height: CGFloat(layout.height) * zoom)
        let top = safe.minY + (safe.height - size.height - hintHeight - Self.hintSpacing) / 2
        gameView.frame = CGRect(x: safe.midX - size.width / 2, y: top, width: size.width, height: size.height)
        hint.frame = CGRect(x: safe.minX, y: gameView.frame.maxY + Self.hintSpacing, width: safe.width, height: hintHeight)
    }

    // MARK: Siri Remote

    /// A presented alert passes the presses it ignores, such as Play/Pause, up to its presenter: this controller.
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard presentedViewController == nil else { return }
        var unhandled = Set<UIPress>()
        for press in presses {
            if let move = Self.move(for: press.type) {
                startMoving(move)
                continue
            }
            switch press.type {
            case .select: gameView.isPressing = cursor.canPress(in: game)
            case .playPause: if let cell = cursor.cell { apply { $0.cycleMark(cell) } }
            case .menu: showGameMenu()
            default: unhandled.insert(press)
            }
        }
        if !unhandled.isEmpty { super.pressesBegan(unhandled, with: event) }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if presses.contains(where: { Self.move(for: $0.type) != nil }) { stopMoving() }
        if presses.contains(where: { $0.type == .select }) { finishSelect() }
        let unhandled = presses.filter { !Self.handledTypes.contains($0.type) }
        if !unhandled.isEmpty { super.pressesEnded(unhandled, with: event) }
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if presses.contains(where: { Self.move(for: $0.type) != nil }) { stopMoving() }
        if presses.contains(where: { $0.type == .select }) { gameView.isPressing = false }
        let unhandled = presses.filter { !Self.handledTypes.contains($0.type) }
        if !unhandled.isEmpty { super.pressesCancelled(unhandled, with: event) }
    }

    /// Menu is kept from UIKit as well, which would otherwise send the app to the Home screen.
    private static let handledTypes: Set<UIPress.PressType> = [
        .upArrow, .downArrow, .leftArrow, .rightArrow, .select, .playPause, .menu,
    ]

    private static func move(for type: UIPress.PressType) -> CursorMove? {
        switch type {
        case .upArrow: .up
        case .downArrow: .down
        case .leftArrow: .left
        case .rightArrow: .right
        default: nil
        }
    }

    /// A held arrow fires one press, so the repeat is ours; crossing Expert would otherwise take 29 clicks.
    private func startMoving(_ move: CursorMove) {
        cursor.move(move)
        arrowRepeat?.invalidate()
        let timer = Timer(
            fire: Date(timeIntervalSinceNow: Self.repeatDelay), interval: Self.repeatInterval, repeats: true
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.presentedViewController == nil { self.cursor.move(move) } else { self.stopMoving() }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        arrowRepeat = timer
    }

    private func stopMoving() {
        arrowRepeat?.invalidate()
        arrowRepeat = nil
    }

    @objc private func swiped(_ swipe: UISwipeGestureRecognizer) {
        switch swipe.direction {
        case .up: cursor.move(.up)
        case .down: cursor.move(.down)
        case .left: cursor.move(.left)
        default: cursor.move(.right)
        }
    }

    private func finishSelect() {
        guard gameView.isPressing else { return }
        gameView.isPressing = false
        switch cursor.selectAction(in: game) {
        case .newGame: startNewGame()
        case .reveal(let cell): apply { $0.reveal(cell) }
        case .chord(let cell): apply { $0.chord(cell) }
        }
    }

    // MARK: Game menu

    private func showGameMenu() {
        gameView.isPressing = false
        stopMoving()
        let menu = TVDialogs.gameMenu(settings: settings, .init(
            newGame: { [weak self] in self?.startNewGame() },
            selectDifficulty: { [weak self] in self?.selectDifficulty($0) },
            toggleMarks: { [weak self] in self?.toggleMarks() },
            showBestTimes: { [weak self] in self?.showBestTimes() }))
        present(menu, animated: true)
    }

    private func selectDifficulty(_ difficulty: Difficulty) {
        guard difficulty == .custom else {
            apply(difficulty: difficulty)
            return
        }
        present(TVDialogs.customField(current: settings.fieldConfig) { [weak self] field in
            self?.settings.customField = field
            self?.apply(difficulty: .custom)
        }, animated: true)
    }

    private func apply(difficulty: Difficulty) {
        settings.difficulty = difficulty
        store.save(settings)
        startNewGame()
    }

    private func toggleMarks() {
        settings.marksEnabled.toggle()
        store.save(settings)
        game.marksEnabled = settings.marksEnabled
    }

    private func showBestTimes() {
        present(TVDialogs.bestTimes(settings.bestTimes) { [weak self] in
            guard let self else { return }
            settings.bestTimes.reset()
            store.save(settings)
            showBestTimes()
        }, animated: true)
    }

    // MARK: Game flow

    private func startNewGame() {
        let config = settings.fieldConfig
        game = Game(config: config, marksEnabled: settings.marksEnabled)
        if !cursor.fits(config) { cursor = BoardCursor(config) }
        view.setNeedsLayout()
    }

    private func apply(_ action: (inout Game) -> Void) {
        let wasWon = game.state == .won
        action(&game)
        guard !wasWon, game.state == .won else { return }
        let seconds = game.elapsedSeconds
        let difficulty = settings.difficulty
        guard settings.bestTimes.isRecord(seconds: seconds, for: difficulty) else { return }
        present(TVDialogs.recordName(for: difficulty, suggested: settings.lastRecordName) { [weak self] name in
            self?.recordBestTime(seconds: seconds, difficulty: difficulty, name: name)
        }, animated: true)
    }

    private func recordBestTime(seconds: Int, difficulty: Difficulty, name: String) {
        settings.bestTimes.record(seconds: seconds, name: name, for: difficulty)
        settings.lastRecordName = settings.bestTimes[difficulty].name
        store.save(settings)
        showBestTimes()
    }

    private func syncTimer() {
        guard game.state == .playing, !isInBackground else {
            timer?.invalidate()
            timer = nil
            return
        }
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.game.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    // XP paused the clock while the window was minimized; leaving the app is the TV's nearest equivalent.
    @objc private func sceneDidEnterBackground() {
        isInBackground = true
        syncTimer()
    }

    @objc private func sceneWillEnterForeground() {
        isInBackground = false
        syncTimer()
    }
}
