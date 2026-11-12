import Raylib

/// A game's windows: their stacking order, which one is in front, which are minimized, and which
/// get each frame's input.
///
/// The manager holds `WindowFrame`s made with a view, from back to front. Each frame:
///
/// - A press brings the window under it to the front.
/// - Only the window in front takes input: clicks, the wheel, and keys. The windows behind it wait,
///   so overlapping windows never both react to one click.
/// - Modal windows stay above every other window, the newest on top, and the top one takes all
///   input while any is open. `hasModal` tells the host to pause the game and leave the map alone.
/// - Minimized windows stay open, but aren't drawn and take no input. The host shows them however it
///   likes, such as a dock or a row of icons, from `minimizedWindows`.
///
/// Close and minimize are requests, as everywhere in Hudini: a window's `.closeRequested` and
/// `.minimizeRequested` reach the host, which calls `close(_:)` or `minimize(_:)` if it agrees.
///
/// Each window can carry its own handler, so its logic lives with it rather than in one big switch,
/// and two hosts, such as a game and its editor, can open the same window with different handlers.
/// `update()` also returns every event, labelled with its window, for a host that prefers one switch.
///
/// HUD panels that never stack, such as a control panel along the screen's edge, stay outside the
/// manager: draw them first, and use `contains(_:)` with their own check to keep clicks off the game.
public final class WindowManager {
    /// Something one of the windows reported.
    public struct Event: Equatable {
        /// The window that reported it.
        public let window: WindowFrame

        /// What it reported.
        public let event: WindowFrame.Event

        public static func == (lhs: Event, rhs: Event) -> Bool {
            lhs.window === rhs.window && lhs.event == rhs.event
        }
    }

    /// Handles one window's events, in the order they happen.
    public typealias Handler = (WindowFrame.Event) -> Void

    private struct Entry {
        let frame: WindowFrame
        let start: Vector2
        let isModal: Bool
        let dimsBehind: Bool
        var isMinimized: Bool
        let handler: Handler?
    }

    // How far each new window sits from the last, so they don't open exactly on top of each other.
    private static let cascade: Float = 24

    // Back to front, with every modal window after every other window.
    private var entries: [Entry] = []

    private var openedCount = 0

    /// Creates a manager with no windows.
    public init() {}

    /// The open windows from back to front, minimized ones included.
    public var windows: [WindowFrame] {
        entries.map(\.frame)
    }

    /// The minimized windows, in the order they were opened.
    public var minimizedWindows: [WindowFrame] {
        entries.filter(\.isMinimized).map(\.frame)
    }

    /// The window in front, which takes the input, or `nil` when none is showing.
    public var frontWindow: WindowFrame? {
        entries.last { !$0.isMinimized }?.frame
    }

    /// Whether a modal window is open. Pause the game and ignore the map while it is.
    public var hasModal: Bool {
        entries.contains { $0.isModal }
    }

    /// Returns whether `window` is open, minimized or not.
    public func isOpen(_ window: WindowFrame) -> Bool {
        index(of: window) != nil
    }

    /// Returns whether `window` is open and minimized.
    public func isMinimized(_ window: WindowFrame) -> Bool {
        index(of: window).map { entries[$0].isMinimized } ?? false
    }

    /// Opens a window in front, or brings an open one to the front, restored if it was minimized.
    ///
    /// - Parameters:
    ///   - window: A frame made with `WindowFrame(view:)`.
    ///   - start: Where its corner goes the first time. Without one, it opens centered on the
    ///     screen, a little down and right of the last window opened.
    ///   - modal: Whether it stays above every other window and takes all input while open. A
    ///     modal window can't be minimized.
    ///   - dimsBehind: Whether a modal window dims everything drawn before it with the theme's
    ///     `overlay`.
    ///   - handler: Receives the window's events during `update()`.
    public func open(
        _ window: WindowFrame,
        at start: Vector2? = nil,
        modal: Bool = false,
        dimsBehind: Bool = false,
        handler: Handler? = nil
    ) {
        precondition(window.view != nil, "A WindowManager needs frames made with WindowFrame(view:)")
        if index(of: window) != nil {
            restore(window)
            return
        }
        let oldFront = frontWindow
        let entry = Entry(
            frame: window,
            start: start ?? cascadedStart(for: window),
            isModal: modal,
            dimsBehind: modal && dimsBehind,
            isMinimized: false,
            handler: handler
        )
        openedCount += 1
        if modal {
            entries.append(entry)
        } else {
            entries.insert(entry, at: entries.firstIndex { $0.isModal } ?? entries.endIndex)
        }
        unfocusIfBehind(oldFront)
    }

    /// Closes a window, dropping its title edit and keyboard focus.
    ///
    /// - Returns: Whether it was open.
    @discardableResult
    public func close(_ window: WindowFrame) -> Bool {
        guard let index = index(of: window) else {
            return false
        }
        Self.unfocus(window)
        entries.remove(at: index)
        return true
    }

    /// Minimizes a window, which stays open but isn't drawn and takes no input.
    ///
    /// - Returns: Whether it was open, showing, and not modal.
    @discardableResult
    public func minimize(_ window: WindowFrame) -> Bool {
        guard let index = index(of: window), !entries[index].isMinimized, !entries[index].isModal else {
            return false
        }
        Self.unfocus(window)
        entries[index].isMinimized = true
        return true
    }

    /// Shows a minimized window again, and brings it to the front.
    public func restore(_ window: WindowFrame) {
        guard let index = index(of: window) else {
            return
        }
        entries[index].isMinimized = false
        bringToFront(window)
    }

    /// Brings an open window to the front of its group. A window that isn't modal stays below any
    /// modal one.
    public func bringToFront(_ window: WindowFrame) {
        guard let index = index(of: window), frontWindow !== window else {
            return
        }
        let oldFront = frontWindow
        let entry = entries.remove(at: index)
        entries.insert(entry, at: entry.isModal ? entries.endIndex : entries.firstIndex { $0.isModal } ?? entries.endIndex)
        unfocusIfBehind(oldFront)
    }

    /// Returns where a window is on the screen, or `nil` when it isn't open.
    public func bounds(of window: WindowFrame) -> Rectangle? {
        index(of: window).map { window.place(at: entries[$0].start) }
    }

    /// Returns the frontmost showing window under `point`, or `nil`.
    public func window(at point: Vector2) -> WindowFrame? {
        entries.last { entry in
            !entry.isMinimized && CheckCollisionPointRec(point, entry.frame.place(at: entry.start))
        }?.frame
    }

    /// Returns whether `point` is over a showing window. While `hasModal` is true, the game behind
    /// should ignore the pointer wherever it is.
    public func contains(_ point: Vector2) -> Bool {
        window(at: point) != nil
    }

    /// Handles this frame's input: brings a pressed window to the front, unless a modal window is
    /// open, then updates the window in front. Each event goes to its window's handler, and all of
    /// them are returned in order.
    @discardableResult
    public func update() -> [Event] {
        if IsMouseButtonPressed(MouseButton.left) {
            focusWindow(at: GetMousePosition())
        }
        guard let front = frontWindow, let bounds = bounds(of: front) else {
            return []
        }
        return deliver(front.updateWindow(in: bounds), from: front)
    }

    /// Hands a window's events to its handler, and labels them with the window.
    func deliver(_ events: [WindowFrame.Event], from window: WindowFrame) -> [Event] {
        let handler = index(of: window).flatMap { entries[$0].handler }
        for event in events {
            handler?(event)
        }
        return events.map { Event(window: window, event: $0) }
    }

    /// Brings the window under a press at `point` to the front, unless a modal window holds the
    /// input.
    func focusWindow(at point: Vector2) {
        guard !hasModal, let target = window(at: point) else {
            return
        }
        bringToFront(target)
    }

    /// Draws the showing windows from back to front. A modal window that dims what's behind it draws
    /// its theme's `overlay` over the whole screen first.
    public func draw() {
        for entry in entries where !entry.isMinimized {
            if entry.dimsBehind {
                DrawRectangle(0, 0, GetScreenWidth(), GetScreenHeight(), entry.frame.theme.overlay)
            }
            entry.frame.draw(in: entry.frame.place(at: entry.start))
        }
    }

    /// Draws the tooltip of the front window's control the pointer rests on. Call this after
    /// everything else, so nothing covers it.
    public func drawTooltip() {
        guard let front = frontWindow, let bounds = bounds(of: front) else {
            return
        }
        front.drawTooltip(in: bounds)
    }

    private func index(of window: WindowFrame) -> Int? {
        entries.firstIndex { $0.frame === window }
    }

    private func cascadedStart(for window: WindowFrame) -> Vector2 {
        let size = window.place(at: .zero)
        let offset = Self.cascade * Float(openedCount % 6)
        return Vector2(
            x: max(0, ((Float(GetScreenWidth()) - size.width) / 2) + offset),
            y: max(0, ((Float(GetScreenHeight()) - size.height) / 2) + offset - Self.cascade)
        )
    }

    // The window that was in front gives up the keyboard if another one has taken its place.
    private func unfocusIfBehind(_ oldFront: WindowFrame?) {
        if let oldFront, frontWindow !== oldFront {
            Self.unfocus(oldFront)
        }
    }

    // A window leaving the front gives up the keyboard and its title edit.
    private static func unfocus(_ window: WindowFrame) {
        window.cancelEdit()
        window.view?.clearFocus()
    }
}
