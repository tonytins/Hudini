// The scroll bars lists and text areas draw for themselves. These run without a window, where
// every line of text measures as one line, so they check the bar's geometry and input, not how
// text wraps around it.

import Foundation
@testable import Hudini
import Raylib
import Testing

// Headless, the 100-tall viewport shows five lines, so twenty items scroll fifteen.
private let listBounds = Rectangle(x: 500, y: 500, width: 200, height: 100)

private func overflowingList(itemCount: Int = 20, isSelectable: Bool = false) -> TextList {
    let list = TextList(items: (0..<itemCount).map { "Item \($0)" }, isSelectable: isSelectable)
    list.prepareLines(for: listBounds)
    return list
}

// A press, then the frames after it while held, at the given times in seconds.
private func press(_ list: TextList, at point: Vector2, time: Double = 0) -> Bool {
    list.updateScrollBar(in: listBounds, pointer: point, isPressed: true, isDown: true, time: time)
}

private func hold(_ list: TextList, at point: Vector2, time: Double) -> Bool {
    list.updateScrollBar(in: listBounds, pointer: point, isPressed: false, isDown: true, time: time)
}

private func release(_ list: TextList) {
    _ = list.updateScrollBar(in: listBounds, pointer: .zero, isPressed: false, isDown: false, time: 0)
}

private let upArrow = Vector2(x: 690, y: 505)
private let downArrow = Vector2(x: 690, y: 595)

@Test func aListThatFitsHasNoScrollBar() {
    let list = overflowingList(itemCount: 5)

    #expect(list.scrollBarGeometry(in: listBounds) == nil)
    #expect(!list.scrollBarContains(Vector2(x: 690, y: 550), in: listBounds))
}

@Test func anOverflowingListsBarRunsDownItsRightEdgeInsideItsOutline() throws {
    let list = overflowingList()
    let bar = try #require(list.scrollBarGeometry(in: listBounds))

    #expect(bar.bar == Rectangle(x: 684, y: 501, width: 15, height: 98))
    #expect(bar.up == Rectangle(x: 684, y: 501, width: 15, height: 15))
    #expect(bar.down == Rectangle(x: 684, y: 584, width: 15, height: 15))
    #expect(bar.track == Rectangle(x: 684, y: 516, width: 15, height: 68))
    // Five of twenty lines would make a 17-pixel thumb, so it takes the 18-pixel minimum. A log
    // list opens on its newest items, so the thumb sits at the bottom of the track.
    #expect(bar.thumb == Rectangle(x: 684, y: 566, width: 15, height: 18))
}

@Test func theArrowsScrollALineAndTheTrackAPage() {
    let list = overflowingList()

    #expect(press(list, at: upArrow))
    #expect(list.scrollOffset == 1)
    release(list)
    #expect(press(list, at: downArrow))
    #expect(list.scrollOffset == 0)
    release(list)

    // Above the thumb pages back by the five lines shown, less one kept for context.
    #expect(press(list, at: Vector2(x: 690, y: 530)))
    #expect(list.scrollOffset == 4)
    release(list)
}

@Test func aHeldArrowRepeatsAfterADelay() {
    let list = overflowingList()

    #expect(press(list, at: upArrow, time: 10))
    #expect(list.scrollOffset == 1)
    #expect(hold(list, at: upArrow, time: 10.2))
    #expect(list.scrollOffset == 1)
    #expect(hold(list, at: upArrow, time: 10.35))
    #expect(list.scrollOffset == 2)
    #expect(hold(list, at: upArrow, time: 10.38))
    #expect(list.scrollOffset == 2)
    #expect(hold(list, at: upArrow, time: 10.4))
    #expect(list.scrollOffset == 3)

    // Moving off the arrow pauses it; letting go ends it.
    #expect(hold(list, at: Vector2(x: 600, y: 550), time: 10.5))
    #expect(list.scrollOffset == 3)
    release(list)
    #expect(!hold(list, at: upArrow, time: 11))
    #expect(list.scrollOffset == 3)
}

@Test func aHeldTrackPagesUntilTheThumbReachesThePointer() {
    let list = overflowingList()
    let target = Vector2(x: 690, y: 530)

    #expect(press(list, at: target, time: 0))
    for step in 1...20 {
        _ = hold(list, at: target, time: 0.3 + (Double(step) * 0.05))
    }
    // The thumb stops under the pointer rather than paging on to the top.
    let thumb = list.scrollBarGeometry(in: listBounds)!.thumb
    #expect(CheckCollisionPointRec(target, thumb))
    #expect(list.scrollOffset < 15)
}

@Test func draggingTheThumbScrollsInProportion() {
    let list = overflowingList()

    // Grab the thumb 4 pixels down from its top.
    #expect(press(list, at: Vector2(x: 690, y: 570)))
    #expect(list.scrollOffset == 0)
    #expect(hold(list, at: Vector2(x: 690, y: 0), time: 0.1))
    #expect(list.scrollOffset == 15)
    // Halfway down the 50 pixels the thumb travels.
    #expect(hold(list, at: Vector2(x: 690, y: 516 + 25 + 4), time: 0.2))
    #expect(list.scrollOffset == 7)
    // It follows the pointer anywhere until let go.
    #expect(hold(list, at: Vector2(x: 0, y: 2000), time: 0.3))
    #expect(list.scrollOffset == 0)
    release(list)
}

@Test func aPressOffTheBarIsLeftForTheList() {
    let list = overflowingList(isSelectable: true)

    #expect(!press(list, at: Vector2(x: 600, y: 520)))
    #expect(!hold(list, at: Vector2(x: 600, y: 520), time: 1))
}

@Test func itemsUnderTheBarCantBeClicked() {
    let list = overflowingList(isSelectable: true)

    #expect(list.itemIndex(at: Vector2(x: 600, y: 508), in: listBounds) == 0)
    #expect(list.itemIndex(at: Vector2(x: 690, y: 508), in: listBounds) == nil)
}

@Test func aTextAreaShowsABarOnlyOnceItsTextOverflows() throws {
    let bounds = Rectangle(x: 0, y: 0, width: 200, height: 80)
    // At 20 pixels, three lines fit.
    let area = TextArea(text: "one\ntwo\nthree", maximumLength: 100, fontSize: 20)
    #expect(area.scrollBarGeometry(in: bounds) == nil)

    area.text = (1...10).map(String.init).joined(separator: "\n")
    let bar = try #require(area.scrollBarGeometry(in: bounds))
    #expect(bar.bar == Rectangle(x: 184, y: 1, width: 15, height: 78))
    #expect(area.firstVisibleLine == 0)

    #expect(area.updateScrollBar(in: bounds, pointer: Vector2(x: 190, y: 75), isPressed: true, isDown: true, time: 0))
    #expect(area.firstVisibleLine == 1)
}

@Test func aPressOnADocumentsScrollBarIsThatControlsAlone() throws {
    let view = UIView(script: try UIScript(data: Data("""
        <UIScript version="1">
          <Window width="400" height="300"/>
          <List name="history" x="0" y="0" width="200" height="100"/>
          <List name="short" x="0" y="150" width="200" height="100"/>
          <TextArea name="notes" x="220" y="0" width="150" height="80"/>
        </UIScript>
        """.utf8)))
    view.list(named: "history")?.items = (0..<20).map { "Item \($0)" }
    view.list(named: "short")?.items = ["Fits"]
    view.textArea(named: "notes")?.text = (1...10).map(String.init).joined(separator: "\n")

    #expect(view.scrollBarControl(at: Vector2(x: 190, y: 50), origin: .zero) == "history")
    #expect(view.scrollBarControl(at: Vector2(x: 360, y: 40), origin: .zero) == "notes")
    // Off the bar, or on a list that fits, the press is left for the list as before.
    #expect(view.scrollBarControl(at: Vector2(x: 50, y: 50), origin: .zero) == nil)
    #expect(view.scrollBarControl(at: Vector2(x: 190, y: 200), origin: .zero) == nil)
}

// MARK: Art from an appearance

@Test func anAppearancesWidthSizesTheBar() throws {
    let appearance = try Appearance(data: Data("<Appearance><ScrollBar width='20'/></Appearance>".utf8))
    let view = UIView(script: try UIScript(data: Data("""
        <UIScript version="1"><Window width="400" height="300"/>
          <List name="history" x="0" y="0" width="200" height="100"/>
        </UIScript>
        """.utf8), appearance: appearance))
    view.list(named: "history")?.items = (0..<20).map { "Item \($0)" }
    let bounds = Rectangle(x: 0, y: 0, width: 200, height: 100)

    let bar = try #require(view.list(named: "history")?.scrollBarGeometry(in: bounds))
    #expect(bar.bar == Rectangle(x: 179, y: 1, width: 20, height: 98))
    #expect(bar.up.height == 20)
}

@Test func aThumbImageStretchesOnlyBetweenItsCaps() {
    let source = Rectangle(x: 0, y: 0, width: 15, height: 32)

    let tall = ScrollBar.thumbSlices(source: source, box: Rectangle(x: 10, y: 100, width: 15, height: 60), cap: 6)
    #expect(tall.map(\.from) == [
        Rectangle(x: 0, y: 0, width: 15, height: 6),
        Rectangle(x: 0, y: 6, width: 15, height: 20),
        Rectangle(x: 0, y: 26, width: 15, height: 6),
    ])
    #expect(tall.map(\.to) == [
        Rectangle(x: 10, y: 100, width: 15, height: 6),
        Rectangle(x: 10, y: 106, width: 15, height: 48),
        Rectangle(x: 10, y: 154, width: 15, height: 6),
    ])

    // Too short for both caps: they shrink evenly, and the middle is left out.
    let short = ScrollBar.thumbSlices(source: source, box: Rectangle(x: 0, y: 0, width: 15, height: 8), cap: 6)
    #expect(short.map(\.to) == [
        Rectangle(x: 0, y: 0, width: 15, height: 4),
        Rectangle(x: 0, y: 4, width: 15, height: 4),
    ])

    // No cap stretches the whole image, and a cap past half the image stops at half.
    #expect(ScrollBar.thumbSlices(source: source, box: Rectangle(x: 0, y: 0, width: 15, height: 60), cap: 0).count == 1)
    let halves = ScrollBar.thumbSlices(source: source, box: Rectangle(x: 0, y: 0, width: 15, height: 60), cap: 40)
    #expect(halves.map(\.from.height) == [16, 16])
}

@Test func anArrowImageShowsItsState() throws {
    var bar = ScrollBar()
    let bounds = Rectangle(x: 0, y: 0, width: 200, height: 100)
    let middle = ScrollBar.Position(first: 5, last: 10, shown: 5)
    let geometry = try #require(bar.geometry(in: bounds, position: middle))
    let away = Vector2(x: 50, y: 50)
    let onUp = Vector2(x: geometry.up.x + 5, y: geometry.up.y + 5)

    #expect(bar.arrowState(.up, in: geometry.up, position: middle, pointer: away, isDown: false) == .normal)
    #expect(bar.arrowState(.up, in: geometry.up, position: middle, pointer: onUp, isDown: false) == .hovered)
    // At its end, an arrow can't scroll, so it shows disabled.
    let top = ScrollBar.Position(first: 0, last: 10, shown: 5)
    #expect(bar.arrowState(.up, in: geometry.up, position: top, pointer: onUp, isDown: false) == .disabled)
    let bottom = ScrollBar.Position(first: 10, last: 10, shown: 5)
    #expect(bar.arrowState(.down, in: geometry.down, position: bottom, pointer: away, isDown: false) == .disabled)

    // Held down, it shows pressed until it's let go.
    _ = bar.update(pointer: onUp, isPressed: true, isDown: true, time: 0, in: bounds, position: middle)
    #expect(bar.arrowState(.up, in: geometry.up, position: middle, pointer: onUp, isDown: true) == .pressed)
    #expect(bar.arrowState(.down, in: geometry.down, position: middle, pointer: onUp, isDown: true) == .normal)
}
