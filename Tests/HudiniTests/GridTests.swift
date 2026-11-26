// Grids: items of one size, pictures, colors, or plain tiles, in rows that wrap and scroll. These
// read documents and run without a window.

import Foundation
@testable import Hudini
import Raylib
import Testing

private let box = "x='0' y='0' width='100' height='60'"
private let cells = "itemWidth='28' itemHeight='24'"

private func script(_ body: String, appearance: Appearance? = nil) throws -> UIScript {
    try UIScript(
        data: Data("<UIScript>\n<Window width='200' height='100'/>\n\(body)\n</UIScript>".utf8),
        appearance: appearance
    )
}

// MARK: Reading grids

@Test func aGridReadsItsCellsAndItsItemsInOrder() throws {
    let loaded = try script("""
    <String name='blueName' table='1' index='1'/>
    <String name='tip' table='1' index='2'/>
    <Image name='earthset' path='earthset.png'/>
    <Grid name='g' \(box) itemWidth='96' itemHeight='72' spacing='12' titles='selected'>
      <Item name='earth' image='earthset' title='Earthset' tooltip='tip'/>
      <Item name='blue' color='#3584E4' string='blueName'/>
      <Item title='Plain'/>
    </Grid>
    """)

    let control = try #require(loaded.control(named: "g"))
    #expect(control.type == .grid)
    #expect(control.grid == UIScript.Grid(
        itemSize: .init(width: 96, height: 72),
        spacing: 12,
        titles: .selected,
        items: [
            .init(name: "earth", title: .literal("Earthset"), content: .image("earthset"), tooltip: "tip"),
            .init(name: "blue", title: .string("blueName"), content: .color(Color(r: 0x35, g: 0x84, b: 0xE4, a: 0xFF))),
            .init(title: .literal("Plain"), content: .plain),
        ]
    ))
    #expect(loaded.ignoredAttributes.isEmpty)
}

@Test func aGridDefaultsToSpacingOf8AndTitlesBelow() throws {
    let grid = try #require(try script("<Grid name='g' \(box) \(cells)/>").control(named: "g")?.grid)

    #expect(grid.spacing == 8)
    #expect(grid.titles == .below)
    #expect(grid.items.isEmpty)
}

@Test func onlyAGridReadsGridAttributes() throws {
    let loaded = try script("<List name='l' \(box) \(cells) titles='none'/>")

    #expect(loaded.control(named: "l")?.grid == nil)
    #expect(loaded.ignoredAttributes.map(\.attribute) == ["itemHeight", "itemWidth", "titles"])
}

@Test func anItemListsItsUnknownAttributes() throws {
    let loaded = try script("<Grid name='g' \(box) \(cells)>\n<Item title='A' shape='star'/>\n</Grid>")

    #expect(loaded.ignoredAttributes == [.init(element: "Item", attribute: "shape", line: 4)])
}

@Test func aGridMayBeInATabOrAPane() throws {
    let loaded = try script("""
    <ToolbarItem name='a' title='A' tab='t'/>
    <Tab name='t'>
      <Grid name='inTab' \(box) \(cells)><Item title='One'/></Grid>
    </Tab>
    <Sidebar name='s' width='80'/>
    <Pane name='p' title='P'>
      <Grid name='inPane' \(box) \(cells)><Item title='Two'/></Grid>
    </Pane>
    """)

    #expect(loaded.tabs.first?.contents == ["inTab"])
    #expect(loaded.sidebar?.panes.first?.contents == ["inPane"])
    #expect(loaded.control(named: "inTab")?.grid?.items.count == 1)
    #expect(loaded.control(named: "inPane")?.grid?.items.count == 1)
}

@Test func gridIsInHudinisSubset() {
    #expect(!UIScript.elementsOutsideSubset.contains("Grid"))
}

// MARK: Refusing grids

@Test(arguments: [
    ("itemHeight='24'", "itemWidth"),
    ("itemWidth='28'", "itemHeight"),
])
func aGridNeedsItsCellSize(attributes: String, missing: String) {
    #expect(throws: UIScriptError.missingAttribute(element: "Grid", attribute: missing, line: 3)) {
        try script("<Grid name='g' \(box) \(attributes)/>")
    }
}

@Test(arguments: [
    ("itemWidth='0' itemHeight='24'", "itemWidth", "0"),
    ("itemWidth='28' itemHeight='-1'", "itemHeight", "-1"),
    ("\(cells) spacing='-2'", "spacing", "-2"),
    ("\(cells) titles='above'", "titles", "above"),
])
func aGridRefusesValuesItCantUse(attributes: String, attribute: String, value: String) {
    #expect(throws: UIScriptError.invalidAttribute(element: "Grid", attribute: attribute, value: value, line: 3)) {
        try script("<Grid name='g' \(box) \(attributes)/>")
    }
}

@Test func aGridHoldsOnlyItems() {
    #expect(throws: UIScriptError.invalidChild("Text", parent: "Grid", line: 4)) {
        try script("<Grid name='g' \(box) \(cells)>\n<Text name='t' \(box)/>\n</Grid>")
    }
    #expect(throws: UIScriptError.unexpectedNesting("Item", line: 5)) {
        try script("<Grid name='g' \(box) \(cells)>\n<Item title='A'>\n<Item title='B'/>\n</Item>\n</Grid>")
    }
}

@Test func anItemBelongsOnlyInAGrid() {
    #expect(throws: UIScriptError.itemOutsideGrid(line: 3)) {
        try script("<Item title='A'/>")
    }
    #expect(throws: UIScriptError.itemOutsideGrid(line: 5)) {
        try script("<ToolbarItem name='a' title='A' tab='t'/>\n<Tab name='t'>\n<Item title='A'/>\n</Tab>")
    }
}

@Test func anItemShowsAnImageOrAColorButNotBoth() {
    let body = "<Image name='i' path='i.png'/>\n<Grid name='g' \(box) \(cells)>\n<Item image='i' color='#FFFFFF'/>\n</Grid>"
    #expect(throws: UIScriptError.conflictingAttributes(element: "Item", first: "image", second: "color", line: 5)) {
        try script(body)
    }
    #expect(throws: UIScriptError.conflictingAttributes(element: "Item", first: "title", second: "string", line: 5)) {
        try script("<String name='s' table='1' index='1'/>\n<Grid name='g' \(box) \(cells)>\n<Item title='A' string='s'/>\n</Grid>")
    }
    #expect(throws: UIScriptError.invalidAttribute(element: "Item", attribute: "color", value: "blue", line: 4)) {
        try script("<Grid name='g' \(box) \(cells)>\n<Item color='blue'/>\n</Grid>")
    }
}

@Test func anItemWithNothingToShowIsRefused() {
    #expect(throws: UIScriptError.emptyGridItem(grid: "g", line: 4)) {
        try script("<Grid name='g' \(box) \(cells)>\n<Item name='blank' tooltip='t'/>\n</Grid>")
    }
}

@Test func anItemsReferencesMustExist() {
    #expect(throws: UIScriptError.unknownReference(owner: "earth", property: "image", reference: "missing")) {
        try script("<Grid name='g' \(box) \(cells)><Item name='earth' image='missing'/></Grid>")
    }
    // An unnamed item is named for its place in its grid.
    #expect(throws: UIScriptError.unknownReference(owner: "item 2 of g", property: "string", reference: "missing")) {
        try script("<Grid name='g' \(box) \(cells)><Item title='A'/><Item string='missing'/></Grid>")
    }
    #expect(throws: UIScriptError.unknownReference(owner: "item 1 of g", property: "tooltip", reference: "missing")) {
        try script("<Grid name='g' \(box) \(cells)><Item title='A' tooltip='missing'/></Grid>")
    }
}

@Test func itemNamesAreUniqueAmongTheOtherNames() {
    #expect(throws: UIScriptError.duplicateName("blue")) {
        try script("<Text name='blue' \(box)/><Grid name='g' \(box) \(cells)><Item name='blue' title='Blue'/></Grid>")
    }
    #expect(throws: UIScriptError.duplicateName("blue")) {
        try script("""
        <Grid name='g' \(box) \(cells)><Item name='blue' title='A'/></Grid>
        <Grid name='h' \(box) \(cells)><Item name='blue' title='B'/></Grid>
        """)
    }
}

@Test func aGridNeedsASizeAndTakesNoImageOfItsOwn() {
    #expect(throws: UIScriptError.missingSize(owner: "g")) {
        try script("<Grid name='g' x='0' y='0' \(cells)/>")
    }
    #expect(throws: UIScriptError.invalidImage(owner: "g")) {
        try script("<Image name='i' path='i.png'/><Grid name='g' \(box) \(cells) image='i'/>")
    }
}

@Test func gridErrorsSayWhatAGridHolds() {
    #expect(UIScriptError.invalidChild("Text", parent: "Grid", line: 4).errorDescription
        == "UIScript line 4: a 'Grid' holds only 'Item's, not 'Text'.")
    #expect(UIScriptError.invalidChild("Image", parent: "Tab", line: 4).errorDescription
        == "UIScript line 4: a 'Tab' holds controls and visuals, not 'Image'.")
    #expect(UIScriptError.itemOutsideGrid(line: 2).errorDescription?.contains("only in a 'Grid'") == true)
    #expect(UIScriptError.emptyGridItem(grid: "g", line: 2).errorDescription?.contains("grid 'g'") == true)
}

// MARK: Grids and appearances

@Test func aGridTakesItsItemImagesAndScrollBarFromAnAppearance() throws {
    let shared = try Appearance(data: Data("""
    <Appearance>
      <Image name='earthset' path='earthset.png'/>
      <Image name='thumb' path='thumb.png'/>
      <ScrollBar thumb='thumb'/>
    </Appearance>
    """.utf8))

    let loaded = try script("<Grid name='g' \(box) \(cells)><Item image='earthset'/></Grid>", appearance: shared)

    #expect(loaded.resources.images["earthset"]?.path == "earthset.png")
    #expect(loaded.scrollBar?.thumb == "thumb")
    #expect(loaded.resources.images["thumb"] != nil)
}

// MARK: Grids in a view

// Cells 28 by 24 with the default spacing, and titles under them in the body size, 14: five
// columns of 36 pixels and rows of 50 fit a 200 by 100 grid.
private let viewBody = """
<String name='tealName' table='1' index='1'/>
<String name='tealTip' table='1' index='2'/>
<String name='gridTip' table='1' index='3'/>
<Image name='earthset' path='earthset.png'/>
<Grid name='g' x='0' y='0' width='200' height='100' \(cells) tooltip='gridTip'>
  <Item name='blue' color='#3584E4' title='Blue'/>
  <Item name='teal' color='#2190A4' string='tealName' tooltip='tealTip'/>
  <Item image='earthset' title='Earthset'/>
  <Item title='Plain'/>
</Grid>
"""

private func gridView(_ body: String = viewBody, theme: InterfaceTheme = .standard) throws -> UIView {
    UIView(script: try script(body), theme: theme, resolveString: { resource in
        ["1": "Teal", "2": "The accent", "3": "Pick one"][String(resource.index)]
    })
}

// The middle of the cell at this row and column.
private func cellMiddle(row: Int, column: Int) -> Vector2 {
    Vector2(x: 3 + Float(column) * 36 + 14, y: 3 + Float(row) * 50 + 12)
}

@Test func aViewMakesAGridFromItsDocument() throws {
    let grid = try #require(try gridView().grid(named: "g"))

    #expect(grid.items.map(\.name) == ["blue", "teal", nil, nil])
    #expect(grid.items.map(\.title) == ["Blue", "Teal", "Earthset", "Plain"])
    #expect(grid.items.map(\.tooltip) == [nil, "The accent", nil, nil])
    #expect(grid.itemSize == Vector2(x: 28, y: 24))
    #expect(grid.spacing == 8)
    #expect(grid.titles == .below)
    // Without a loader, the picture is missing.
    guard case .image(nil, _) = grid.items[2].content, case .plain = grid.items[3].content,
          case let .color(color) = grid.items[0].content else {
        Issue.record("The items' content isn't what the document lists.")
        return
    }
    #expect(color == Color(r: 0x35, g: 0x84, b: 0xE4, a: 0xFF))
}

@Test func aGridItemsMissingStringShowsItsTableAndIndex() throws {
    let view = UIView(script: try script(viewBody))

    #expect(view.grid(named: "g")?.items[1].title == "1#1")
    #expect(view.grid(named: "g")?.items[1].tooltip == nil)
    #expect(view.missingStrings == ["gridTip", "tealName", "tealTip"])
}

@Test func choosingAGridItemReportsItsName() throws {
    let view = try gridView()

    #expect(view.selectItem(at: cellMiddle(row: 0, column: 1), origin: .zero, time: 0)
        == .selected(control: "g", index: 1, item: "teal"))
    #expect(view.selectItem(at: cellMiddle(row: 0, column: 1), origin: .zero, time: 0.2)
        == .submittedItem(control: "g", index: 1, item: "teal"))
    #expect(view.selectItem(at: cellMiddle(row: 0, column: 2), origin: .zero, time: 1)
        == .selected(control: "g", index: 2, item: nil))
    #expect(view.selectItem(at: Vector2(x: 150, y: 80), origin: .zero, time: 2) == nil)
    #expect(view.grid(named: "g")?.selectedIndex == 2)
}

@Test func aHostsOwnItemsReportTheirNames() throws {
    let view = try gridView()
    let grid = try #require(view.grid(named: "g"))

    grid.items = [.init(name: "mine", title: "Mine", content: view.gridPicture(named: "earthset"))]

    #expect(view.selectItem(at: cellMiddle(row: 0, column: 0), origin: Vector2.zero, time: 0)
        == .selected(control: "g", index: 0, item: "mine"))
    guard case .image(nil, _) = view.gridPicture(named: "nothing") else {
        Issue.record("An unknown image should be a missing picture.")
        return
    }
}

@Test func aGridInATabThatIsntShowingTakesNoClicks() throws {
    let view = try gridView("""
    <ToolbarItem name='aTab' title='A' tab='a'/>
    <ToolbarItem name='bTab' title='B' tab='b'/>
    <Tab name='a'/>
    <Tab name='b'><Grid name='g' x='0' y='0' width='200' height='100' \(cells)><Item title='One'/></Grid></Tab>
    """)

    #expect(view.selectItem(at: cellMiddle(row: 0, column: 0), origin: .zero, time: 0) == nil)
    view.setSelected(true, named: "bTab")
    #expect(view.selectItem(at: cellMiddle(row: 0, column: 0), origin: .zero, time: 1)
        == .selected(control: "g", index: 0, item: nil))
}

@Test func aGridsScrollBarIsItsOwn() throws {
    let items = (0..<24).map { "<Item title='\($0)'/>" }.joined()
    let view = try gridView("<Grid name='g' x='0' y='0' width='200' height='100' \(cells)>\(items)</Grid>")
    let bar = try #require(view.grid(named: "g")?.scrollBarGeometry(in: Rectangle(x: 0, y: 0, width: 200, height: 100))).bar

    #expect(view.scrollBarControl(at: Vector2(x: bar.x + 2, y: 50), origin: .zero) == "g")
    #expect(view.scrollBarControl(at: cellMiddle(row: 0, column: 0), origin: .zero) == nil)
}

@Test func anItemsTooltipWinsOverItsGrids() throws {
    let view = try gridView()

    view.updateTooltip(pointer: cellMiddle(row: 0, column: 1), origin: .zero, elapsed: 1)
    #expect(view.pendingTooltip == "g")
    #expect(view.pendingTooltipItem == 1)

    // Moving to another item starts the wait again, and an item without one shows the grid's.
    view.updateTooltip(pointer: cellMiddle(row: 0, column: 0), origin: .zero, elapsed: 0.1)
    #expect(view.pendingTooltip == nil)
    view.updateTooltip(pointer: cellMiddle(row: 0, column: 0), origin: .zero, elapsed: 1)
    #expect(view.pendingTooltip == "g")
    #expect(view.pendingTooltipItem == nil)
}

@Test func aGridWithoutTitlesShowsAnItemsTitleAsItsTooltip() throws {
    let view = try gridView("<Grid name='g' x='0' y='0' width='200' height='100' \(cells) titles='none'><Item color='#FFFFFF' title='White'/></Grid>")

    view.updateTooltip(pointer: cellMiddle(row: 0, column: 0), origin: .zero, elapsed: 1)
    #expect(view.pendingTooltipItem == 0)
    #expect(view.grid(named: "g")?.tooltip(forItem: 0) == "White")
}

@Test func aGridFollowsItsStyleAndTheViewsTheme() throws {
    let view = try gridView("""
    <Style name='big' fontSize='20' textColor='#FF0000'/>
    <Grid name='g' x='0' y='0' width='200' height='100' \(cells) style='big'/>
    <Grid name='plain' x='0' y='0' width='200' height='100' \(cells)/>
    """)
    let styled = try #require(view.grid(named: "g"))
    let plain = try #require(view.grid(named: "plain"))

    #expect(styled.fontSize == 20)
    #expect(styled.textColor == Color(r: 255, g: 0, b: 0, a: 255))
    view.theme = .depot
    #expect(styled.fontSize == 20)
    #expect(plain.theme.cornerRadius == InterfaceTheme.depot.cornerRadius)
    #expect(plain.textColor == InterfaceTheme.depot.text)
}

@Test func aGridTakesItsAppearancesScrollBarWidth() throws {
    let shared = try Appearance(data: Data("<Appearance><ScrollBar width='20'/></Appearance>".utf8))
    let items = (0..<24).map { "<Item title='\($0)'/>" }.joined()
    let view = UIView(script: try script("<Grid name='g' x='0' y='0' width='200' height='100' \(cells)>\(items)</Grid>", appearance: shared))

    let bar = try #require(view.grid(named: "g")?.scrollBarGeometry(in: Rectangle(x: 0, y: 0, width: 200, height: 100))).bar
    #expect(bar.width == 20)
}
