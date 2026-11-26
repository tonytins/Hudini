// Tabs, which toolbar items switch, and panes, which a sidebar's rows switch. These run without a
// window: they read documents and check which controls a view shows.

import Foundation
@testable import Hudini
import Raylib
import Testing

private let box = "x='0' y='0' width='10' height='10'"

private func script(_ body: String) throws -> UIScript {
    try UIScript(data: Data("<UIScript>\n<Window width='100' height='80'/>\n\(body)\n</UIScript>".utf8))
}

private let tabbed = """
<Image name='logo' path='logo.png'/>
<ToolbarItem name='cityTab' title='City' tab='city'/>
<ToolbarItem name='refresh' title='Refresh'/>
<ToolbarItem name='lawsTab' title='Ordinances' tab='laws'/>
<Text name='always' \(box)/>
<Tab name='city'>
  <Text name='population' \(box)/>
  <Visual name='badge' image='logo' \(box)/>
</Tab>
<Tab name='laws'>
  <Button name='curfew' \(box)/>
</Tab>
"""

private let paned = """
<Sidebar name='places' width='120'/>
<Pane name='general' title='General'>
  <TextField name='name' \(box)/>
</Pane>
<Pane name='advanced' title='Advanced'/>
<Button name='reset' \(box) pane='advanced'/>
<Text name='always' \(box)/>
"""

// MARK: Reading tabs

@Test func tabsHoldTheirControlsAndVisualsAndItemsNameThem() throws {
    let loaded = try script(tabbed)

    #expect(loaded.tabs == [
        .init(name: "city", contents: ["population", "badge"]),
        .init(name: "laws", contents: ["curfew"]),
    ])
    #expect(loaded.toolbarItems.map(\.tab) == ["city", nil, "laws"])
    // Controls stay in document order, whether or not they're in a tab.
    #expect(loaded.controls.map(\.name) == ["always", "population", "curfew"])
    #expect(loaded.ignoredAttributes.isEmpty)
}

@Test func aTabMayHoldNothing() throws {
    let loaded = try script("<ToolbarItem name='mapTab' title='Map' tab='map'/><Tab name='map'/>")

    #expect(loaded.tabs == [.init(name: "map", contents: [])])
}

@Test func eachTabNeedsExactlyOneItemNamingIt() {
    #expect(throws: UIScriptError.tabWithoutItem("map")) {
        try script("<Tab name='map'/>")
    }
    #expect(throws: UIScriptError.tabWithSeveralItems("map")) {
        try script("<ToolbarItem name='a' title='A' tab='map'/><ToolbarItem name='b' title='B' tab='map'/><Tab name='map'/>")
    }
    #expect(throws: UIScriptError.unknownReference(owner: "a", property: "tab", reference: "map")) {
        try script("<ToolbarItem name='a' title='A' tab='map'/>")
    }
}

@Test func tabsOnlyNest() {
    // A control naming a tab would read as one on every tab in a reader that ignored it.
    #expect(throws: UIScriptError.tabAttributeOnControl(owner: "b", line: 5)) {
        try script("<ToolbarItem name='a' title='A' tab='map'/>\n<Tab name='map'/>\n<Button name='b' \(box) tab='map'/>")
    }
}

@Test func aTabHoldsOnlyControlsAndVisuals() {
    let item = "<ToolbarItem name='a' title='A' tab='t'/>\n"
    #expect(throws: UIScriptError.invalidChild("Image", parent: "Tab", line: 5)) {
        try script(item + "<Tab name='t'>\n<Image name='i' path='i.png'/>\n</Tab>")
    }
    #expect(throws: UIScriptError.invalidChild("Tab", parent: "Tab", line: 5)) {
        try script(item + "<Tab name='t'>\n<Tab name='u'/>\n</Tab>")
    }
    #expect(throws: UIScriptError.unexpectedNesting("Text", line: 6)) {
        try script(item + "<Tab name='t'>\n<Button name='b' \(box)>\n<Text name='c' \(box)/>\n</Button>\n</Tab>")
    }
}

@Test func tabAndPaneNamesAreUniqueAmongTheOtherNames() {
    #expect(throws: UIScriptError.duplicateName("city")) {
        try script("<ToolbarItem name='a' title='A' tab='city'/><Tab name='city'/><Text name='city' \(box)/>")
    }
    #expect(throws: UIScriptError.duplicateName("population")) {
        try script(tabbed + "<Text name='population' \(box)/>")
    }
    #expect(throws: UIScriptError.duplicateName("general")) {
        try script(paned + "<Text name='general' \(box)/>")
    }
}

@Test func aPanelRefusesTabsSidebarsAndPanes() {
    for element in ["<Tab name='t'/>", "<Sidebar name='s' width='9'/>", "<Pane name='p' title='P'/>"] {
        #expect(throws: UIScriptError.self) {
            try UIScript(data: Data("<UIScript><Panel width='9' height='9' edge='top'/>\(element)</UIScript>".utf8))
        }
    }
    #expect(throws: UIScriptError.notAllowedInPanel("Tab", line: 1)) {
        try UIScript(data: Data("<UIScript><Panel width='9' height='9' edge='top'/><Tab name='t'/></UIScript>".utf8))
    }
}

// MARK: Reading a sidebar of panes

@Test func aSidebarOfPanesReadsBothFormsOfPane() throws {
    let loaded = try script(paned)

    let sidebar = try #require(loaded.sidebar)
    #expect(sidebar.name == "places")
    #expect(sidebar.width == 120)
    #expect(sidebar.panes == [
        .init(name: "general", title: "General", contents: ["name"]),
        .init(name: "advanced", title: "Advanced", contents: ["reset"]),
    ])
    #expect(loaded.ignoredAttributes.isEmpty)
    #expect(try script("").sidebar == nil)
}

@Test func aSidebarsEdgeIsIgnoredAndListed() throws {
    // The spec lets a reader without `edge` draw the sidebar on the left.
    let loaded = try script("<Sidebar name='s' width='9' edge='right'/><Pane name='p' title='P'/>")

    #expect(loaded.ignoredAttributes.map(\.attribute) == ["edge"])
}

@Test func onlyASidebarOfPanesIsInTheSubset() {
    // Rows the host fills.
    #expect(throws: UIScriptError.unsupportedSidebar(line: 3)) {
        try script("<Sidebar name='s' width='9'/>")
    }
    // A sidebar that holds controls of its own.
    #expect(throws: UIScriptError.unsupportedSidebar(line: 3)) {
        try script("<Sidebar name='s' width='9'>\n<Button name='b' \(box)/>\n</Sidebar>")
    }
}

@Test func aSidebarNeedsAPositiveWidthAndComesOnce() {
    #expect(throws: UIScriptError.invalidAttribute(element: "Sidebar", attribute: "width", value: "0", line: 3)) {
        try script("<Sidebar name='s' width='0'/><Pane name='p' title='P'/>")
    }
    #expect(throws: UIScriptError.duplicateElement("Sidebar", line: 4)) {
        try script("<Sidebar name='s' width='9'/>\n<Sidebar name='t' width='9'/>")
    }
}

@Test func panesNeedASidebar() {
    #expect(throws: UIScriptError.panesWithoutSidebar(line: 3)) {
        try script("<Pane name='p' title='P'/>")
    }
    #expect(throws: UIScriptError.unknownReference(owner: "b", property: "pane", reference: "p")) {
        try script("<Button name='b' \(box) pane='p'/>")
    }
}

@Test func aPaneUsesOneFormOrTheOther() {
    #expect(throws: UIScriptError.paneUsesBothForms(pane: "p")) {
        try script("<Sidebar name='s' width='9'/><Pane name='p' title='P'><Text name='a' \(box)/></Pane><Button name='b' \(box) pane='p'/>")
    }
    #expect(throws: UIScriptError.unknownReference(owner: "b", property: "pane", reference: "q")) {
        try script("<Sidebar name='s' width='9'/><Pane name='p' title='P'/><Button name='b' \(box) pane='q'/>")
    }
}

@Test func aControlSitsInOneTabOrPaneAtMost() {
    #expect(throws: UIScriptError.containedControlNamesPane(owner: "b", line: 4)) {
        try script("<Sidebar name='s' width='9'/><Pane name='p' title='P'/><Pane name='q' title='Q'>\n<Button name='b' \(box) pane='p'/></Pane>")
    }
    #expect(throws: UIScriptError.containedControlNamesPane(owner: "b", line: 4)) {
        try script("<Sidebar name='s' width='9'/><Pane name='p' title='P'/><ToolbarItem name='a' title='A' tab='t'/><Tab name='t'>\n<Button name='b' \(box) pane='p'/></Tab>")
    }
}

@Test func tabsAndPanesShareADocument() throws {
    let loaded = try script(paned + "<ToolbarItem name='a' title='A' tab='t'/><Tab name='t'><Text name='inTab' \(box)/></Tab>")

    #expect(loaded.tabs.map(\.name) == ["t"])
    #expect(loaded.sidebar?.panes.count == 2)
}

@Test func aNestedMenuIsRefusedAsOutsideTheSubsetRatherThanAsNesting() {
    #expect(throws: UIScriptError.unknownElement("Menu", line: 3)) {
        try script("<Menu name='file' title='File'>\n<MenuItem name='open' title='Open'/>\n</Menu>")
    }
}

// MARK: What a view shows

@Test func aViewShowsTheFirstTabAndHoldsItsItem() throws {
    let view = UIView(script: try script(tabbed))

    #expect(view.isShown("always"))
    #expect(view.isShown("population"))
    #expect(view.isShown("badge"))
    #expect(!view.isShown("curfew"))
    #expect(view.isSelected(named: "cityTab"))
    #expect(!view.isSelected(named: "lawsTab"))
    // Being outside the selected tab isn't the host hiding it.
    #expect(!view.isHidden(named: "curfew"))
}

@Test func aViewShowsTheFirstPane() throws {
    let view = UIView(script: try script(paned))

    #expect(view.isShown("name"))
    #expect(!view.isShown("reset"))
    #expect(view.isShown("always"))
}

@Test func aControlTheHostHidStaysHiddenInTheSelectedTab() throws {
    let view = UIView(script: try script(tabbed))

    view.setHidden(true, named: "population")
    #expect(!view.isShown("population"))
    view.setHidden(false, named: "population")
    #expect(view.isShown("population"))
}
