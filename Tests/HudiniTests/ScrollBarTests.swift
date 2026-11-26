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

    let tall = ScrollBar.slices(source: source, box: Rectangle(x: 10, y: 100, width: 15, height: 60), cap: 6)
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
    let short = ScrollBar.slices(source: source, box: Rectangle(x: 0, y: 0, width: 15, height: 8), cap: 6)
    #expect(short.map(\.to) == [
        Rectangle(x: 0, y: 0, width: 15, height: 4),
        Rectangle(x: 0, y: 4, width: 15, height: 4),
    ])

    // No cap stretches the whole image, and a cap past half the image stops at half.
    #expect(ScrollBar.slices(source: source, box: Rectangle(x: 0, y: 0, width: 15, height: 60), cap: 0).count == 1)
    let halves = ScrollBar.slices(source: source, box: Rectangle(x: 0, y: 0, width: 15, height: 60), cap: 40)
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

// MARK: Packed art (docs/design/2026-11-26-packed-scroll-bar.md)

private func texture(_ width: Int32, _ height: Int32) -> Texture2D {
    var texture = Texture2D()
    texture.width = width
    texture.height = height
    return texture
}

private func art(_ width: Int32, _ height: Int32, states: Int = 1) -> ScrollBar.Art.Image {
    ScrollBar.Art.Image(
        texture: texture(width, height),
        resource: UIScript.ImageResource(path: "art.png", assetID: nil, stateCount: states)
    )
}

// The Sims Online's gizmo bar: four-state 84x8 arrows, and a 13x96 slider packing track and thumb.
private func gizmo(slider: Bool = true, arrows: Bool = true) -> ScrollBar {
    var bar = ScrollBar()
    bar.art = ScrollBar.Art(
        up: arrows ? art(84, 8, states: 4) : nil,
        down: arrows ? art(84, 8, states: 4) : nil,
        isPacked: true,
        slider: slider ? art(13, 96) : nil
    )
    bar.width = bar.art!.packedWidth
    return bar
}

private let packedBounds = Rectangle(x: 0, y: 0, width: 200, height: 200)

@Test func aPackedBarIsAsWideAsItsWidestPart() {
    #expect(gizmo().width == 21)
    // A slider that didn't load counts as the classic bar's 15 pixels; arrows still widen it.
    #expect(gizmo(slider: false).width == 21)
    #expect(gizmo(arrows: false).width == 13)
    #expect(gizmo(slider: false, arrows: false).width == 15)
}

@Test func aPackedBarDrawsEachPartAtItsOwnSizeCentered() throws {
    let bar = gizmo()
    let top = try #require(bar.geometry(in: packedBounds, position: .init(first: 0, last: 10, shown: 5)))

    #expect(top.bar == Rectangle(x: 178, y: 1, width: 21, height: 198))
    // One state of the arrow strip, 21x8, at each end.
    #expect(top.up == Rectangle(x: 178, y: 1, width: 21, height: 8))
    #expect(top.down == Rectangle(x: 178, y: 191, width: 21, height: 8))
    // The 13-pixel track and thumb centered under them, as budget.uis places them.
    #expect(top.track == Rectangle(x: 182, y: 9, width: 13, height: 182))
    #expect(top.thumb == Rectangle(x: 182, y: 9, width: 13, height: 24))
}

@Test func aPackedThumbKeepsItsSizeAndOnlyMoves() throws {
    let bar = gizmo()
    func thumb(first: Int, shown: Int) throws -> Rectangle {
        try #require(bar.geometry(in: packedBounds, position: .init(first: first, last: 10, shown: shown))).thumb
    }

    #expect(try thumb(first: 5, shown: 5) == Rectangle(x: 182, y: 88, width: 13, height: 24))
    #expect(try thumb(first: 10, shown: 5) == Rectangle(x: 182, y: 167, width: 13, height: 24))
    // However much shows, the thumb is the same size.
    #expect(try thumb(first: 10, shown: 50).height == 24)
}

@Test func aPackedThumbShrinksToAShortTrack() throws {
    let geometry = try #require(gizmo().geometry(
        in: Rectangle(x: 0, y: 0, width: 200, height: 40),
        position: .init(first: 0, last: 10, shown: 2)
    ))

    #expect(geometry.track.height == 22)
    #expect(geometry.thumb.height == 22)
}

@Test func aPackedImageKeepsItsTrackAboveItsThumb() {
    let sources = ScrollBar.packedSources(of: art(13, 96))
    #expect(sources.track == Rectangle(x: 0, y: 0, width: 13, height: 72))
    #expect(sources.thumb == Rectangle(x: 0, y: 72, width: 13, height: 24))
    #expect(ScrollBar.trackCap(of: sources.track) == 24)

    // A height that doesn't divide by four rounds the thumb's quarter down.
    let uneven = ScrollBar.packedSources(of: art(13, 98))
    #expect(uneven.thumb.height == 24)
    #expect(uneven.track.height == 74)
    #expect(ScrollBar.trackCap(of: uneven.track) == 24)

    // The track's ends keep their 24 rows, and its middle stretches.
    let slices = ScrollBar.slices(
        source: sources.track,
        box: Rectangle(x: 182, y: 9, width: 13, height: 182),
        cap: ScrollBar.trackCap(of: sources.track)
    )
    #expect(slices.map(\.to.height) == [24, 134, 24])
    #expect(slices.map(\.from.y) == [0, 24, 48])
}

@Test func theWholePackedColumnBelongsToTheBar() throws {
    var bar = gizmo()
    let middle = ScrollBar.Position(first: 5, last: 10, shown: 5)
    let geometry = try #require(bar.geometry(in: packedBounds, position: middle))

    // Beside the narrower track, the column still pages toward the pointer.
    #expect(ScrollBar.part(at: Vector2(x: 179, y: 150), in: geometry) == .pageDown)
    #expect(ScrollBar.part(at: Vector2(x: 179, y: 30), in: geometry) == .pageUp)
    #expect(ScrollBar.part(at: Vector2(x: 188, y: 100), in: geometry) == .thumb)
    #expect(ScrollBar.part(at: Vector2(x: 179, y: 4), in: geometry) == .up)
    #expect(ScrollBar.part(at: Vector2(x: 177, y: 100), in: geometry) == nil)

    // Dragging moves the fixed thumb over the track less its own height: 158 pixels for 10 lines.
    _ = bar.update(pointer: Vector2(x: 188, y: 90), isPressed: true, isDown: true, time: 0, in: packedBounds, position: middle)
    let dragged = bar.update(pointer: Vector2(x: 188, y: 90 + 79), isPressed: false, isDown: true, time: 0.1, in: packedBounds, position: middle)
    #expect(dragged == (true, 10))
}

@Test func aPackedBarWithoutItsSliderFallsBackToTheClassicTrackAndThumb() throws {
    let geometry = try #require(gizmo(slider: false).geometry(in: packedBounds, position: .init(first: 0, last: 10, shown: 5)))

    #expect(geometry.track == Rectangle(x: 181, y: 9, width: 15, height: 182))
    // The classic thumb shows how much is visible: 182 * 5 / 15.
    #expect(geometry.thumb.height == 60)
}

@Test func aPackedBarWithoutArrowArtDrawsClassicArrowsAcrossIt() throws {
    let geometry = try #require(gizmo(arrows: false).geometry(in: packedBounds, position: .init(first: 0, last: 10, shown: 5)))

    #expect(geometry.up == Rectangle(x: 186, y: 1, width: 13, height: 15))
    #expect(geometry.track.y == 16)
}

@Test func aViewSizesAPackedBarFromItsArt() throws {
    let appearance = try Appearance(data: Data("""
        <Appearance>
          <Image name='up' assetID='0x0000031200000001' stateCount='4'/>
          <Image name='down' assetID='0x0000031100000001' stateCount='4'/>
          <Image name='bar' assetID='0x0000031000000001'/>
          <ScrollBar up='up' down='down' slider='bar'/>
        </Appearance>
        """.utf8))
    let script = try UIScript(data: Data("""
        <UIScript version="1"><Window width="400" height="300"/>
          <List name="lots" x="0" y="0" width="200" height="200"/>
        </UIScript>
        """.utf8), appearance: appearance)
    let view = UIView(script: script, loadImage: { resource in
        resource.assetID == "0x0000031000000001" ? texture(13, 96) : texture(84, 8)
    })
    view.list(named: "lots")?.items = (0..<40).map { "Lot \($0)" }

    let geometry = try #require(view.list(named: "lots")?.scrollBarGeometry(in: packedBounds))
    #expect(geometry.bar.width == 21)
    #expect(geometry.up.width == 21 && geometry.up.height == 8)
    #expect(geometry.thumb.height == 24)
}
