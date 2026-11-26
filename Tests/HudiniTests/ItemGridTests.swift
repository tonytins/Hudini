// The item grid's layout, choosing, and scrolling. These run without a window: titles use the
// standard theme's body size, 14, so a row with titles under it is 24 + 8 + 18 = 50 pixels tall.

import Foundation
@testable import Hudini
import Raylib
import Testing

private let bounds = Rectangle(x: 500, y: 500, width: 200, height: 100)
private let cellSize = Vector2(x: 28, y: 24)

private func grid(itemCount: Int, titles: UIScript.Grid.Titles = .below) -> ItemGrid {
    ItemGrid(
        itemSize: cellSize,
        titles: titles,
        items: (0..<itemCount).map { ItemGrid.Item(name: "item\($0)", title: "Item \($0)", content: .plain) }
    )
}

// The middle of the cell at this row and column, counted from the first row showing.
private func middle(row: Int, column: Int) -> Vector2 {
    Vector2(x: 500 + 3 + Float(column) * 36 + 14, y: 500 + 3 + Float(row) * 50 + 12)
}

// MARK: Layout

@Test func itemsFillAsManyColumnsAsFitAndTheRowsThatFitShow() {
    // (200 - 6 + 8) / 36 columns and (100 - 6 + 8) / 50 rows, rounded down.
    #expect(grid(itemCount: 10).shape(in: bounds) == .init(columns: 5, rows: 2, visibleRows: 2))
    #expect(grid(itemCount: 7).shape(in: bounds) == .init(columns: 5, rows: 2, visibleRows: 2))
    #expect(grid(itemCount: 0).shape(in: bounds) == .init(columns: 5, rows: 0, visibleRows: 2))
}

@Test func withoutTitlesARowIsOnlyItsCellAndSpacing() {
    // (100 - 6 + 8) / 32 rows.
    #expect(grid(itemCount: 1, titles: .none).shape(in: bounds).visibleRows == 3)
    // `selected` keeps room under every row, since the chosen item can be in any of them.
    #expect(grid(itemCount: 1, titles: .selected).shape(in: bounds).visibleRows == 2)
}

@Test func aScrollBarTakesItsWidthFromTheColumns() {
    let wide = Rectangle(x: 500, y: 500, width: 214, height: 100)

    // Six columns fit 214 pixels, but five fit what's left beside a 15-pixel bar.
    #expect(grid(itemCount: 12).shape(in: wide) == .init(columns: 6, rows: 2, visibleRows: 2))
    #expect(grid(itemCount: 13).shape(in: wide) == .init(columns: 5, rows: 3, visibleRows: 2))
    #expect(grid(itemCount: 12).scrollBarGeometry(in: wide) == nil)
    #expect(grid(itemCount: 13).scrollBarGeometry(in: wide) != nil)
}

@Test func aGridTooSmallForAnItemStillShowsOne() {
    let tiny = Rectangle(x: 0, y: 0, width: 4, height: 4)

    #expect(grid(itemCount: 3).shape(in: tiny) == .init(columns: 1, rows: 3, visibleRows: 1))
}

@Test func cellsSitInsideTheRingRoomAndStepBySpacing() {
    let items = grid(itemCount: 10)

    #expect(items.cell(of: 0, in: bounds) == Rectangle(x: 503, y: 503, width: 28, height: 24))
    #expect(items.cell(of: 7, in: bounds) == Rectangle(x: 503 + 72, y: 553, width: 28, height: 24))
    #expect(items.cell(of: 10, in: bounds) == nil)
}

// MARK: Finding items

@Test func aPointFindsTheItemOnItsCellOrItsTitle() {
    let items = grid(itemCount: 10)

    #expect(items.itemIndex(at: middle(row: 0, column: 0), in: bounds) == 0)
    #expect(items.itemIndex(at: middle(row: 1, column: 2), in: bounds) == 7)
    // The title runs 18 pixels under the cell.
    #expect(items.itemIndex(at: Vector2(x: 517, y: 503 + 24 + 10), in: bounds) == 0)
}

@Test func aPointBetweenOrPastTheItemsFindsNothing() {
    let items = grid(itemCount: 7)

    // The spacing between columns, and below a row's title.
    #expect(items.itemIndex(at: Vector2(x: 503 + 30, y: 515), in: bounds) == nil)
    #expect(items.itemIndex(at: Vector2(x: 517, y: 503 + 24 + 18 + 3), in: bounds) == nil)
    // The ring room, a cell past the last item, and outside the grid.
    #expect(items.itemIndex(at: Vector2(x: 501, y: 501), in: bounds) == nil)
    #expect(items.itemIndex(at: middle(row: 1, column: 3), in: bounds) == nil)
    #expect(items.itemIndex(at: Vector2(x: 400, y: 515), in: bounds) == nil)
}

@Test func theScrollBarIsntAnItem() throws {
    let items = grid(itemCount: 30)
    let bar = try #require(items.scrollBarGeometry(in: bounds)).bar

    #expect(items.itemIndex(at: Vector2(x: bar.x + 2, y: bar.y + 40), in: bounds) == nil)
}

@Test func aTooltipIsTheItemsOrItsTitleWhenNoTitlesShow() {
    let items = ItemGrid(itemSize: cellSize, titles: .below, items: [
        .init(title: "Blue", content: .color(.blue), tooltip: "The accent"),
        .init(title: "Teal", content: .color(.green)),
    ])
    let untitled = ItemGrid(itemSize: cellSize, titles: .none, items: [.init(title: "Teal", content: .color(.green))])

    #expect(items.tooltip(at: middle(row: 0, column: 0), in: bounds) == "The accent")
    #expect(items.tooltip(at: middle(row: 0, column: 1), in: bounds) == nil)
    #expect(untitled.tooltip(at: Vector2(x: 517, y: 515), in: bounds) == "Teal")
    #expect(untitled.tooltip(at: Vector2(x: 400, y: 515), in: bounds) == nil)
}

// MARK: Choosing

@Test func aClickChoosesAnItemAndASecondSoonAfterSubmitsIt() {
    let items = grid(itemCount: 10)

    #expect(items.select(at: middle(row: 0, column: 1), in: bounds, time: 0) == .selected(1))
    #expect(items.selectedIndex == 1)
    #expect(items.select(at: middle(row: 0, column: 1), in: bounds, time: 0.3) == .submitted(1))
    // A third click starts over, and the item is already chosen.
    #expect(items.select(at: middle(row: 0, column: 1), in: bounds, time: 0.4) == nil)
    #expect(items.select(at: middle(row: 1, column: 0), in: bounds, time: 0.5) == .selected(5))
}

@Test func clicksTooFarApartOrOnNothingDontSubmit() {
    let items = grid(itemCount: 10)

    _ = items.select(at: middle(row: 0, column: 1), in: bounds, time: 0)
    #expect(items.select(at: middle(row: 0, column: 1), in: bounds, time: 2) == nil)
    _ = items.select(at: Vector2(x: 400, y: 400), in: bounds, time: 2.1)
    #expect(items.select(at: middle(row: 0, column: 1), in: bounds, time: 2.2) == nil)
    #expect(items.selectedIndex == 1)
}

@Test func theChoiceStaysInsideTheItems() {
    let items = grid(itemCount: 10)

    items.selectedIndex = 12
    #expect(items.selectedIndex == nil)
    items.selectedIndex = 8
    items.items.removeLast(3)
    #expect(items.selectedIndex == nil)
    items.selectedIndex = 2
    items.items.removeLast()
    #expect(items.selectedIndex == 2)
}

// MARK: Scrolling

@Test func scrollingMovesByRowsAndStaysInRange() {
    // 24 items in five columns are five rows, two of which show.
    let items = grid(itemCount: 24)

    items.scroll(byRows: 1, in: bounds)
    #expect(items.firstRow == 1)
    #expect(items.itemIndex(at: middle(row: 0, column: 0), in: bounds) == 5)
    #expect(items.cell(of: 0, in: bounds) == nil)
    items.scroll(byRows: 100, in: bounds)
    #expect(items.firstRow == 3)
    items.scroll(byRows: -100, in: bounds)
    #expect(items.firstRow == 0)
}

@Test func theWheelScrollsByRowsAndCarriesPartsOfOne() {
    let items = grid(itemCount: 24)

    items.scroll(byWheelMovement: -0.5, in: bounds)
    #expect(items.firstRow == 0)
    items.scroll(byWheelMovement: -0.5, in: bounds)
    #expect(items.firstRow == 1)
    items.scroll(byWheelMovement: 1, in: bounds)
    #expect(items.firstRow == 0)
    items.scroll(byWheelMovement: .nan, in: bounds)
    #expect(items.firstRow == 0)
}

@Test func removingItemsPullsTheScrollBackIntoRange() {
    let items = grid(itemCount: 24)
    items.scroll(byRows: 3, in: bounds)

    items.items.removeLast(14)
    #expect(items.shape(in: bounds).scrolls == false)
    #expect(items.itemIndex(at: middle(row: 0, column: 0), in: bounds) == 0)
    #expect(items.firstRow == 0)
}

@Test func theScrollBarsArrowsScrollByARowAndTakeThePointer() throws {
    let items = grid(itemCount: 24)
    let geometry = try #require(items.scrollBarGeometry(in: bounds))
    let downArrow = Vector2(x: geometry.down.x + 2, y: geometry.down.y + 2)

    #expect(items.updateScrollBar(in: bounds, pointer: downArrow, isPressed: true, isDown: true, time: 0))
    #expect(items.firstRow == 1)
    #expect(items.selectedIndex == nil)
    // Off the bar, a press is the items'.
    #expect(!items.updateScrollBar(in: bounds, pointer: middle(row: 0, column: 0), isPressed: true, isDown: true, time: 1))
}
