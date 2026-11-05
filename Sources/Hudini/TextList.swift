import Raylib

/// Displays host-provided plain-text items in a clipped, scrollable viewport.
///
/// By default the list works as a log: it opens on its newest items and stays at the end as
/// items arrive. A selectable list works as a pick list: it opens on its first items, stays where
/// it is when items change, and a click selects an item.
public final class TextList {
    private static let padding: Int = 6
    private static let lineGap: Int = 2
    private static let linesPerWheelNotch: Float = 3
    private static let minimumThumbHeight: Float = 6

    private var lines: [String] = []
    // The index of the item each line came from.
    private var lineItems: [Int] = []
    private var lineWidth: Int?
    private var visibleLineCount = 1
    private var pendingWheelLines: Float = 0

    private let fontSize: Int
    private let theme: InterfaceTheme
    private let textColor: Color
    private let backgroundColor: Color
    private let borderColor: Color
    private let selectionColor: Color

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
        self.fontSize = fontSize ?? theme.textSizes.body
        self.theme = theme
        self.textColor = textColor ?? theme.text
        self.backgroundColor = backgroundColor ?? theme.panel
        self.borderColor = borderColor ?? theme.border
        selectionColor = theme.selectedItem
        self.isSelectable = isSelectable
    }

    /// Updates wheel and arrow-button scrolling for this frame, and selection on a selectable list.
    ///
    /// Positive values passed to `scroll(byLines:)` move toward older content. Returns an event
    /// when a click selects a different item.
    @discardableResult
    public func update(
        in bounds: Rectangle,
        scrollUpButton: Rectangle? = nil,
        scrollDownButton: Rectangle? = nil
    ) -> Event? {
        prepareLines(for: bounds)
        let mouse = GetMousePosition()
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
            return select(at: mouse, in: bounds)
        }
        return nil
    }

    /// Returns the index of the item drawn at `point`, or `nil` when no item is there. An item
    /// that wraps covers all of its lines. This works whether or not the list is selectable.
    public func itemIndex(at point: Vector2, in bounds: Rectangle) -> Int? {
        prepareLines(for: bounds)
        let distance = point.y - bounds.y - Float(Self.padding)
        guard CheckCollisionPointRec(point, bounds), distance >= 0 else {
            return nil
        }
        let row = Int(clamping: distance) / lineHeight
        let line = firstVisibleLine + row
        guard row < visibleLineCount, line < lines.count else {
            return nil
        }
        return lineItems[line]
    }

    /// Selects the item at `point`, and reports it when that changes the selection.
    func select(at point: Vector2, in bounds: Rectangle) -> Event? {
        guard isSelectable, let index = itemIndex(at: point, in: bounds), index != selectedIndex else {
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

    /// Draws the list background, border, and visible text.
    public func draw(in bounds: Rectangle) {
        prepareLines(for: bounds)

        DrawRectangleRec(bounds, backgroundColor)
        DrawRectangleLinesEx(bounds, 1, borderColor)

        let firstLine = firstVisibleLine
        let endLine = min(lines.count, firstLine + visibleLineCount)
        let textBounds = Rectangle(
            x: bounds.x + 1,
            y: bounds.y + 1,
            width: max(0, bounds.width - 2),
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
                DrawRectangle(Int(clamping: textBounds.x), y, Int(clamping: textBounds.width), lineHeight, selectionColor)
            }
            theme.drawText(lines[index], x: Int(clamping: bounds.x) + Self.padding, y: y, size: fontSize, color: textColor)
        }
        EndScissorMode()
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
        if lineWidth != width {
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
            lineWidth = width
        }
        visibleLineCount = max(
            1,
            (Int(clamping: bounds.height) - (Self.padding * 2) + Self.lineGap) / lineHeight
        )
        // scrollOffset counts from the end, so a pick list works out again what keeps its top line.
        let maximumOffset = max(0, lines.count - visibleLineCount)
        scrollOffset = isSelectable ? max(0, maximumOffset - previousFirstLine) : min(scrollOffset, maximumOffset)
    }
}
