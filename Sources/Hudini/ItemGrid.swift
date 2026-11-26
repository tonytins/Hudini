import Raylib

/// Shows items of one size, pictures, colors, or plain tiles, in rows that wrap to its width and
/// scroll, with one of them chosen, as wallpapers or accent colors are chosen from.
///
/// Items run from the left, row after row, in as many columns as fit. Once the rows don't all fit,
/// the grid draws a classic scroll bar down its right edge, taking its width from the columns, and
/// scrolls by rows. A click chooses an item, ringed in the theme's accent, and a second click on it
/// soon after makes a double-click, as a list's does. The grid draws nothing behind its items, so
/// it sits on whatever is under it.
public final class ItemGrid {
    /// How far the ring around a chosen item sits outside its cell, which is also the room kept
    /// around the cells inside the grid's bounds.
    static let ring: Float = 3
    // The room between a plain tile's edge and its title.
    private static let tileInset: Float = 4
    // The room between a cell and the title under it.
    private static let titleGap: Float = 2
    private static let rowsPerWheelNotch: Float = 1

    /// The most seconds between two clicks on the same item that count as a double-click.
    public static let doubleClickInterval: Double = TextList.doubleClickInterval

    /// One cell of a grid.
    public struct Item {
        /// What the grid reports when the item is chosen, or `nil` for an item with no name.
        public var name: String?

        /// What the item's called, shown as the grid's `titles` say, and inside a plain tile.
        public var title: String

        /// What the cell shows.
        public var content: Content

        /// Text shown while the pointer rests on the item, or `nil` for none.
        public var tooltip: String?

        /// What a grid item's cell shows.
        public enum Content {
            /// A picture scaled to fill the cell: `source` of the texture, or all of it when
            /// `source` is `nil`. A `nil` texture, one that couldn't be loaded, draws as an outline
            /// in the theme's error color. The host owns the texture.
            case image(Texture2D?, source: Rectangle? = nil)

            /// A color, drawn as a circle as wide as the cell's shorter side.
            case color(Color)

            /// A plain tile with the item's title inside it.
            case plain
        }

        /// Creates an item.
        public init(name: String? = nil, title: String = "", content: Content, tooltip: String? = nil) {
            self.name = name
            self.title = title
            self.content = content
            self.tooltip = tooltip
        }
    }

    /// An event produced by this grid.
    public enum Event: Equatable, Sendable {
        /// A click chose the item at this index, which wasn't chosen before.
        case selected(Int)

        /// The item at this index was double-clicked. The first click chose it.
        case submitted(Int)
    }

    /// The size of every item's cell, in pixels.
    public let itemSize: Vector2

    /// The room between cells, across and down, in pixels.
    public let spacing: Float

    /// Which items show their titles under their cells.
    public let titles: UIScript.Grid.Titles

    /// The items, in order. Replace them freely; the grid lays them out again on the next frame.
    public var items: [Item] {
        didSet {
            if let selectedIndex, selectedIndex >= items.count {
                self.selectedIndex = nil
            }
        }
    }

    /// The chosen item, or `nil` when none is. Setting it reports no event, and an index outside
    /// `items` clears it.
    ///
    /// The grid tracks a position, not an item, so a host that reorders `items` sets this again.
    public var selectedIndex: Int? {
        didSet {
            if let selectedIndex, !items.indices.contains(selectedIndex) {
                self.selectedIndex = nil
            }
        }
    }

    /// The first row showing.
    ///
    /// The value is clamped to the rows there are during update and drawing.
    public private(set) var firstRow = 0

    /// The colors and size the grid draws with. Setting it takes effect from the next draw, and
    /// keeps the grid's items, choice, and scroll position. A size and color passed when creating
    /// the grid still win.
    public var theme: InterfaceTheme

    private var fontSizeOverride: Int?
    private var textColorOverride: Color?
    private var scrollBar = ScrollBar()
    private var pendingWheelRows: Float = 0
    // The item the last click landed on, and when, so a second one can make a double-click.
    private var lastClick: (index: Int, time: Double)?

    var fontSize: Int {
        fontSizeOverride ?? theme.textSizes.body
    }

    var textColor: Color {
        textColorOverride ?? theme.text
    }

    /// Creates a grid. Without a `fontSize`, titles use the theme's `body` size.
    public init(
        itemSize: Vector2,
        spacing: Float = UIScript.Grid.defaultSpacing,
        titles: UIScript.Grid.Titles = .below,
        items: [Item] = [],
        fontSize: Int? = nil,
        theme: InterfaceTheme = .standard,
        textColor: Color? = nil
    ) {
        precondition(itemSize.x > 0 && itemSize.y > 0, "itemSize must be positive")
        precondition(spacing >= 0, "spacing must not be negative")
        precondition(fontSize.map { $0 > 0 } ?? true, "fontSize must be positive")
        self.itemSize = itemSize
        self.spacing = spacing
        self.titles = titles
        self.items = items
        fontSizeOverride = fontSize
        self.theme = theme
        textColorOverride = textColor
    }

    /// Replaces the size and color the document's style gave this grid, after its view resolved
    /// them against a new theme.
    func applyStyle(fontSize: Int?, textColor: Color?) {
        fontSizeOverride = fontSize
        textColorOverride = textColor
    }

    // MARK: Layout

    /// How many columns and rows the items take, and how many rows show at once, at `bounds`.
    struct Shape: Equatable {
        var columns: Int
        var rows: Int
        var visibleRows: Int

        /// Whether the rows don't all fit, so the grid shows a scroll bar.
        var scrolls: Bool { rows > visibleRows }
    }

    // The room under each cell for its title, or none when no title shows under a cell.
    private var titleRoom: Float {
        titles == .none ? 0 : Float(fontSize) + Self.titleGap * 2
    }

    private var rowHeight: Float {
        itemSize.y + spacing + titleRoom
    }

    private func columns(in width: Float) -> Int {
        max(1, Int(((width - 2 * Self.ring + spacing) / (itemSize.x + spacing)).rounded(.down)))
    }

    /// The grid's shape at `bounds`. The scroll bar takes room once the rows don't fit, and the
    /// items wrap again in what's left; fewer columns only add rows, so the bar still shows.
    func shape(in bounds: Rectangle) -> Shape {
        let visibleRows = max(1, Int(((bounds.height - 2 * Self.ring + spacing) / rowHeight).rounded(.down)))
        var columns = columns(in: bounds.width)
        var rows = (items.count + columns - 1) / columns
        if rows > visibleRows {
            columns = self.columns(in: bounds.width - scrollBar.width)
            rows = (items.count + columns - 1) / columns
        }
        return Shape(columns: columns, rows: rows, visibleRows: visibleRows)
    }

    // Keeps the scroll in range of the rows there are.
    private func clampScroll(_ shape: Shape) {
        firstRow = min(max(firstRow, 0), max(0, shape.rows - shape.visibleRows))
    }

    /// The cell of the item at `index` at `bounds`, or `nil` when it isn't showing.
    func cell(of index: Int, in bounds: Rectangle) -> Rectangle? {
        let shape = shape(in: bounds)
        clampScroll(shape)
        let row = index / shape.columns - firstRow
        guard items.indices.contains(index), row >= 0, row < shape.visibleRows else {
            return nil
        }
        return cell(row: row, column: index % shape.columns, in: bounds)
    }

    private func cell(row: Int, column: Int, in bounds: Rectangle) -> Rectangle {
        Rectangle(
            x: bounds.x + Self.ring + Float(column) * (itemSize.x + spacing),
            y: bounds.y + Self.ring + Float(row) * rowHeight,
            width: itemSize.x,
            height: itemSize.y
        )
    }

    /// Returns the index of the item at `point`, on its cell or its title, or `nil` when no item
    /// is there.
    public func itemIndex(at point: Vector2, in bounds: Rectangle) -> Int? {
        let shape = shape(in: bounds)
        clampScroll(shape)
        let along = point.x - bounds.x - Self.ring
        let down = point.y - bounds.y - Self.ring
        guard CheckCollisionPointRec(point, bounds), along >= 0, down >= 0,
              !scrollBarContains(point, in: bounds) else {
            return nil
        }
        let step = itemSize.x + spacing
        let column = Int((along / step).rounded(.down))
        let row = Int((down / rowHeight).rounded(.down))
        guard column < shape.columns, row < shape.visibleRows,
              along - Float(column) * step < itemSize.x,
              down - Float(row) * rowHeight < itemSize.y + titleRoom else {
            return nil
        }
        let index = (firstRow + row) * shape.columns + column
        return index < items.count ? index : nil
    }

    /// What shows while the pointer rests at `point`: the item's tooltip, or its title when the
    /// grid shows no titles; `nil` elsewhere.
    public func tooltip(at point: Vector2, in bounds: Rectangle) -> String? {
        itemIndex(at: point, in: bounds).flatMap(tooltip(forItem:))
    }

    /// What shows while the pointer rests on the item at `index`: its tooltip, or its title when
    /// the grid shows no titles; `nil` when there's neither, or no item at `index`.
    func tooltip(forItem index: Int) -> String? {
        guard items.indices.contains(index) else {
            return nil
        }
        let item = items[index]
        return item.tooltip ?? (titles == .none && !item.title.isEmpty ? item.title : nil)
    }

    // MARK: Input

    /// Updates the scroll bar, wheel, and Page Up and Page Down scrolling for this frame, and
    /// choosing an item.
    ///
    /// A press on the scroll bar, and the pointer until it's let go, belong to the bar, so they
    /// never choose an item. Returns an event when a click chooses a different item, or when a
    /// second click on the same item within `doubleClickInterval` makes a double-click.
    @discardableResult
    public func update(in bounds: Rectangle) -> Event? {
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
            scroll(byWheelMovement: GetMouseWheelMove(), in: bounds)
            let page = shape(in: bounds).visibleRows
            if IsKeyPressed(KeyboardKey.pageUp) {
                scroll(byRows: -page, in: bounds)
            } else if IsKeyPressed(KeyboardKey.pageDown) {
                scroll(byRows: page, in: bounds)
            }
            return nil
        }
        return select(at: mouse, in: bounds, time: GetTime())
    }

    /// Chooses the item at `point` for a click at `time`, in seconds. Reports a change to the
    /// choice, or a double-click when the last click landed on the same item close enough before.
    func select(at point: Vector2, in bounds: Rectangle, time: Double) -> Event? {
        guard let index = itemIndex(at: point, in: bounds) else {
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

    /// Moves through the rows at `bounds`. Positive values move toward later rows.
    public func scroll(byRows rowCount: Int, in bounds: Rectangle) {
        firstRow += rowCount
        clampScroll(shape(in: bounds))
    }

    /// Moves through the rows by a mouse wheel reading, where positive values, a wheel turned
    /// away from the user, move toward earlier rows.
    ///
    /// Partial rows carry over to later calls, so the small steps a trackpad reports still add up.
    public func scroll(byWheelMovement movement: Float, in bounds: Rectangle) {
        guard movement.isFinite else {
            return
        }
        pendingWheelRows += movement * Self.rowsPerWheelNotch
        let rowCount = Int(pendingWheelRows)
        pendingWheelRows -= Float(rowCount)
        if rowCount != 0 {
            scroll(byRows: -rowCount, in: bounds)
        }
    }

    // MARK: Scroll bar

    private func scrollBarPosition(_ shape: Shape) -> ScrollBar.Position {
        ScrollBar.Position(
            first: firstRow,
            last: shape.scrolls ? shape.rows - shape.visibleRows : 0,
            shown: shape.visibleRows
        )
    }

    /// The scroll bar's parts at `bounds`, or `nil` when the grid has no bar showing.
    func scrollBarGeometry(in bounds: Rectangle) -> ScrollBar.Geometry? {
        let shape = shape(in: bounds)
        clampScroll(shape)
        return scrollBar.geometry(in: bounds, position: scrollBarPosition(shape))
    }

    /// Gives the scroll bar a width and an appearance's art, or `nil` art for the theme's classic
    /// bar.
    func useScrollBar(width: Float, art: ScrollBar.Art?) {
        scrollBar.width = width
        scrollBar.art = art
    }

    /// Whether `point` is on the scroll bar the grid shows at `bounds`.
    func scrollBarContains(_ point: Vector2, in bounds: Rectangle) -> Bool {
        scrollBarGeometry(in: bounds).map { CheckCollisionPointRec(point, $0.bar) } ?? false
    }

    /// Applies one frame of the pointer to the scroll bar, and reports whether the pointer is the
    /// bar's this frame.
    func updateScrollBar(in bounds: Rectangle, pointer: Vector2, isPressed: Bool, isDown: Bool, time: Double) -> Bool {
        let shape = shape(in: bounds)
        clampScroll(shape)
        let result = scrollBar.update(
            pointer: pointer,
            isPressed: isPressed,
            isDown: isDown,
            time: time,
            in: bounds,
            position: scrollBarPosition(shape)
        )
        if let first = result.first {
            firstRow = first
            clampScroll(shape)
        }
        return result.tookPointer
    }

    // MARK: Drawing

    /// Draws the rows that show at `bounds`: pictures scaled to their cells, colors as circles, and
    /// plain tiles with their titles, the chosen one ringed in the accent, then titles as `titles`
    /// says, and the scroll bar when the rows don't all fit.
    public func draw(in bounds: Rectangle) {
        let shape = shape(in: bounds)
        clampScroll(shape)
        for row in 0..<shape.visibleRows {
            for column in 0..<shape.columns {
                let index = (firstRow + row) * shape.columns + column
                guard index < items.count else {
                    break
                }
                let item = items[index]
                let isChosen = index == selectedIndex
                let cell = cell(row: row, column: column, in: bounds)
                switch item.content {
                case let .color(color):
                    drawSwatch(color, in: cell, isChosen: isChosen)
                case let .image(texture, source):
                    drawPicture(texture, source: source, in: cell, isChosen: isChosen)
                case .plain:
                    drawPlainTile(item.title, in: cell, isChosen: isChosen)
                    continue
                }
                let showsTitle = titles == .below || (titles == .selected && isChosen)
                if showsTitle, !item.title.isEmpty {
                    drawTitle(item.title, under: cell, in: bounds, isChosen: isChosen)
                }
            }
        }
        if let geometry = scrollBar.geometry(in: bounds, position: scrollBarPosition(shape)) {
            scrollBar.draw(geometry, position: scrollBarPosition(shape), theme: theme)
        }
    }

    private func drawSwatch(_ color: Color, in cell: Rectangle, isChosen: Bool) {
        let radius = min(cell.width, cell.height) / 2
        let center = Vector2(x: cell.x + cell.width / 2, y: cell.y + cell.height / 2)
        if isChosen {
            DrawRing(center, radius + 1, radius + Self.ring, 0, 360, 36, theme.accent)
        }
        DrawCircleV(center, radius, color)
    }

    private func drawPicture(_ texture: Texture2D?, source: Rectangle?, in cell: Rectangle, isChosen: Bool) {
        if isChosen {
            DrawRectangleLinesEx(Self.ringBounds(around: cell), 2, theme.accent)
        }
        guard let texture else {
            DrawRectangleLinesEx(cell, 1, theme.error)
            return
        }
        let whole = Rectangle(x: 0, y: 0, width: Float(texture.width), height: Float(texture.height))
        DrawTexturePro(texture, source ?? whole, cell, .zero, 0, .white)
    }

    private func drawPlainTile(_ title: String, in cell: Rectangle, isChosen: Bool) {
        // A ring rather than a fill behind the tile, since a theme's panel, and so the tile, may
        // be see-through.
        if isChosen {
            theme.outlineRectangle(Self.ringBounds(around: cell), theme.accent, thickness: 2)
        }
        theme.fillRectangle(cell, ScrollBar.blend(theme.panel, theme.text, 0.08))
        let text = theme.fitted(title, size: fontSize, in: cell.width - 2 * Self.tileInset)
        let width = Float(theme.textWidth(of: text, size: fontSize))
        theme.drawText(
            text,
            x: Int(clamping: cell.x + ((cell.width - width) / 2).rounded(.down)),
            y: Int(clamping: cell.y + ((cell.height - Float(fontSize)) / 2).rounded(.down)),
            size: fontSize,
            color: textColor
        )
    }

    // A title centred under its cell. Every title fits its cell and the room beside it; a chosen
    // one shown alone may run as wide as the grid, as a row of colors names the one in use.
    private func drawTitle(_ title: String, under cell: Rectangle, in bounds: Rectangle, isChosen: Bool) {
        let room = titles == .selected ? bounds.width : cell.width + spacing
        let text = theme.fitted(title, size: fontSize, in: room)
        let width = Float(theme.textWidth(of: text, size: fontSize))
        let centred = cell.x + ((cell.width - width) / 2).rounded(.down)
        let left = min(max(centred, bounds.x), max(bounds.x, bounds.x + bounds.width - width))
        theme.drawText(
            text,
            x: Int(clamping: left),
            y: Int(clamping: cell.y + cell.height + Self.titleGap),
            size: fontSize,
            color: isChosen ? textColor : theme.secondaryText
        )
    }

    private static func ringBounds(around cell: Rectangle) -> Rectangle {
        Rectangle(x: cell.x - ring, y: cell.y - ring, width: cell.width + ring * 2, height: cell.height + ring * 2)
    }
}
