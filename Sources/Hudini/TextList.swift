import Raylib

/// Displays host-provided plain-text items in a clipped, scrollable viewport.
public final class TextList {
    private static let padding: Int = 6
    private static let lineGap: Int = 2
    private static let linesPerWheelNotch: Float = 3
    private static let minimumThumbHeight: Float = 6

    private var lines: [String] = []
    private var lineWidth: Int?
    private var visibleLineCount = 1
    private var pendingWheelLines: Float = 0

    private let fontSize: Int
    private let textColor: Color
    private let backgroundColor: Color
    private let borderColor: Color

    /// The plain-text items supplied by the host.
    public var items: [String] {
        didSet {
            lineWidth = nil
        }
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

    /// Creates a text list using the host's ordered items.
    public init(
        items: [String] = [],
        fontSize: Int = 14,
        theme: InterfaceTheme = .standard,
        textColor: Color? = nil,
        backgroundColor: Color? = nil,
        borderColor: Color? = nil
    ) {
        precondition(fontSize > 0, "fontSize must be positive")
        self.items = items
        self.fontSize = fontSize
        self.textColor = textColor ?? theme.text
        self.backgroundColor = backgroundColor ?? theme.panel
        self.borderColor = borderColor ?? theme.border
    }

    /// Updates wheel and arrow-button scrolling for this frame.
    ///
    /// Positive values passed to `scroll(byLines:)` move toward older content.
    public func update(
        in bounds: Rectangle,
        scrollUpButton: Rectangle? = nil,
        scrollDownButton: Rectangle? = nil
    ) {
        prepareLines(for: bounds)
        let mouse = GetMousePosition()
        guard IsMouseButtonPressed(MouseButton.left) else {
            guard CheckCollisionPointRec(mouse, bounds) else {
                return
            }
            scroll(byWheelMovement: GetMouseWheelMove())
            if IsKeyPressed(KeyboardKey.pageUp) {
                scroll(byLines: visibleLineCount)
            } else if IsKeyPressed(KeyboardKey.pageDown) {
                scroll(byLines: -visibleLineCount)
            }
            return
        }

        if let scrollUpButton, CheckCollisionPointRec(mouse, scrollUpButton) {
            scroll(byLines: 1)
        } else if let scrollDownButton, CheckCollisionPointRec(mouse, scrollDownButton) {
            scroll(byLines: -1)
        }
    }

    /// Moves through the list. Positive values reveal older content.
    public func scroll(byLines lineCount: Int) {
        let maximumOffset = max(0, lines.count - visibleLineCount)
        scrollOffset = min(max(scrollOffset + lineCount, 0), maximumOffset)
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
        let maximumOffset = max(0, lines.count - visibleLineCount)
        scrollOffset = min(scrollOffset, maximumOffset)

        DrawRectangleRec(bounds, backgroundColor)
        DrawRectangleLinesEx(bounds, 1, borderColor)

        let firstLine = maximumOffset - scrollOffset
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
        let lineHeight = fontSize + Self.lineGap
        for index in firstLine..<endLine {
            DrawText(
                lines[index],
                Int(clamping: bounds.x) + Self.padding,
                Int(clamping: bounds.y) + Self.padding + ((index - firstLine) * lineHeight),
                fontSize,
                textColor
            )
        }
        EndScissorMode()
    }

    private func prepareLines(for bounds: Rectangle) {
        let width = max(1, Int(clamping: bounds.width) - (Self.padding * 2) - 2)
        if lineWidth != width {
            lines = items.flatMap { item in
                item
                    .split(separator: "\n", omittingEmptySubsequences: false)
                    .flatMap { paragraph -> [String] in
                        let wrapped = TextWrapper.lines(for: String(paragraph), fontSize: fontSize, maximumWidth: width)
                        return wrapped.isEmpty ? [""] : wrapped
                    }
            }
            lineWidth = width
        }
        visibleLineCount = max(
            1,
            (Int(clamping: bounds.height) - (Self.padding * 2) + Self.lineGap) / (fontSize + Self.lineGap)
        )
        scrollOffset = min(scrollOffset, max(0, lines.count - visibleLineCount))
    }
}
