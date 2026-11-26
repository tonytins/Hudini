import Raylib

/// Displays host-provided plain-text items in a clipped, scrollable viewport.
///
/// By default the list works as a log: it opens on its newest items and stays at the end as
/// items arrive. A selectable list works as a pick list: it opens on its first items, stays where
/// it is when items change, and a click selects an item.
///
/// Once its lines don't all fit, the list draws a classic scroll bar down its right edge, taking
/// 15 pixels from its text: arrows scroll a line, the track a page, and the thumb drags.
public final class TextList {
    private static let padding: Int = 6
    private static let lineGap: Int = 2
    private static let linesPerWheelNotch: Float = 3
    private static let minimumThumbHeight: Float = 6

    /// The most seconds between two clicks on the same item that count as a double-click.
    public static let doubleClickInterval: Double = 0.5

    private var lines: [String] = []
    // The index of the item each line came from.
    private var lineItems: [Int] = []
    private var lineWidth: Int?
    // The visible line count `lines` was wrapped for, since that decides whether the bar shows.
    private var wrappedVisibleLineCount: Int?
    private var visibleLineCount = 1
    private var scrollBar = ScrollBar()
    // Whether the lines overflowed, so they were wrapped short of the scroll bar.
    private var showsScrollBar = false

    /// Whether the list draws its own scroll bar when its lines overflow. A document's list that a
    /// slider or scroll buttons already move has none, so it never shows two.
    var hasScrollBar = true {
        didSet {
            lineWidth = nil
        }
    }
    private var pendingWheelLines: Float = 0
    // The item the last click landed on, and when, so a second one can make a double-click.
    private var lastClick: (index: Int, time: Double)?

    /// The colors and size the list draws with. Setting it takes effect from the next draw, and keeps
    /// the list's items, selection, and scroll position. Colors and a size passed when creating the
    /// list still win.
    public var theme: InterfaceTheme {
        didSet {
            lineWidth = nil
        }
    }

    // What the caller asked for. Anything left out comes from the theme when drawing.
    private var fontSizeOverride: Int?
    private var textColorOverride: Color?
    private var backgroundColorOverride: Color?
    private var borderColorOverride: Color?

    var fontSize: Int {
        fontSizeOverride ?? theme.textSizes.body
    }

    var textColor: Color {
        textColorOverride ?? theme.text
    }

    var backgroundColor: Color {
        backgroundColorOverride ?? theme.panel
    }

    var borderColor: Color {
        borderColorOverride ?? theme.border
    }

    /// Replaces the colors and size the document's style gave this control, after its view resolved
    /// them against a new theme.
    func applyStyle(fontSize: Int?, textColor: Color?, backgroundColor: Color?, borderColor: Color?) {
        fontSizeOverride = fontSize
        textColorOverride = textColor
        backgroundColorOverride = backgroundColor
        borderColorOverride = borderColor
        lineWidth = nil
    }

    /// The plain-text items supplied by the host.
    public var items: [String] {
        didSet {
            lineWidth = nil
            if let selectedIndex, selectedIndex >= items.count {
                self.selectedIndex = nil
            }
        }
    }

    /// Whether clicking an item selects it.
    public let isSelectable: Bool

    /// The selected item, or `nil` when none is. It is always `nil` on a list that is not
    /// selectable, and an index outside `items` clears it.
    ///
    /// The list tracks a position, not an item, so a host that reorders `items` sets this again.
    public var selectedIndex: Int? {
        didSet {
            if let selectedIndex, !isSelectable || !items.indices.contains(selectedIndex) {
                self.selectedIndex = nil
            }
        }
    }

    /// An event produced by this list.
    public enum Event: Equatable, Sendable {
        /// A click changed the selected item to the one at this index.
        case selected(Int)

        /// The item at this index was double-clicked. The first click selected it.
        case submitted(Int)
    }

    /// How many lines the viewport is scrolled back from the newest content.
    ///
    /// The value is clamped to the available content during update and drawing.
    public private(set) var scrollOffset = 0

    /// The current scrollbar position, where zero is the oldest content and one
    /// is the newest content.
    public var scrollFraction: Float {
        let maximumOffset = max(0, lines.count - visibleLineCount)
        guard maximumOffset > 0 else {
            return 1
        }
        return 1 - (Float(scrollOffset) / Float(maximumOffset))
    }

    /// The fraction of the full scroll range visible in the viewport.
    public var scrollThumbFraction: Float {
        guard !lines.isEmpty else {
            return 1
        }
        return min(1, Float(visibleLineCount) / Float(lines.count))
    }

    /// Returns the scrollbar thumb's bounds inside `track`.
    ///
    /// The thumb sits at the bottom of the track while the newest content is
    /// showing. Call this after `update(in:)` or `draw(in:)` so it reflects the
    /// current items.
    public func scrollThumbBounds(in track: Rectangle) -> Rectangle {
        let innerHeight = max(0, track.height - 2)
        let thumbHeight = min(innerHeight, max(Self.minimumThumbHeight, innerHeight * scrollThumbFraction))
        return Rectangle(
            x: track.x + 1,
            y: track.y + 1 + ((innerHeight - thumbHeight) * scrollFraction),
            width: max(0, track.width - 2),
            height: thumbHeight
        )
    }

    /// Creates a text list using the host's ordered items. Without a `fontSize`, it uses the
    /// theme's `body` size.
    public init(
        items: [String] = [],
        fontSize: Int? = nil,
        theme: InterfaceTheme = .standard,
        textColor: Color? = nil,
        backgroundColor: Color? = nil,
        borderColor: Color? = nil,
        isSelectable: Bool = false
    ) {
        precondition(fontSize.map { $0 > 0 } ?? true, "fontSize must be positive")
        self.items = items
        fontSizeOverride = fontSize
        self.theme = theme
        textColorOverride = textColor
        backgroundColorOverride = backgroundColor
        borderColorOverride = borderColor
        self.isSelectable = isSelectable
    }

    /// Updates the scroll bar, wheel, and arrow-button scrolling for this frame, and selection on a
    /// selectable list.
    ///
    /// A press on the scroll bar, and the pointer until it's let go, belong to the bar, so they
    /// never select an item. Positive values passed to `scroll(byLines:)` move toward older
    /// content. Returns an event when a click selects a different item, or when a second click on
    /// the same item within `doubleClickInterval` makes a double-click.
    @discardableResult
    public func update(
        in bounds: Rectangle,
        scrollUpButton: Rectangle? = nil,
        scrollDownButton: Rectangle? = nil
    ) -> Event? {
        prepareLines(for: bounds)
        let mouse = GetMousePosition()
        let tookPointer = updateScrollBar(
            in: bounds,
            pointer: mouse,
            isPressed: IsMouseButtonPressed(MouseButton.left),
            isDown: IsMouseButtonDown(MouseButton.left),
            time: GetTime()
        )
        guard !tookPointer else {
            return nil
        }
        guard IsMouseButtonPressed(MouseButton.left) else {
            guard CheckCollisionPointRec(mouse, bounds) else {
                return nil
            }
            scroll(byWheelMovement: GetMouseWheelMove())
            if IsKeyPressed(KeyboardKey.pageUp) {
                scroll(byLines: visibleLineCount)
            } else if IsKeyPressed(KeyboardKey.pageDown) {
                scroll(byLines: -visibleLineCount)
            }
            return nil
        }

        if let scrollUpButton, CheckCollisionPointRec(mouse, scrollUpButton) {
            scroll(byLines: 1)
        } else if let scrollDownButton, CheckCollisionPointRec(mouse, scrollDownButton) {
            scroll(byLines: -1)
        } else {
            return select(at: mouse, in: bounds, time: GetTime())
        }
        return nil
    }

    // MARK: Scroll bar

    private var scrollBarPosition: ScrollBar.Position {
        ScrollBar.Position(
            first: firstVisibleLine,
            last: showsScrollBar ? max(0, lines.count - visibleLineCount) : 0,
            shown: visibleLineCount
        )
    }

    /// The scroll bar's parts at `bounds`, or `nil` when the list has no bar showing.
    func scrollBarGeometry(in bounds: Rectangle) -> ScrollBar.Geometry? {
        prepareLines(for: bounds)
        return ScrollBar.geometry(in: bounds, position: scrollBarPosition)
    }

    /// Whether `point` is on the scroll bar the list shows at `bounds`.
    func scrollBarContains(_ point: Vector2, in bounds: Rectangle) -> Bool {
        scrollBarGeometry(in: bounds).map { CheckCollisionPointRec(point, $0.bar) } ?? false
    }

    /// Applies one frame of the pointer to the scroll bar, and reports whether the pointer is the
    /// bar's this frame.
    func updateScrollBar(in bounds: Rectangle, pointer: Vector2, isPressed: Bool, isDown: Bool, time: Double) -> Bool {
        prepareLines(for: bounds)
        let result = scrollBar.update(
            pointer: pointer,
            isPressed: isPressed,
            isDown: isDown,
            time: time,
            in: bounds,
            position: scrollBarPosition
        )
        if let first = result.first {
            scrollOffset = max(0, lines.count - visibleLineCount) - first
        }
        return result.tookPointer
    }

    /// Returns the index of the item drawn at `point`, or `nil` when no item is there. An item
    /// that wraps covers all of its lines. This works whether or not the list is selectable.
    public func itemIndex(at point: Vector2, in bounds: Rectangle) -> Int? {
        prepareLines(for: bounds)
        let distance = point.y - bounds.y - Float(Self.padding)
        guard CheckCollisionPointRec(point, bounds), distance >= 0, !scrollBarContains(point, in: bounds) else {
            return nil
        }
        let row = Int(clamping: distance) / lineHeight
        let line = firstVisibleLine + row
        guard row < visibleLineCount, line < lines.count else {
            return nil
        }
        return lineItems[line]
    }

    /// Selects the item at `point` for a click at `time`, in seconds. Reports a change to the
    /// selection, or a double-click when the last click landed on the same item close enough before.
    func select(at point: Vector2, in bounds: Rectangle, time: Double) -> Event? {
        guard isSelectable, let index = itemIndex(at: point, in: bounds) else {
            lastClick = nil
            return nil
        }
        if let lastClick, lastClick.index == index, time - lastClick.time <= Self.doubleClickInterval {
            // A third click starts over rather than making a second double-click.
            self.lastClick = nil
            return .submitted(index)
        }
        lastClick = (index, time)
        guard index != selectedIndex else {
            return nil
        }
        selectedIndex = index
        return .selected(index)
    }

    /// Moves through the list. Positive values reveal older content.
    public func scroll(byLines lineCount: Int) {
        let maximumOffset = max(0, lines.count - visibleLineCount)
        scrollOffset = min(max(scrollOffset + lineCount, 0), maximumOffset)
    }

    /// Moves to a scrollbar position, where zero is the oldest content and one is the newest.
    public func scroll(toFraction fraction: Float) {
        guard fraction.isFinite else {
            return
        }
        let maximumOffset = max(0, lines.count - visibleLineCount)
        scrollOffset = Int((1 - min(max(fraction, 0), 1)) * Float(maximumOffset) + 0.5)
    }

    /// Moves through the list by a mouse wheel reading. Positive values reveal older content.
    ///
    /// Partial lines carry over to later calls, so the small steps a trackpad
    /// reports still add up to movement.
    public func scroll(byWheelMovement movement: Float) {
        guard movement.isFinite else {
            return
        }
        pendingWheelLines += movement * Self.linesPerWheelNotch
        let lineCount = Int(clamping: pendingWheelLines)
        pendingWheelLines -= Float(lineCount)
        if lineCount != 0 {
            scroll(byLines: lineCount)
        }
    }

    /// Draws the list background, border, visible text, and its scroll bar when the text overflows.
    public func draw(in bounds: Rectangle) {
        prepareLines(for: bounds)

        theme.fillRectangle(bounds, backgroundColor)
        theme.outlineRectangle(bounds, borderColor)

        let firstLine = firstVisibleLine
        let endLine = min(lines.count, firstLine + visibleLineCount)
        let textBounds = Rectangle(
            x: bounds.x + 1,
            y: bounds.y + 1,
            width: max(0, bounds.width - 2 - (showsScrollBar ? ScrollBar.width : 0)),
            height: max(0, bounds.height - 2)
        )
        BeginScissorMode(
            Int(clamping: textBounds.x),
            Int(clamping: textBounds.y),
            Int(clamping: textBounds.width),
            Int(clamping: textBounds.height)
        )
        for index in firstLine..<endLine {
            let y = Int(clamping: bounds.y) + Self.padding + ((index - firstLine) * lineHeight)
            if lineItems[index] == selectedIndex {
                DrawRectangle(Int(clamping: textBounds.x), y, Int(clamping: textBounds.width), lineHeight, theme.selectedItem)
            }
            theme.drawText(lines[index], x: Int(clamping: bounds.x) + Self.padding, y: y, size: fontSize, color: textColor)
        }
        EndScissorMode()
        if let geometry = ScrollBar.geometry(in: bounds, position: scrollBarPosition) {
            ScrollBar.draw(geometry, theme: theme)
        }
    }

    private var lineHeight: Int {
        fontSize + Self.lineGap
    }

    private var firstVisibleLine: Int {
        max(0, lines.count - visibleLineCount) - scrollOffset
    }

    func prepareLines(for bounds: Rectangle) {
        let previousFirstLine = firstVisibleLine
        let width = max(1, Int(clamping: bounds.width) - (Self.padding * 2) - 2)
        visibleLineCount = max(
            1,
            (Int(clamping: bounds.height) - (Self.padding * 2) + Self.lineGap) / lineHeight
        )
        if lineWidth != width || wrappedVisibleLineCount != visibleLineCount {
            wrap(to: width)
            // The bar takes room only once the lines overflow, and wrapping short of it can only
            // add lines, so it still shows afterward.
            showsScrollBar = hasScrollBar && lines.count > visibleLineCount
            if showsScrollBar {
                wrap(to: max(1, width - Int(ScrollBar.width)))
            }
            lineWidth = width
            wrappedVisibleLineCount = visibleLineCount
        }
        // scrollOffset counts from the end, so a pick list works out again what keeps its top line.
        let maximumOffset = max(0, lines.count - visibleLineCount)
        scrollOffset = isSelectable ? max(0, maximumOffset - previousFirstLine) : min(scrollOffset, maximumOffset)
    }

    private func wrap(to width: Int) {
        lines = []
        lineItems = []
        for (index, item) in items.enumerated() {
            let itemLines = item
                .split(separator: "\n", omittingEmptySubsequences: false)
                .flatMap { paragraph -> [String] in
                    let wrapped = theme.wrappedLines(for: String(paragraph), size: fontSize, maximumWidth: width)
                    return wrapped.isEmpty ? [""] : wrapped
                }
            lines += itemLines
            lineItems += repeatElement(index, count: itemLines.count)
        }
    }
}

/// Text a slider or scroll buttons can move through: a list or a text area.
protocol ScrollableText: AnyObject {
    func prepareLines(for bounds: Rectangle)
    func scroll(byLines lineCount: Int)
    func scroll(toFraction fraction: Float)
    func scrollThumbBounds(in track: Rectangle) -> Rectangle
}

extension TextList: ScrollableText {}
extension TextArea: ScrollableText {}
