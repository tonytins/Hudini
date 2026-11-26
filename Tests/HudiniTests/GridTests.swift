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
