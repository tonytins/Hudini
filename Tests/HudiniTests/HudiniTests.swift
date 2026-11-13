// These run without a window. Measuring text needs the font a window loads, so the checks
// here stay with what doesn't draw: the camera's math and what the text boxes accept.

import Foundation
@testable import Hudini
import Raylib
import SwiftCST
import Testing

@Test func cameraRoundTripsBetweenScreenAndWorld() {
    let camera = Hudini.ViewportCamera(zoom: 2)
    camera.resize(to: Vector2(x: 800, y: 600))
    camera.center(on: Vector2(x: 100, y: 50))
    let screen = Vector2(x: 123, y: 456)
    let back = camera.screenPoint(forWorldPoint: camera.worldPoint(forScreenPoint: screen))
    #expect(abs(back.x - screen.x) < 0.001 && abs(back.y - screen.y) < 0.001)
    #expect(camera.screenPoint(forWorldPoint: Vector2(x: 100, y: 50)) == Vector2(x: 400, y: 300))
}

@Test func cameraZoomStaysInItsRange() {
    let camera = Hudini.ViewportCamera(zoom: 100)
    #expect(camera.zoom == Hudini.ViewportCamera.maxZoom)
    camera.zoom(to: 0)
    #expect(camera.zoom == Hudini.ViewportCamera.minZoom)
}

@Test func cameraZoomKeepsThePointUnderThePointerStill() {
    let camera = Hudini.ViewportCamera()
    camera.resize(to: Vector2(x: 800, y: 600))
    let pointer = Vector2(x: 200, y: 100)
    let before = camera.worldPoint(forScreenPoint: pointer)
    camera.zoom(at: pointer, by: 1)
    let after = camera.worldPoint(forScreenPoint: pointer)
    #expect(abs(before.x - after.x) < 0.001 && abs(before.y - after.y) < 0.001)
}

@Test func cameraCentersAWorldSmallerThanTheScreen() {
    let camera = Hudini.ViewportCamera()
    camera.resize(to: Vector2(x: 800, y: 600))
    camera.constrain(to: Vector2(x: 200, y: 100))
    #expect(camera.centerPoint == Vector2(x: 100, y: 50))
}

@Test func textFieldTakesOnlyWhatItAccepts() {
    let digits = TextField(text: "a1b2c3", maximumLength: 4, accepting: { $0.isNumber })
    #expect(digits.text == "123")
    let short = TextField(text: "abcdef", maximumLength: 3)
    #expect(short.text == "abc")
    // Raylib's default font draws printable ASCII only.
    let ascii = TextField(text: "héllo~\u{7F}", maximumLength: 10)
    #expect(ascii.text == "hllo~")
}

@Test func textFieldSubmitsExactTextAndKeepsWhitespaceOnlyDrafts() {
    let field = TextField(text: "  Hello!  ", maximumLength: 32)
    #expect(field.submit() == .submitted("  Hello!  "))
    #expect(field.text.isEmpty)

    field.text = "   "
    #expect(field.submit() == nil)
    #expect(field.text == "   ")
}

@Test func textAreaKeepsItsLimit() {
    let area = TextArea(text: "one two three", maximumLength: 7, fontSize: 20)
    #expect(area.text == "one two")
}

@Test func windowContentSitsBelowTheTitleBar() {
    let content = WindowFrame.content(in: Rectangle(x: 10, y: 20, width: 300, height: 200))
    #expect(content == Rectangle(x: 10, y: 20 + Float(WindowFrame.titleHeight), width: 300, height: 200 - Float(WindowFrame.titleHeight)))
    let tiny = WindowFrame.content(in: Rectangle(x: 0, y: 0, width: 50, height: 10))
    #expect(tiny.height == 0)
}

@Test func windowTitlesCanBeRenamed() {
    let frame = WindowFrame(title: "Lot")
    frame.title = "Neighborhood"
    #expect(frame.title == "Neighborhood")
    #expect(!frame.isEditingTitle)
}

@Test func windowWithoutACloseButtonFreesItsRoom() {
    let bounds = Rectangle(x: 100, y: 100, width: 300, height: 200)
    let onCloseButton = Vector2(x: 112, y: 115)
    let frame = WindowFrame(title: "Start Game")

    #expect(frame.isCloseButton(at: onCloseButton, in: bounds))
    #expect(!frame.beginDragging(at: onCloseButton, within: bounds))
    let titleWithButton = frame.titleBounds(bounds)

    frame.showsCloseButton = false
    #expect(!frame.isCloseButton(at: onCloseButton, in: bounds))
    let titleWithoutButton = frame.titleBounds(bounds)
    #expect(titleWithoutButton.x < titleWithButton.x)
    #expect(titleWithoutButton.width > titleWithButton.width)
    // The spot the button would hold drags the window like the rest of the bar.
    #expect(frame.beginDragging(at: onCloseButton, within: bounds))
}

@Test func interfaceThemeSupportsOverridesAndStandardDefaults() {
    let standard = InterfaceTheme.standard
    let customAccent = Color(r: 190, g: 145, b: 255, a: 255)
    let custom = InterfaceTheme(accent: customAccent)

    #expect(standard.accent == Color(r: 240, g: 190, b: 90, a: 255))
    #expect(custom.accent == customAccent)
    #expect(custom.panel == standard.panel)
}

// UIScript documents in these tests use single-quoted attributes, which keeps them readable in Swift strings.

private func demoResource(_ name: String) -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("../../Demo/Sources/hudini-demo/Resources/\(name)")
        .standardizedFileURL
}

private let tenByTen = "x='0' y='0' width='10' height='10'"

private func document(_ body: String, root: String = "") -> Data {
    Data("<UIScript \(root)><Window width='100' height='80'/>\(body)</UIScript>".utf8)
}

private func script(_ body: String, root: String = "") throws -> UIScript {
    try UIScript(data: document(body, root: root))
}

private func stubTexture(width: Int32, height: Int32) -> Texture2D {
    var texture = Texture2D()
    texture.width = width
    texture.height = height
    return texture
}

@Test func uiScriptReadsResourcesStylesVisualsAndControls() throws {
    let loaded = try UIScript(data: Data("""
    <?xml version="1.0" encoding="UTF-8"?>
    <!-- Comments are welcome anywhere. -->
    <UIScript version="1">
      <Window width="500" height="255" minWidth="350" minHeight="196"/>
      <Image name="scrollbar" path="ui/scrollbar.bmp" assetID="0x0000031000000001"/>
      <String name="sendTooltip" table="UIText" index="5"/>
      <Style name="chatEntry" textColor="#FFF99D" fontSize="8"/>
      <Visual name="chatBackground" image="scrollbar" x="19" y="39" width="341" height="166"/>
      <TextField name="chatEntry" legacyID="5" x="52" y="216" width="299" height="17"
                 edgeOffsetLeft="38" edgeOffsetRight="67" edgeOffsetBottom="22"
                 style="chatEntry" placeholder="Type a message" tooltip="sendTooltip"/>
      <Button name="send" x="360" y="210" width="24" height="24" image="scrollbar" string="sendTooltip"/>
    </UIScript>
    """.utf8))

    #expect(loaded.version == 1)
    #expect(loaded.window.size.width == 500)
    #expect(loaded.window.minSize?.height == 196)
    #expect(loaded.resources.images["scrollbar"]?.path == "ui/scrollbar.bmp")
    #expect(loaded.resources.images["scrollbar"]?.assetID == "0x0000031000000001")
    #expect(loaded.resources.strings["sendTooltip"]?.index == 5)
    #expect(loaded.styles["chatEntry"]?.fontSize == 8)
    #expect(loaded.visuals.first?.name == "chatBackground")
    #expect(loaded.controls[0].type == .textField)
    #expect(loaded.controls[0].legacyID == 5)
    #expect(loaded.controls[0].frame.edgeOffsets?.right == 67)
    #expect(loaded.controls[0].tooltip == "sendTooltip")
    #expect(loaded.controls[0].placeholder == .literal("Type a message"))
    #expect(loaded.controls[1].text == .string("sendTooltip"))
    #expect(loaded.ignoredAttributes.isEmpty)
}

// MARK: Compatibility

@Test func uiScriptVersionDefaultsToTheFirst() throws {
    #expect(try script("").version == 1)
}

@Test func uiScriptRefusesNewerVersionsBeforeReadingTheirContents() {
    #expect(throws: UIScriptError.unsupportedVersion(2)) {
        try script("<FutureThing/>", root: "version='2'")
    }
}

@Test(arguments: ["0", "-1", "two"])
func uiScriptRejectsInvalidVersions(version: String) {
    #expect(throws: UIScriptError.self) {
        try script("", root: "version='\(version)'")
    }
}

@Test func uiScriptRefusesModulesItDoesNotImplement() {
    #expect(throws: UIScriptError.unsupportedFeature("menus")) {
        try script("<Menu/>", root: "requires='menus'")
    }
}

@Test func unsupportedModuleMessageNamesTheModuleWithoutSuggestingAnUpdate() {
    // A module is optional, so a newer Hudini may not implement it either.
    let message = UIScriptError.unsupportedFeature("menus").localizedDescription

    #expect(message.contains("'menus' module"))
    #expect(!message.contains("Update Hudini"))
}

@Test func uiScriptIgnoresAndReportsUnknownAttributes() throws {
    let loaded = try script("<Button name='a' \(tenByTen) textColour='#FFF' zeta='1' alpha='2'/>", root: "future='1'")

    #expect(loaded.controls.count == 1)
    #expect(loaded.ignoredAttributes.map(\.element) == ["UIScript", "Button", "Button", "Button"])
    #expect(loaded.ignoredAttributes.map(\.attribute) == ["future", "alpha", "textColour", "zeta"])
    #expect(loaded.ignoredAttributes.allSatisfy { $0.line == 1 })
}

@Test func uiScriptRejectsUnknownElements() {
    #expect(throws: UIScriptError.unknownElement("FutureControl", line: 1)) {
        try script("<FutureControl name='a' \(tenByTen)/>")
    }
}

// MARK: Malformed documents

@Test(arguments: ["", "not xml", "<UIScript>", "<UIScript><Window width=1 height=1/></UIScript>"])
func uiScriptRejectsMalformedXML(text: String) {
    #expect(throws: UIScriptError.self) {
        try UIScript(data: Data(text.utf8))
    }
}

@Test func uiScriptRefusesDoctypesSoEntitiesCannotExpand() {
    let entityBomb = """
    <!DOCTYPE UIScript [<!ENTITY a "aaaaaaaaaa"><!ENTITY b "&a;&a;&a;&a;&a;&a;&a;&a;">]>
    <UIScript><Window width="1" height="1"/><Text name="a" x="0" y="0" width="1" height="1" text="&b;"/></UIScript>
    """
    #expect(throws: UIScriptError.doctypeNotAllowed) {
        try UIScript(data: Data(entityBomb.utf8))
    }
}

@Test func uiScriptRefusesOtherEncodings() throws {
    let utf16 = try #require("<UIScript><Window width='1' height='1'/></UIScript>".data(using: .utf16))
    #expect(throws: UIScriptError.unsupportedEncoding) {
        try UIScript(data: utf16)
    }
}

@Test func uiScriptRejectsTheWrongRootElement() {
    #expect(throws: UIScriptError.invalidRoot("Html")) {
        try UIScript(data: Data("<Html/>".utf8))
    }
}

@Test func uiScriptRejectsNestedElementsAndStrayText() {
    #expect(throws: UIScriptError.unexpectedNesting("Text", line: 1)) {
        try script("<Button name='a' \(tenByTen)><Text name='b' \(tenByTen)/></Button>")
    }
    #expect(throws: UIScriptError.unexpectedText(line: 1)) {
        try script("<Button name='a' \(tenByTen)>Press me</Button>")
    }
}

@Test func uiScriptNeedsExactlyOneWindow() {
    #expect(throws: UIScriptError.missingElement("Window")) {
        try UIScript(data: Data("<UIScript/>".utf8))
    }
    #expect(throws: UIScriptError.duplicateElement("Window", line: 1)) {
        try script("<Window width='1' height='1'/>")
    }
}

@Test func uiScriptReportsMissingAndUnusableAttributes() {
    #expect(throws: UIScriptError.missingAttribute(element: "Button", attribute: "name", line: 1)) {
        try script("<Button \(tenByTen)/>")
    }
    #expect(throws: UIScriptError.missingAttribute(element: "Button", attribute: "x", line: 1)) {
        try script("<Button name='a' y='0' width='1' height='1'/>")
    }
    #expect(throws: UIScriptError.invalidAttribute(element: "Button", attribute: "x", value: "left", line: 1)) {
        try script("<Button name='a' x='left' y='0' width='1' height='1'/>")
    }
    #expect(throws: UIScriptError.invalidAttribute(element: "Button", attribute: "width", value: "nan", line: 1)) {
        try script("<Button name='a' x='0' y='0' width='nan' height='1'/>")
    }
    #expect(throws: UIScriptError.missingAttribute(element: "Window", attribute: "minHeight", line: 1)) {
        try UIScript(data: Data("<UIScript><Window width='9' height='9' minWidth='1'/></UIScript>".utf8))
    }
}

@Test func uiScriptReportsTheLineOfAProblem() {
    let lines = "<UIScript>\n<Window width='1' height='1'/>\n\n<Mystery/>\n</UIScript>"
    #expect(throws: UIScriptError.unknownElement("Mystery", line: 4)) {
        try UIScript(data: Data(lines.utf8))
    }
}

@Test func uiScriptRejectsLiteralAndReferencedTextTogether() {
    let strings = "<String name='s' table='t' index='1'/>"
    #expect(throws: UIScriptError.conflictingAttributes(element: "Text", first: "text", second: "string", line: 1)) {
        try script("\(strings)<Text name='a' \(tenByTen) text='hi' string='s'/>")
    }
}

// MARK: Values and references

@Test func uiScriptReadsHexColors() throws {
    let loaded = try script("<Style name='plain' textColor='#FFF99D'/><Style name='faded' textColor='#10203040'/>")

    #expect(loaded.styles["plain"]?.textColor == Color(r: 255, g: 249, b: 157, a: 255))
    #expect(loaded.styles["faded"]?.textColor == Color(r: 16, g: 32, b: 48, a: 64))
}

@Test(arguments: ["FFF99D", "#FFF", "#GGGGGG", "#+12345", "#FFF99D0", "", "#１２３４５６"])
func uiScriptRejectsInvalidColors(color: String) {
    #expect(throws: UIScriptError.invalidAttribute(element: "Style", attribute: "backgroundColor", value: color, line: 1)) {
        try script("<Style name='bad' backgroundColor='\(color)'/>")
    }
}

@Test(arguments: [0, -4])
func uiScriptRejectsNonpositiveFontSizes(fontSize: Int) {
    #expect(throws: UIScriptError.invalidFontSize(style: "bad")) {
        try script("<Style name='bad' fontSize='\(fontSize)'/>")
    }
}

@Test func uiScriptRejectsDuplicateNames() {
    let image = "<Image name='art' path='a.bmp'/>"
    #expect(throws: UIScriptError.duplicateName("twin")) {
        try script("<Text name='twin' \(tenByTen)/><Text name='twin' \(tenByTen)/>")
    }
    #expect(throws: UIScriptError.duplicateName("twin")) {
        try script("\(image)<Visual name='twin' image='art' \(tenByTen)/><Text name='twin' \(tenByTen)/>")
    }
    #expect(throws: UIScriptError.duplicateName("art")) {
        try script("\(image)\(image)")
    }
    #expect(throws: UIScriptError.duplicateName("look")) {
        try script("<Style name='look'/><Style name='look'/>")
    }
}

@Test func uiScriptLetsResourcesShareNamesWithControls() throws {
    let loaded = try script("<Image name='next' path='a.bmp'/><Button name='next' x='0' y='0' image='next'/>")

    #expect(loaded.control(named: "next")?.image == "next")
}

@Test func uiScriptRejectsMinimumSizeLargerThanWindow() {
    #expect(throws: UIScriptError.invalidMinimumWindowSize) {
        try UIScript(data: Data("<UIScript><Window width='100' height='80' minWidth='101' minHeight='80'/></UIScript>".utf8))
    }
}

@Test func uiScriptRejectsUnknownReferencesAndInvalidFrames() {
    #expect(throws: UIScriptError.unknownReference(owner: "ok", property: "style", reference: "missing")) {
        try script("<Button name='ok' \(tenByTen) style='missing'/>")
    }
    #expect(throws: UIScriptError.unknownReference(owner: "entry", property: "placeholder", reference: "missing")) {
        try script("<TextField name='entry' \(tenByTen) placeholderString='missing'/>")
    }
    #expect(throws: UIScriptError.invalidPlaceholder(owner: "button")) {
        try script("<Button name='button' \(tenByTen) placeholder='Invalid here'/>")
    }
    #expect(throws: UIScriptError.invalidFrame(owner: "bad")) {
        try script("<Text name='bad' x='0' y='0' width='-1' height='10'/>")
    }
}

@Test func uiScriptFindsAControlsStyle() throws {
    let loaded = try script("<Style name='label' fontSize='9'/><Text name='a' \(tenByTen) style='label'/>")
    let control = try #require(loaded.control(named: "a"))

    #expect(loaded.style(for: control)?.fontSize == 9)
    #expect(loaded.control(named: "missing") == nil)
}

private func scrollDocument(_ scroller: String) -> String {
    "<List name='history' \(tenByTen)/><Text name='label' \(tenByTen)/>\(scroller)"
}

@Test func scrollBindingsReadForSlidersAndButtons() throws {
    let slider = try script(scrollDocument("<Slider name='scroller' \(tenByTen) scrolls='history'/>"))
    #expect(slider.control(named: "scroller")?.scrolls?.list == "history")
    #expect(slider.control(named: "scroller")?.scrolls?.direction == nil)

    let button = try script(scrollDocument("<Button name='scroller' \(tenByTen) scrolls='history' direction='up'/>"))
    #expect(button.control(named: "scroller")?.scrolls?.list == "history")
    #expect(button.control(named: "scroller")?.scrolls?.direction == .up)
}

@Test(arguments: [
    "<Slider name='scroller' \(tenByTen) scrolls='history' direction='up'/>",
    "<Button name='scroller' \(tenByTen) scrolls='history'/>",
    "<Button name='scroller' \(tenByTen) direction='up'/>",
    "<Text name='scroller' \(tenByTen) scrolls='history'/>",
    "<Slider name='scroller' \(tenByTen) scrolls='label'/>"
])
func uiScriptRejectsMismatchedScrollBindings(scroller: String) {
    #expect(throws: UIScriptError.invalidScrollBinding(owner: "scroller")) {
        try script(scrollDocument(scroller))
    }
}

@Test func uiScriptRejectsUnknownScrollDirectionsAndLists() {
    #expect(throws: UIScriptError.invalidAttribute(element: "Button", attribute: "direction", value: "sideways", line: 1)) {
        try script(scrollDocument("<Button name='scroller' \(tenByTen) scrolls='history' direction='sideways'/>"))
    }
    #expect(throws: UIScriptError.unknownReference(owner: "scroller", property: "scrolls", reference: "missing")) {
        try script(scrollDocument("<Slider name='scroller' \(tenByTen) scrolls='missing'/>"))
    }
}

@Test(arguments: [
    "<TextField name='entry' \(tenByTen) maximumLength='0'/>",
    "<Button name='entry' \(tenByTen) maximumLength='5'/>"
])
func uiScriptRejectsInvalidMaximumLengths(control: String) {
    #expect(throws: UIScriptError.invalidMaximumLength(owner: "entry")) {
        try script(control)
    }
}

// MARK: Images

private func imageDocument(stateCount: Int?) -> String {
    let count = stateCount.map { " stateCount='\($0)'" } ?? ""
    return "<Image name='art' path='ui/art.bmp'\(count)/><Button name='owner' x='5' y='6' image='art'/>"
}

@Test func imagesNeedAPathOrAnAssetID() throws {
    #expect(throws: UIScriptError.invalidImageResource(image: "art")) {
        try script("<Image name='art'/>")
    }
    let idOnly = try script("<Image name='art' assetID='0x10'/>").resources.images["art"]
    #expect(idOnly?.assetID == "0x10")
    #expect(idOnly?.path == nil)
    let pathOnly = try script("<Image name='art' path='a.bmp'/>").resources.images["art"]
    #expect(pathOnly?.path == "a.bmp")
    #expect(pathOnly?.assetID == nil)
}

@Test(arguments: zip(
    [UIScript.ButtonState.normal, .pressed, .hovered, .disabled],
    [Float(0), 25, 50, 75]
))
func fourStateImagesSliceInStateOrder(state: UIScript.ButtonState, expectedX: Float) throws {
    let image = try #require(try script(imageDocument(stateCount: 4)).resources.images["art"])

    let source = image.sourceRectangle(for: state, textureWidth: 100, textureHeight: 25)
    #expect(source == Rectangle(x: expectedX, y: 0, width: 25, height: 25))
}

@Test(arguments: [UIScript.ButtonState.normal, .pressed, .hovered, .disabled])
func singleStateImagesShowWholeInEveryState(state: UIScript.ButtonState) throws {
    let image = try #require(try script(imageDocument(stateCount: nil)).resources.images["art"])

    #expect(image.stateCount == 1)
    let source = image.sourceRectangle(for: state, textureWidth: 40, textureHeight: 20)
    #expect(source == Rectangle(x: 0, y: 0, width: 40, height: 20))
}

@Test(arguments: [0, 2, 3, 5, -4])
func uiScriptRejectsUnsupportedStateCounts(stateCount: Int) {
    #expect(throws: UIScriptError.invalidStateCount(image: "art")) {
        try script(imageDocument(stateCount: stateCount))
    }
}

@Test(arguments: ["Text", "List", "TextField", "Slider", "Region"])
func uiScriptRejectsImagesOnOtherControls(element: String) {
    #expect(throws: UIScriptError.invalidImage(owner: "owner")) {
        try script("<Image name='art' path='a.bmp'/><\(element) name='owner' \(tenByTen) image='art'/>")
    }
}

@Test(arguments: ["Button", "Text", "List", "TextField", "Slider", "Region"])
func controlsWithoutAnImageNeedASize(element: String) {
    #expect(throws: UIScriptError.missingSize(owner: "owner")) {
        try script("<\(element) name='owner' x='0' y='0'/>")
    }
    #expect(throws: UIScriptError.missingSize(owner: "owner")) {
        try script("<\(element) name='owner' x='0' y='0' width='10'/>")
    }
}

// MARK: View

@Test func viewTakesMissingSizesFromOneImageSlice() throws {
    let loaded = try script("""
    <Image name='strip' path='strip.bmp' stateCount='4'/>
    <Image name='plain' path='plain.bmp'/>
    <Button name='fromStrip' x='5' y='6' image='strip'/>
    <Button name='wider' x='5' y='6' width='70' image='strip'/>
    <Visual name='fromPlain' x='1' y='2' image='plain'/>
    """)
    let view = UIScriptView(script: loaded, loadImage: { resource in
        resource.stateCount == 4 ? stubTexture(width: 100, height: 25) : stubTexture(width: 40, height: 20)
    })
    let origin = Vector2(x: 10, y: 20)

    #expect(view.bounds(named: "fromStrip", at: origin) == Rectangle(x: 15, y: 26, width: 25, height: 25))
    #expect(view.bounds(named: "wider", at: origin) == Rectangle(x: 15, y: 26, width: 70, height: 25))
    #expect(view.bounds(named: "fromPlain", at: origin) == Rectangle(x: 11, y: 22, width: 40, height: 20))
    #expect(view.bounds(named: "missing", at: origin) == nil)
    #expect(view.pressButton(at: Vector2(x: 39, y: 50), origin: origin) == .pressed(control: "wider"))
}

@Test func viewFallsBackToASmallSizeForMissingImages() throws {
    let view = UIScriptView(script: try script(imageDocument(stateCount: 4)))

    #expect(view.missingImages == ["art"])
    #expect(view.bounds(named: "owner", at: .zero) == Rectangle(x: 5, y: 6, width: 24, height: 24))
}

@Test func viewAsksTheHostForEachImageOnce() throws {
    var requestedPaths: [String?] = []
    let view = UIScriptView(script: try script(imageDocument(stateCount: 4)), loadImage: { resource in
        requestedPaths.append(resource.path)
        return Texture2D()
    })

    #expect(requestedPaths == ["ui/art.bmp"])
    #expect(view.missingImages.isEmpty)
}

@Test func viewBuildsControlsAndFindsThemByKind() throws {
    let view = UIScriptView(script: try UIScript(contentsOf: demoResource("chatdialog.uix")))

    #expect(view.list(named: "chatHistory") != nil)
    #expect(view.textField(named: "chatEntry") != nil)
    #expect(view.list(named: "chatEntry") == nil)
    #expect(view.textField(named: "missing") == nil)
}

@Test func viewAppliesDocumentSettingsToTextFields() throws {
    let view = UIScriptView(script: try UIScript(contentsOf: demoResource("chatdialog.uix")))
    let entry = try #require(view.textField(named: "chatEntry"))

    entry.text = String(repeating: "a", count: 500)
    #expect(entry.text.count == 120)
}

@Test func viewScrollButtonsMoveTheirListWithoutReportingAnEvent() throws {
    let view = UIScriptView(script: try UIScript(contentsOf: demoResource("chatdialog.uix")))
    let history = try #require(view.list(named: "chatHistory"))
    let origin = Vector2(x: 1000, y: 1000)
    history.items = (1...20).map { "Message \($0)" }
    _ = view.update(at: origin)

    #expect(view.pressButton(at: Vector2(x: 1370, y: 1035), origin: origin) == nil)
    #expect(history.scrollOffset == 1)
    #expect(view.pressButton(at: Vector2(x: 1370, y: 1200), origin: origin) == nil)
    #expect(history.scrollOffset == 0)
}

@Test func viewReportsOtherButtonsAndSkipsHiddenOnes() throws {
    let view = UIScriptView(script: try script("<Button name='lower' \(tenByTen)/><Button name='upper' \(tenByTen)/>"))
    let point = Vector2(x: 5, y: 5)

    #expect(view.pressButton(at: point, origin: .zero) == .pressed(control: "upper"))

    view.setHidden(true, named: "upper")
    #expect(view.isHidden(named: "upper"))
    #expect(view.pressButton(at: point, origin: .zero) == .pressed(control: "lower"))

    view.setHidden(false, named: "upper")
    #expect(view.pressButton(at: point, origin: .zero) == .pressed(control: "upper"))
    #expect(view.pressButton(at: Vector2(x: 50, y: 50), origin: .zero) == nil)
}

@Test func disabledButtonsAbsorbPressesWithoutReporting() throws {
    let view = UIScriptView(script: try script("<Button name='lower' \(tenByTen)/><Button name='upper' \(tenByTen)/>"))
    let point = Vector2(x: 5, y: 5)

    view.setDisabled(true, named: "upper")
    #expect(view.isDisabled(named: "upper"))
    #expect(view.pressButton(at: point, origin: .zero) == nil)

    view.setDisabled(false, named: "upper")
    #expect(view.pressButton(at: point, origin: .zero) == .pressed(control: "upper"))
}

@Test func viewResolvesStringReferencesThroughTheHost() throws {
    let parsed = try script("<String name='hint' table='UIText' index='7'/><TextField name='entry' \(tenByTen) string='hint'/>")

    let resolved = UIScriptView(script: parsed, resolveString: { "\($0.table) string \($0.index)" })
    #expect(resolved.textField(named: "entry")?.text == "UIText string 7")

    let unresolved = UIScriptView(script: parsed)
    #expect(unresolved.textField(named: "entry")?.text == "UIText#7")
}

@Test func chatDialogControlsFitInsideItsWindow() throws {
    let chat = try UIScript(contentsOf: demoResource("chatdialog.uix"))
    let view = UIScriptView(script: chat)

    for control in chat.controls {
        let bounds = try #require(view.bounds(named: control.name, at: .zero))
        #expect(bounds.x + bounds.width <= chat.window.size.width, "\(control.name) is too wide")
        #expect(bounds.y + bounds.height <= chat.window.size.height, "\(control.name) is too tall")
    }
}

// Both roadmap examples must work through the same model and view, with different compositions.
@Test func chatAndLivePanelShareOneModelWithoutSharingALayout() throws {
    let chat = try UIScript(contentsOf: demoResource("chatdialog.uix"))
    let panel = try UIScript(contentsOf: demoResource("livepanel1024.uix"))
    let chatView = UIScriptView(script: chat)
    let panelView = UIScriptView(script: panel)

    #expect(chat.controls.contains { $0.scrolls != nil })
    #expect(!panel.controls.contains { $0.scrolls != nil })
    #expect(panel.controls.contains { $0.type == .region })
    #expect(!chat.controls.contains { $0.type == .region })
    #expect(chatView.missingImages.isEmpty)
    #expect(panelView.missingImages.count == panel.resources.images.count)
    #expect(panelView.textField(named: "statusBarTimerEntry") != nil)
}

@Test func demoDocumentsUseNoAttributesTheReaderIgnores() throws {
    for name in ["chatdialog.uix", "livepanel1024.uix"] {
        #expect(try UIScript(contentsOf: demoResource(name)).ignoredAttributes.isEmpty, "\(name)")
    }
}

@Test func livePanelReadsWithTheCurrentModel() throws {
    let panel = try UIScript(contentsOf: demoResource("livepanel1024.uix"))

    #expect(panel.window.size.width == 1024)
    #expect(panel.controls.count == 14)
    #expect(panel.visuals.count == 4)
    #expect(panel.control(named: "peopleList")?.type == .region)
    #expect(panel.resources.images["nextPage"]?.stateCount == 4)
    #expect(panel.resources.images.values.allSatisfy { $0.assetID == nil && $0.path?.hasPrefix("demo/") == true })
    #expect(panel.control(named: "nextPage")?.frame.width == nil)
}

// MARK: Text list

// Headless, the 100-tall viewport shows five lines and each item measures as one line.
private func scrollableList(itemCount: Int) -> (list: TextList, bounds: Rectangle) {
    let list = TextList(items: (1...itemCount).map { "Item \($0)" })
    let bounds = Rectangle(x: 500, y: 500, width: 200, height: 100)
    list.update(in: bounds)
    return (list, bounds)
}

@Test func scrollThumbSitsAtTheBottomForNewestContent() {
    let (list, _) = scrollableList(itemCount: 20)
    let track = Rectangle(x: 10, y: 100, width: 12, height: 102)

    let newest = list.scrollThumbBounds(in: track)
    #expect(newest == Rectangle(x: 11, y: 176, width: 10, height: 25))

    list.scroll(byLines: 15)
    let oldest = list.scrollThumbBounds(in: track)
    #expect(oldest == Rectangle(x: 11, y: 101, width: 10, height: 25))
}

@Test func scrollingToAFractionMatchesTheThumbPosition() {
    let (list, _) = scrollableList(itemCount: 20)

    list.scroll(toFraction: 0)
    #expect(list.scrollOffset == 15)
    #expect(list.scrollFraction == 0)
    list.scroll(toFraction: 1)
    #expect(list.scrollOffset == 0)
    list.scroll(toFraction: 0.6)
    #expect(list.scrollOffset == 6)
    list.scroll(toFraction: 5)
    #expect(list.scrollOffset == 0)
    list.scroll(toFraction: .nan)
    #expect(list.scrollOffset == 0)
}

@Test func scrollThumbFillsTheTrackWhenEverythingFits() {
    let (list, _) = scrollableList(itemCount: 2)
    let thumb = list.scrollThumbBounds(in: Rectangle(x: 0, y: 0, width: 10, height: 52))

    #expect(thumb == Rectangle(x: 1, y: 1, width: 8, height: 50))
}

@Test func wheelMovementAddsUpPartialLines() {
    let (list, _) = scrollableList(itemCount: 20)

    list.scroll(byWheelMovement: 0.2)
    #expect(list.scrollOffset == 0)
    list.scroll(byWheelMovement: 0.2)
    #expect(list.scrollOffset == 1)
    list.scroll(byWheelMovement: 1)
    #expect(list.scrollOffset == 4)
    list.scroll(byWheelMovement: .nan)
    #expect(list.scrollOffset == 4)
}

@Test func textListKeepsBlankLinesInsideItems() {
    let list = TextList(items: ["one\n\nthree"])
    // Room for exactly one line, so the thumb's size reveals the line count.
    list.update(in: Rectangle(x: 500, y: 500, width: 200, height: 20))

    #expect(abs(list.scrollThumbFraction - (1.0 / 3.0)) < 0.001)
}

// Headless, the 100-tall viewport shows five 16-tall lines, starting 6 below the top.
private func pickList(itemCount: Int) -> (list: TextList, bounds: Rectangle) {
    let list = TextList(items: (0..<itemCount).map { "Item \($0)" }, isSelectable: true)
    let bounds = Rectangle(x: 500, y: 500, width: 200, height: 100)
    list.update(in: bounds)
    return (list, bounds)
}

private func row(_ row: Int, of bounds: Rectangle) -> Vector2 {
    Vector2(x: bounds.x + 10, y: bounds.y + 6 + (Float(row) * 16) + 1)
}

@Test func pickListsOpenOnTheirFirstItemsAndStayPutWhenItemsChange() {
    let (list, bounds) = pickList(itemCount: 20)
    #expect(list.itemIndex(at: row(0, of: bounds), in: bounds) == 0)
    #expect(list.scrollFraction == 0)

    list.scroll(byLines: -3)
    #expect(list.itemIndex(at: row(0, of: bounds), in: bounds) == 3)

    list.items += ["Item 20", "Item 21"]
    #expect(list.itemIndex(at: row(0, of: bounds), in: bounds) == 3)
    list.items = ["Only", "Two"]
    #expect(list.itemIndex(at: row(0, of: bounds), in: bounds) == 0)
}

@Test func logListsStayAtTheirNewestItems() {
    let (list, bounds) = scrollableList(itemCount: 20)
    #expect(list.itemIndex(at: row(4, of: bounds), in: bounds) == 19)

    list.items += ["Item 21"]
    #expect(list.itemIndex(at: row(4, of: bounds), in: bounds) == 20)
}

@Test func itemIndexFindsOnlyDrawnItems() {
    let (list, bounds) = pickList(itemCount: 2)

    #expect(list.itemIndex(at: row(1, of: bounds), in: bounds) == 1)
    // Below the last item, in the top padding, and outside the list.
    #expect(list.itemIndex(at: row(2, of: bounds), in: bounds) == nil)
    #expect(list.itemIndex(at: Vector2(x: 510, y: 502), in: bounds) == nil)
    #expect(list.itemIndex(at: Vector2(x: 10, y: 10), in: bounds) == nil)

    let (crowded, crowdedBounds) = pickList(itemCount: 20)
    // The sliver under the fifth row holds no whole line, so nothing is drawn there.
    #expect(crowded.itemIndex(at: row(5, of: crowdedBounds), in: crowdedBounds) == nil)
}

@Test func everyLineOfAnItemBelongsToIt() {
    let list = TextList(items: ["one\ntwo", "three"], isSelectable: true)
    let bounds = Rectangle(x: 500, y: 500, width: 200, height: 100)

    #expect(list.itemIndex(at: row(1, of: bounds), in: bounds) == 0)
    #expect(list.itemIndex(at: row(2, of: bounds), in: bounds) == 1)
}

@Test func clicksSelectAndReportOnlyAChange() {
    let (list, bounds) = pickList(itemCount: 3)

    #expect(list.select(at: row(1, of: bounds), in: bounds, time: 0) == .selected(1))
    #expect(list.selectedIndex == 1)
    #expect(list.select(at: row(1, of: bounds), in: bounds, time: 10) == nil)
    // A click on the empty part of the list keeps the selection.
    #expect(list.select(at: row(4, of: bounds), in: bounds, time: 20) == nil)
    #expect(list.selectedIndex == 1)
}

@Test func selectionStaysWithinTheItems() {
    let (list, _) = pickList(itemCount: 3)

    list.selectedIndex = 2
    #expect(list.selectedIndex == 2)
    list.selectedIndex = 3
    #expect(list.selectedIndex == nil)
    list.selectedIndex = -1
    #expect(list.selectedIndex == nil)

    list.selectedIndex = 2
    list.items = ["a", "b", "c"]
    #expect(list.selectedIndex == 2)
    list.items = ["a"]
    #expect(list.selectedIndex == nil)
}

@Test func logListsHaveNoSelection() {
    let (list, bounds) = scrollableList(itemCount: 3)

    #expect(list.select(at: row(0, of: bounds), in: bounds, time: 0) == nil)
    list.selectedIndex = 0
    #expect(list.selectedIndex == nil)
}

@Test func demoMoveWindowDeclaresWhatItNeeds() throws {
    let moveLot = try UIScript(contentsOf: demoResource("movelot.uix"))

    #expect(moveLot.ignoredAttributes.isEmpty)
    #expect(moveLot.control(named: "lotChoices")?.isSelectable == true)
    #expect(moveLot.control(named: "lotKey")?.isSecure == true)
    #expect(moveLot.titleField?.name == "lotSearch")
    #expect(moveLot.toolbarItems.map(\.name) == ["showAll"])
}

@Test func uiScriptReadsSelectable() throws {
    let loaded = try script("<List name='a' \(tenByTen) selectable='true'/><List name='b' \(tenByTen)/>")

    #expect(loaded.ignoredAttributes.isEmpty)
    let view = UIScriptView(script: loaded)
    #expect(view.list(named: "a")?.isSelectable == true)
    #expect(view.list(named: "b")?.isSelectable == false)
}

@Test func uiScriptRejectsInvalidSelectable() {
    #expect(throws: UIScriptError.invalidSelectable(owner: "a")) {
        try script("<TextField name='a' \(tenByTen) selectable='true'/>")
    }
}

private let lotList = "<List name='lots' x='0' y='0' width='100' height='60' selectable='true'/>"

@Test func viewReportsSelectionOnTheListUnderThePointer() throws {
    let view = UIScriptView(script: try script(lotList))
    let origin = Vector2(x: 500, y: 500)
    let list = try #require(view.list(named: "lots"))
    list.items = ["Maple", "Oak"]

    #expect(view.selectListItem(at: Vector2(x: 510, y: 507), origin: origin, time: 0) == .selected(control: "lots", index: 0))
    #expect(view.selectListItem(at: Vector2(x: 510, y: 523), origin: origin, time: 10) == .selected(control: "lots", index: 1))
    #expect(view.selectListItem(at: Vector2(x: 510, y: 523), origin: origin, time: 20) == nil)
    #expect(list.selectedIndex == 1)
}

@Test func controlsOverAListKeepItsClicks() throws {
    let view = UIScriptView(script: try script(lotList + "<Button name='over' x='0' y='0' width='100' height='20'/>"))
    let list = try #require(view.list(named: "lots"))
    list.items = ["Maple", "Oak"]

    #expect(view.selectListItem(at: Vector2(x: 10, y: 7), origin: .zero, time: 0) == nil)
    #expect(list.selectedIndex == nil)
    // Hiding the button uncovers the list.
    view.setHidden(true, named: "over")
    #expect(view.selectListItem(at: Vector2(x: 10, y: 7), origin: .zero, time: 10) == .selected(control: "lots", index: 0))
}

@Test func hiddenListsTakeNoClicks() throws {
    let view = UIScriptView(script: try script(lotList))
    view.list(named: "lots")?.items = ["Maple"]
    view.setHidden(true, named: "lots")

    #expect(view.selectListItem(at: Vector2(x: 10, y: 7), origin: .zero, time: 0) == nil)
}

@Test func formLayoutStacksLabeledControlsAndReservesFooterSpace() {
    let name = TextField(maximumLength: 20)
    let description = TextField(maximumLength: 80)
    let layout = FormLayout(
        fields: [
            .init(label: "Name", control: name, height: 24),
            .init(label: "Description", control: description, height: 60)
        ],
        footerHeight: 40
    )
    layout.layout(in: Rectangle(x: 10, y: 20, width: 300, height: 200))

    #expect(layout.fields[0].labelPosition == Vector2(x: 20, y: 32))
    #expect(layout.fields[0].controlBounds == Rectangle(x: 20, y: 54, width: 280, height: 24))
    #expect(name.bounds == layout.fields[0].controlBounds)
    #expect(layout.fields[1].labelPosition == Vector2(x: 20, y: 86))
    #expect(layout.fields[1].controlBounds == Rectangle(x: 20, y: 108, width: 280, height: 60))
    #expect(description.bounds == layout.fields[1].controlBounds)
    #expect(layout.buttonRowCorner == Vector2(x: 300, y: 210))

    layout.layout(in: Rectangle(x: 30, y: 40, width: 400, height: 220))
    #expect(layout.fields[0].labelPosition == Vector2(x: 40, y: 52))
    #expect(layout.fields[0].controlBounds == Rectangle(x: 40, y: 74, width: 380, height: 24))
    #expect(layout.buttonRowCorner == Vector2(x: 420, y: 250))
}

@Test func formLayoutPlacesBoundControls() {
    let name = TextField(text: "Player", maximumLength: 24)
    let description = TextArea(text: "A place to explore.", maximumLength: 200)
    let layout = FormLayout(fields: [
        .init(label: "Name", control: name),
        .init(label: "Description", control: description)
    ])

    layout.layout(in: Rectangle(x: 10, y: 20, width: 320, height: 240))

    #expect(name.bounds == layout.fields[0].controlBounds)
    #expect(description.bounds == layout.fields[1].controlBounds)
    #expect(name.bounds.height == Float(name.height))
    #expect(description.bounds.height == Float(description.height(forLineCount: 4)))

    name.place(in: Rectangle())
    layout.layout(in: Rectangle(x: 10, y: 20, width: 320, height: 240))
    #expect(name.bounds == layout.fields[0].controlBounds)
}

@Test func iconToolbarAnchorsButtonsAtTheBottomLeft() {
    let panel = Rectangle(x: 12, y: 504, width: 776, height: 84)
    let toolbar = IconToolbar.bounds(itemCount: 3, in: panel)
    let first = IconToolbar.buttonBounds(at: 0, itemCount: 3, in: panel)
    let last = IconToolbar.buttonBounds(at: 2, itemCount: 3, in: panel)

    #expect(toolbar == Rectangle(x: 24, y: 522, width: 146, height: 54))
    #expect(first == Rectangle(x: 30, y: 528, width: 42, height: 42))
    #expect(last == Rectangle(x: 122, y: 528, width: 42, height: 42))
    #expect(IconToolbar.buttonBounds(at: 3, itemCount: 3, in: panel) == nil)
}

@Test func iconToolbarReportsOnlyButtonHits() {
    let screen = Rectangle(x: 0, y: 0, width: 800, height: 600)

    #expect(IconToolbar.buttonIndex(at: Vector2(x: 30, y: 550), itemCount: 3, in: screen) == 0)
    #expect(IconToolbar.buttonIndex(at: Vector2(x: 62, y: 550), itemCount: 3, in: screen) == nil)
    #expect(IconToolbar.buttonIndex(at: Vector2(x: 790, y: 10), itemCount: 3, in: screen) == nil)
    #expect(IconToolbar.buttonIndex(at: Vector2(x: 30, y: 550), itemCount: 0, in: screen) == nil)
}

// MARK: API review

@Test func panelsAcceptBlankTextWithoutCrashing() {
    let notice = NoticePanel()
    notice.show(title: "", message: "   ")
    #expect(notice.isOpen)
}

@Test func confirmPanelOpensOnShowAndStaysPendingWithoutInput() {
    let panel = ConfirmPanel()
    #expect(!panel.isOpen)
    #expect(panel.update() == .pending)

    panel.show(title: "Leave?", message: "Your lot will stay open.")
    #expect(panel.isOpen)
    #expect(panel.update() == .pending)
    #expect(panel.isOpen)
}

@Test func formLayoutToleratesBoundsTooSmallForIt() {
    let name = TextField(maximumLength: 20)
    let layout = FormLayout(fields: [.init(label: "Name", control: name)], footerHeight: 40)

    layout.layout(in: Rectangle(x: 0, y: 0, width: 4, height: 4))

    #expect(name.bounds.width == 0)
}

private func wrapped(_ text: String, maximumWidth: Int) -> [String] {
    TextWrapper.lines(for: text, maximumWidth: maximumWidth) { $0.count }
}

@Test func textWrapperBreaksBetweenWords() {
    #expect(wrapped("one two three", maximumWidth: 7) == ["one two", "three"])
    #expect(wrapped("", maximumWidth: 7).isEmpty)
}

@Test func textWrapperBreaksWordsTooWideForALine() {
    #expect(wrapped("abcdefghij", maximumWidth: 4) == ["abcd", "efgh", "ij"])
    #expect(wrapped("hi abcdefghij ok", maximumWidth: 4) == ["hi", "abcd", "efgh", "ij", "ok"])
}

@Test func textWrapperAlwaysMakesProgressWhenNothingFits() {
    #expect(wrapped("abc", maximumWidth: 0) == ["a", "b", "c"])
}

@Test func buttonRowIgnoresDisabledButtons() {
    // Headless, labels measure as empty, so each button is 28 wide with a 10 gap.
    let corner = Vector2(x: 200, y: 100)
    let labels = ["Save", "Cancel"]
    let onCancel = Vector2(x: 180, y: 85)
    let onSave = Vector2(x: 140, y: 85)

    #expect(ButtonRow.buttonIndex(at: onCancel, endingAt: corner, labels: labels) == 1)
    #expect(ButtonRow.buttonIndex(at: onCancel, endingAt: corner, labels: labels, enabled: [true, false]) == nil)
    #expect(ButtonRow.buttonIndex(at: onSave, endingAt: corner, labels: labels, enabled: [true, false]) == 0)
    #expect(ButtonRow.buttonIndex(at: onCancel, endingAt: corner, labels: labels, enabled: [true]) == 1)
}

@Test func readOnlyFieldsDisplayTextButNeverSubmit() {
    let field = TextField(text: "08:00", maximumLength: 8, isReadOnly: true)

    #expect(field.submit() == nil)
    #expect(field.text == "08:00")
    #expect(field.update(in: Rectangle(x: 0, y: 0, width: 50, height: 15)) == nil)
    #expect(!field.isFocused)

    field.text = "08:01"
    #expect(field.text == "08:01")
}

@Test func standardThemeKeepsSquareCornersAndAFlatTitleBar() {
    #expect(InterfaceTheme.standard.cornerRadius == 0)
    #expect(InterfaceTheme.standard.titleBarBottom == nil)
    #expect(InterfaceTheme.standard.cornerRadius(for: Rectangle(x: 0, y: 0, width: 100, height: 100)) == 0)
}

@Test func cornersShrinkToFitSmallShapes() {
    let theme = InterfaceTheme(cornerRadius: 8)

    #expect(theme.cornerRadius(for: Rectangle(x: 0, y: 0, width: 300, height: 200)) == 8)
    #expect(theme.cornerRadius(for: Rectangle(x: 0, y: 0, width: 300, height: 10)) == 5)
    #expect(theme.cornerRadius(for: Rectangle(x: 0, y: 0, width: 0, height: 200)) == 0)
    #expect(theme.cornerRadius(for: Rectangle(x: 0, y: 0, width: -4, height: 200)) == 0)
}

@Test func titleBarRowsFollowTheCornerThenRunFullWidth() {
    #expect(InterfaceTheme.cornerInset(ofRow: 0, radius: 0) == 0)

    let insets = (0..<10).map { InterfaceTheme.cornerInset(ofRow: $0, radius: 8) }
    #expect(insets[0] > 4 && insets[0] < 8)
    #expect(zip(insets, insets.dropFirst()).allSatisfy { $0 >= $1 })
    #expect(insets[7] > 0)
    #expect(insets[8] == 0)
    #expect(insets[9] == 0)
}

@Test func titleBarFadesFromTopColorToBottomColor() {
    let top = Color(r: 0, g: 100, b: 200, a: 255)
    let bottom = Color(r: 100, g: 200, b: 0, a: 155)
    let glossy = InterfaceTheme(titleBar: top, titleBarBottom: bottom)
    let flat = InterfaceTheme(titleBar: top)

    func channels(_ color: Color) -> [UInt8] { [color.r, color.g, color.b, color.a] }

    #expect(channels(glossy.titleBarColor(ofRow: 0, rowCount: 30)) == channels(top))
    #expect(channels(glossy.titleBarColor(ofRow: 29, rowCount: 30)) == channels(bottom))
    #expect(channels(glossy.titleBarColor(ofRow: 1, rowCount: 3)) == [50, 150, 100, 205])
    #expect(channels(glossy.titleBarColor(ofRow: 0, rowCount: 1)) == channels(top))
    #expect(channels(flat.titleBarColor(ofRow: 29, rowCount: 30)) == channels(top))
}

@Test func standardTextSizesKeepHudinisLook() {
    let sizes = InterfaceTheme.standard.textSizes

    #expect(sizes.title == 16)
    #expect(sizes.label == 16)
    #expect(sizes.body == 14)
    #expect(sizes.button == 20)
    #expect(sizes.input == 20)
    #expect(sizes.tooltip == 12)
    #expect(sizes.problem == 10)
    #expect(InterfaceTheme.standard.font == nil)
}

@Test func controlsTakeTheirSizeFromTheThemeUnlessGivenOne() {
    let theme = InterfaceTheme(textSizes: .init(input: 30))

    #expect(TextField(maximumLength: 8).height == 32)
    #expect(TextField(maximumLength: 8, theme: theme).height == 42)
    #expect(TextField(maximumLength: 8, fontSize: 10, theme: theme).height == 22)
    #expect(TextArea(maximumLength: 8, theme: theme).formHeight == TextArea(maximumLength: 8, fontSize: 30).formHeight)
}

@Test func uiScriptFieldsUseTheThemesBodySizeUnlessStyled() throws {
    let theme = InterfaceTheme(textSizes: .init(body: 30))
    let plain = UIScriptView(script: try script("<TextField name='entry' \(tenByTen)/>"), theme: theme)
    let styled = UIScriptView(
        script: try script("<Style name='s' fontSize='18'/><TextField name='entry' style='s' \(tenByTen)/>"),
        theme: theme
    )

    #expect(plain.textField(named: "entry")?.height == 42)
    #expect(styled.textField(named: "entry")?.height == 30)
}

@Test func formsLeaveRoomForTheThemesLabelSize() {
    let bounds = Rectangle(x: 0, y: 0, width: 200, height: 200)
    let standard = FormLayout(fields: [.init(label: "Name", control: TextField(maximumLength: 8))])
    let larger = FormLayout(
        fields: [.init(label: "Name", control: TextField(maximumLength: 8))],
        theme: InterfaceTheme(textSizes: .init(label: 26))
    )

    standard.layout(in: bounds)
    larger.layout(in: bounds)

    #expect(larger.fields[0].controlBounds.y == standard.fields[0].controlBounds.y + 10)
}

@Test func aFontWithoutATextureCountsAsNoFont() {
    let theme = InterfaceTheme(font: Font())

    #expect(theme.textWidth(of: "Hudini", size: 20) == InterfaceTheme.standard.textWidth(of: "Hudini", size: 20))
}

@Test func themesStaySendableWithAFont() {
    func send(_ value: some Sendable) {}
    send(InterfaceTheme(font: Font()))
}

@Test func buttonRowHitTestingTakesTheThemeItDrawsWith() {
    let corner = Vector2(x: 300, y: 100)
    let theme = InterfaceTheme(accent: Color(r: 1, g: 2, b: 3, a: 255))
    let point = Vector2(x: 295, y: 90)

    #expect(
        ButtonRow.buttonIndex(at: point, endingAt: corner, labels: ["OK"], theme: theme)
            == ButtonRow.buttonIndex(at: point, endingAt: corner, labels: ["OK"])
    )
}

@Test func settingAFieldsThemeKeepsItsTextFocusAndOwnSize() {
    let larger = InterfaceTheme(textSizes: .init(input: 30))
    let field = TextField(text: "Maya", maximumLength: 8)
    let sized = TextField(maximumLength: 8, fontSize: 10)
    field.setFocused(true)

    field.theme = larger
    sized.theme = larger

    #expect(field.height == 42)
    #expect(field.text == "Maya")
    #expect(field.isFocused)
    #expect(sized.height == 22)
}

@Test func settingAnAreasThemeFollowsItsSize() {
    let area = TextArea(text: "Some words", maximumLength: 40)

    area.theme = InterfaceTheme(textSizes: .init(input: 30))

    #expect(area.formHeight == TextArea(maximumLength: 40, fontSize: 30).formHeight)
    #expect(area.text == "Some words")
}

@Test func settingAListsThemeKeepsItsSelectionAndUsesTheNewLineHeight() {
    let list = TextList(items: ["Maple", "Oak", "Birch"], isSelectable: true)
    let bounds = Rectangle(x: 0, y: 0, width: 200, height: 200)
    // The second line starts 6 + 16 pixels down at the standard body size.
    let point = Vector2(x: 10, y: 26)
    list.selectedIndex = 2

    #expect(list.itemIndex(at: point, in: bounds) == 1)

    list.theme = InterfaceTheme(textSizes: .init(body: 30))

    #expect(list.itemIndex(at: point, in: bounds) == 0)
    #expect(list.selectedIndex == 2)
}

@Test func settingAViewsThemeReachesItsControlsAndKeepsTheirState() throws {
    let view = UIScriptView(script: try script("""
    <Style name='fixed' fontSize='18'/>
    <TextField name='entry' \(tenByTen)/>
    <TextField name='styled' style='fixed' \(tenByTen)/>
    <List name='lots' x='0' y='20' width='200' height='200' selectable='true'/>
    """))
    let lots = try #require(view.list(named: "lots"))
    lots.items = ["Maple", "Oak", "Birch"]
    lots.selectedIndex = 2
    view.setText("Maya", named: "entry")

    view.theme = InterfaceTheme(textSizes: .init(body: 30))

    #expect(view.textField(named: "entry")?.height == 42)
    #expect(view.textField(named: "styled")?.height == 30)
    #expect(view.text(named: "entry") == "Maya")
    #expect(lots.selectedIndex == 2)
    #expect(lots.theme.textSizes.body == 30)
}

@Test func settingAFramesThemeKeepsItsTitle() {
    let frame = WindowFrame(title: "Lots", theme: .standard)

    frame.theme = InterfaceTheme(textSizes: .init(title: 22))

    #expect(frame.theme.textSizes.title == 22)
    #expect(frame.title == "Lots")
}

@Test func formsLayOutAgainForANewThemeOrControlHeight() {
    let bounds = Rectangle(x: 0, y: 0, width: 200, height: 300)
    let name = TextField(maximumLength: 8)
    let note = TextField(maximumLength: 8)
    let layout = FormLayout(fields: [
        .init(label: "Name", control: name),
        .init(label: "Note", control: note),
    ])
    layout.layout(in: bounds)
    let before = layout.fields.map(\.controlBounds.y)

    layout.theme = InterfaceTheme(textSizes: .init(label: 26))
    layout.layout(in: bounds)
    // Each label is 10 pixels taller, so each field moves down 10 more than the one above it.
    #expect(layout.fields.map(\.controlBounds.y) == [before[0] + 10, before[1] + 20])
    let afterLabels = layout.fields.map(\.controlBounds.y)

    name.theme = InterfaceTheme(textSizes: .init(input: 30))
    layout.layout(in: bounds)
    #expect(layout.fields[0].controlBounds.height == 42)
    #expect(layout.fields[1].controlBounds.y == afterLabels[1] + 10)
}

@Test func hostsCanGiveAndRemoveFieldFocus() {
    let field = TextField(maximumLength: 8)

    field.setFocused(true)
    #expect(field.isFocused)
    // A frame without a click leaves the host's choice in place.
    #expect(field.update(in: Rectangle(x: 500, y: 500, width: 80, height: 30)) == nil)
    #expect(field.isFocused)

    field.setFocused(false)
    #expect(!field.isFocused)
}

@Test func readOnlyFieldsRefuseFocusFromTheHost() {
    let field = TextField(maximumLength: 8, isReadOnly: true)

    field.setFocused(true)
    #expect(!field.isFocused)
}

@Test func viewFieldsTakeFocusByNameAndLoseItWhenHidden() throws {
    let view = UIScriptView(script: try script("<TextField name='entry' \(tenByTen)/>"))
    let field = try #require(view.textField(named: "entry"))

    field.setFocused(true)
    #expect(field.isFocused)

    view.setHidden(true, named: "entry")
    #expect(!field.isFocused)
}

@Test func fieldsAndAreasRememberBoundsFromUpdate() {
    let bounds = Rectangle(x: 500, y: 500, width: 80, height: 30)
    let field = TextField(maximumLength: 8)
    let area = TextArea(maximumLength: 8)

    #expect(field.update(in: bounds) == nil)
    #expect(field.bounds == bounds)
    #expect(field.update() == nil)
    #expect(!area.update(in: bounds))
    #expect(area.bounds == bounds)
    #expect(!area.update())
    #expect(!area.isFocused)
}

@Test func secureFieldsMaskWhatTheyDrawOnly() {
    let field = TextField(text: "hunter2", maximumLength: 16, isSecure: true)

    #expect(field.text == "hunter2")
    #expect(field.shownText == "*******")
    #expect(field.submit() == .submitted("hunter2"))
    #expect(field.shownText.isEmpty)

    let plain = TextField(text: "hunter2", maximumLength: 16)
    #expect(plain.shownText == "hunter2")
}

@Test func uiScriptReadsSecure() throws {
    let loaded = try script("<TextField name='a' \(tenByTen) secure='true'/><TextField name='b' \(tenByTen)/>")

    #expect(loaded.ignoredAttributes.isEmpty)
    #expect(loaded.control(named: "a")?.isSecure == true)
    #expect(loaded.control(named: "b")?.isSecure == false)
    #expect(UIScriptView(script: loaded).textField(named: "a")?.isSecure == true)
}

@Test func uiScriptRejectsInvalidSecure() {
    #expect(throws: UIScriptError.invalidSecure(owner: "a")) {
        try script("<Button name='a' \(tenByTen) secure='true'/>")
    }
    #expect(throws: UIScriptError.invalidAttribute(element: "TextField", attribute: "secure", value: "yes", line: 1)) {
        try script("<TextField name='a' \(tenByTen) secure='yes'/>")
    }
}

@Test func uiScriptReadsReadOnly() throws {
    let loaded = try script("<TextField name='a' \(tenByTen) readOnly='true'/><TextField name='b' \(tenByTen)/>")

    #expect(loaded.control(named: "a")?.isReadOnly == true)
    #expect(loaded.control(named: "b")?.isReadOnly == false)
    #expect(UIScriptView(script: loaded).textField(named: "a")?.isReadOnly == true)
}

@Test func uiScriptRejectsInvalidReadOnly() {
    #expect(throws: UIScriptError.invalidReadOnly(owner: "a")) {
        try script("<Button name='a' \(tenByTen) readOnly='true'/>")
    }
    #expect(throws: UIScriptError.invalidAttribute(element: "TextField", attribute: "readOnly", value: "yes", line: 1)) {
        try script("<TextField name='a' \(tenByTen) readOnly='yes'/>")
    }
}

@Test func stylesPickButtonLabelColorsByState() throws {
    let white = "#FFFFFF", red = "#FF0000", green = "#00FF00", blue = "#0000FF"
    let loaded = try script("""
    <Style name='full' textColor='\(white)' selectedTextColor='\(red)' highlightedTextColor='\(green)' disabledTextColor='\(blue)'/>
    <Style name='plain' textColor='\(white)'/>
    """)
    let full = try #require(loaded.styles["full"])
    let plain = try #require(loaded.styles["plain"])
    let whiteColor = Color(r: 255, g: 255, b: 255, a: 255)

    #expect(full.textColor(for: .normal) == whiteColor)
    #expect(full.textColor(for: .pressed) == Color(r: 255, g: 0, b: 0, a: 255))
    #expect(full.textColor(for: .hovered) == Color(r: 0, g: 255, b: 0, a: 255))
    #expect(full.textColor(for: .disabled) == Color(r: 0, g: 0, b: 255, a: 255))
    #expect(plain.textColor(for: .pressed) == whiteColor)
    #expect(plain.textColor(for: .hovered) == whiteColor)
    #expect(plain.textColor(for: .disabled) == nil)
}

@Test func viewChangesTextAtRuntime() throws {
    let view = UIScriptView(script: try script("""
    <Text name='label' \(tenByTen) text='Funds'/>
    <Button name='button' \(tenByTen)/>
    <TextField name='field' \(tenByTen) maximumLength='3'/>
    <List name='list' \(tenByTen)/>
    """))

    #expect(view.text(named: "label") == "Funds")
    view.setText("$100", named: "label")
    #expect(view.text(named: "label") == "$100")

    #expect(view.text(named: "button") == nil)
    view.setText("Go", named: "button")
    #expect(view.text(named: "button") == "Go")

    view.setText("08:00", named: "field")
    #expect(view.text(named: "field") == "08:")

    view.setText("ignored", named: "list")
    view.setText("ignored", named: "missing")
    #expect(view.text(named: "list") == nil)
    #expect(view.text(named: "missing") == nil)
}

@Test func viewReportsWhenAPointIsOverItsVisibleParts() throws {
    let view = UIScriptView(script: try script("""
    <Image name='art' path='a.bmp'/>
    <Visual name='backdrop' image='art' x='100' y='100' width='10' height='10'/>
    <Region name='area' x='0' y='0' width='10' height='10'/>
    """))
    let origin = Vector2(x: 50, y: 50)

    #expect(view.containsPoint(Vector2(x: 55, y: 55), origin: origin))
    #expect(view.containsPoint(Vector2(x: 155, y: 155), origin: origin))
    #expect(!view.containsPoint(Vector2(x: 5, y: 5), origin: origin))

    view.setHidden(true, named: "area")
    #expect(!view.containsPoint(Vector2(x: 55, y: 55), origin: origin))
    view.setHidden(true, named: "backdrop")
    #expect(!view.containsPoint(Vector2(x: 155, y: 155), origin: origin))
}

// MARK: .uis files

private func uis(_ text: String) throws -> UIScript {
    try UIScript(uisData: Data(text.utf8))
}

@Test func uisReadsTheDebugBarWithNothingLeftOver() throws {
    let bar = try UIScript(uisContentsOf: demoResource("debugbar.uis"))

    #expect(bar.conversionNotes.isEmpty)
    #expect(bar.ignoredAttributes.isEmpty)
    #expect(bar.window.size.width == 1024)
    #expect(bar.window.size.height == 28)
    #expect(bar.visuals.map(\.name) == ["BarBackground"])
    #expect(bar.control(named: "HelpButton")?.frame.edgeOffsets?.right == 8)
    #expect(bar.control(named: "SpeedSlow")?.legacyID == 2)
    #expect(bar.control(named: "SpeedSlow")?.tooltip == "SlowSpeedTip")
    #expect(bar.resources.strings["HelpTip"]?.table == "DemoText:5")
    #expect(bar.resources.images["SpeedArrowImg"]?.stateCount == 4)
    #expect(bar.resources.images["BarBackgroundImg"]?.stateCount == 1)
}

@Test func uisHandlesItsSyntaxQuirks() throws {
    let loaded = try uis("""
    #A comment with a <Tag> and a "quote"
    <BEGIN>
      <setsharedproperties COLOR=(1,2,3)>
      <AddText "Spread" # a comment inside a tag
         id = 7
         position = ( 10 , 20 )
         size=(30,40)
      >
      <AddText "Own" position=(0,0) size=(1,1) color=(9,9,9)>
    <end>
    <AddText "Unshared" position=(0,0) size=(1,1)>
    """)

    let spread = try #require(loaded.control(named: "Spread"))
    #expect(spread.legacyID == 7)
    #expect(spread.frame.x == 10)
    #expect(spread.frame.height == 40)
    #expect(loaded.styles["SpreadStyle"]?.textColor == Color(r: 1, g: 2, b: 3, a: 255))
    #expect(loaded.styles["OwnStyle"]?.textColor == Color(r: 9, g: 9, b: 9, a: 255))
    #expect(loaded.control(named: "Unshared")?.style == nil)
}

@Test func uisResolvesReferencesIgnoringCase() throws {
    let loaded = try uis("""
    <DefineImage "ArtImg" assetID="0x10">
    <DefineString "StatusTip" stringIndex=1>
    <AddButton "A" image="artimg" position=(0,0) toolTip="STATUSTIP">
    """)

    #expect(loaded.control(named: "A")?.image == "ArtImg")
    #expect(loaded.control(named: "A")?.tooltip == "StatusTip")
    #expect(loaded.resources.images["ArtImg"]?.assetID == "0x10")
    #expect(loaded.conversionNotes.isEmpty)
}

@Test func uisTreatsUnknownTextAsLiteralAndKnownTextAsAReference() throws {
    let loaded = try uis("""
    <DefineString "Title" stringIndex=2>
    <AddText "A" position=(0,0) size=(1,1) text="Title">
    <AddText "B" position=(0,0) size=(1,1) text="Hello there">
    """)

    #expect(loaded.control(named: "A")?.text == .string("Title"))
    #expect(loaded.control(named: "B")?.text == .literal("Hello there"))
}

@Test func uisMapsControlsAndTheirSettings() throws {
    let loaded = try uis("""
    <SetControlProperties "DialogSize" size=(500,255) minSize=(350,196)>
    <AddTextEdit "Entry" position=(1,2) size=(3,4) capacity=120 font=8 backColor=(0,0,0)>
    <AddTextEdit "Timer" position=(1,2) size=(3,4) mode="kReadOnly">
    <AddListBox "Items" position=(1,2) size=(3,4)>
    <AddSlider "Scroller" position=(1,2) size=(3,4)>
    <AddFormatedText "Rich" position=(1,2) size=(3,4)>
    <AddText "Middle" position=(1,2) size=(3,4) alignment=3>
    """)

    #expect(loaded.window.size.width == 500)
    #expect(loaded.window.minSize?.height == 196)
    #expect(loaded.control(named: "Entry")?.type == .textField)
    #expect(loaded.control(named: "Entry")?.maximumLength == 120)
    #expect(loaded.styles["EntryStyle"]?.fontSize == 8)
    #expect(loaded.control(named: "Timer")?.isReadOnly == true)
    #expect(loaded.control(named: "Items")?.type == .list)
    #expect(loaded.control(named: "Scroller")?.type == .slider)
    #expect(loaded.control(named: "Rich")?.type == .formattedText)
    #expect(loaded.control(named: "Middle")?.alignment == .center)
}

@Test func uisKeepsEverySettingForGameCodeToRead() throws {
    let loaded = try uis("""
    <DefineImage "ArtImg" path="art.bmp">
    <Begin><SetSharedProperties stringDir="UIText" stringTable=1 tint=(9,9,9)>
    <SetControlProperties "Backdrop" image="artimg" position=(1,2)>
    <SetControlProperties "PeopleSetup" position=(5,6) size=(7,8) pageSize=16>
    <SetControlProperties "Colors" normal=(1,2,3) label="Pale">
    <End>
    """)

    let backdrop = try #require(loaded.setting(named: "BACKDROP"))
    #expect(backdrop.name == "Backdrop")
    #expect(backdrop.line == 3)
    #expect(backdrop.image == "ArtImg")
    #expect(backdrop.position == Vector2(x: 1, y: 2))
    #expect(backdrop.size == nil)
    #expect(backdrop.string("stringDir") == nil)
    #expect(backdrop.numbers("Tint") == [9, 9, 9])

    let people = try #require(loaded.setting(named: "PeopleSetup"))
    #expect(people.size?.width == 7)
    #expect(people.number("pageSize") == 16)

    let colors = try #require(loaded.setting(named: "Colors"))
    #expect(colors.numbers("normal") == [1, 2, 3])
    #expect(colors.string("label") == "Pale")
    #expect(colors.number("label") == nil)
    #expect(colors.numbers("label") == nil)

    #expect(loaded.setting(named: "Missing") == nil)
    #expect(loaded.ignoredAttributes.isEmpty)
    #expect(loaded.conversionNotes.isEmpty)
}

@Test func uisSettingsStayHiddenUntilTheHostAsks() throws {
    let loaded = try uis("""
    <DefineImage "ArtImg" path="art.bmp">
    <SetControlProperties "Frame1" image="ArtImg" position=(1,2) size=(10,10)>
    <SetControlProperties "Frame2" image="ArtImg" position=(1,2) size=(10,10)>
    <SetControlProperties "Spot" position=(50,60) size=(10,10)>
    <AddText "Plain" position=(0,0) size=(1,1)>
    """)
    let view = UIScriptView(script: loaded)
    let inFrame = Vector2(x: 5, y: 5)
    let inSpot = Vector2(x: 55, y: 65)

    #expect(loaded.visual(named: "Frame1")?.isInitiallyHidden == true)
    #expect(loaded.control(named: "Spot")?.type == .region)
    #expect(loaded.control(named: "Spot")?.isInitiallyHidden == true)
    #expect(loaded.control(named: "Plain")?.isInitiallyHidden == false)
    #expect(view.isHidden(named: "Frame1"))
    #expect(view.isHidden(named: "Spot"))
    #expect(!view.isHidden(named: "Plain"))
    #expect(!view.containsPoint(inFrame, origin: .zero))
    #expect(!view.containsPoint(inSpot, origin: .zero))

    view.setHidden(false, named: "Frame2")
    view.setHidden(false, named: "Spot")
    #expect(view.isHidden(named: "Frame1"))
    #expect(view.containsPoint(inFrame, origin: .zero))
    #expect(view.containsPoint(inSpot, origin: .zero))
}

@Test func uisReportsADuplicateOrUnnamedSetting() throws {
    let loaded = try uis("""
    <SetControlProperties "Spot" number=1>
    <SetControlProperties "SPOT" number=2>
    <SetControlProperties number=3>
    """)

    #expect(loaded.setting(named: "spot")?.number("number") == 1)
    #expect(loaded.conversionNotes.map(\.line) == [2, 3])
}

@Test func uisReadsSlidersAndProgressBars() throws {
    let loaded = try uis("""
    <AddSlider "Across" position=(0,0) size=(100,10) orientation=0 minValue=2 maxValue=12>
    <AddSlider "Down" position=(0,0) size=(10,100) orientation=1>
    <AddSlider "Odd" position=(0,0) size=(10,100) orientation=7 minValue=5 maxValue=5>
    <AddProgressBar "Score" position=(0,0) size=(100,10) maxValue=50>
    <AddProgressBar "Unsized" position=(0,0)>
    """)

    #expect(loaded.control(named: "Across")?.orientation == .horizontal)
    #expect(loaded.control(named: "Across")?.valueRange == 2...12)
    #expect(loaded.control(named: "Down")?.orientation == .vertical)
    #expect(loaded.control(named: "Down")?.valueRange == nil)
    #expect(loaded.control(named: "Odd")?.orientation == nil)
    #expect(loaded.control(named: "Odd")?.valueRange == nil)
    #expect(loaded.control(named: "Score")?.type == .progressBar)
    #expect(loaded.control(named: "Score")?.valueRange == 0...50)
    #expect(loaded.conversionNotes.map(\.name) == ["Odd", "Odd", "Unsized"])
}

@Test func uisKeepsTagsWithoutAnEquivalentInItsNotes() throws {
    let loaded = try uis("<AddMystery \"Thing\" position=(0,0)>")

    #expect(loaded.controls.isEmpty)
    #expect(loaded.conversionNotes.map(\.name) == ["Thing"])
}

@Test func uisReportsWhatItCannotRepresentWithoutFailing() throws {
    let loaded = try uis("""
    <AddButton "NoImage" image="Missing" position=(0,0) tooltip="MissingTip">
    <AddText "NoSize" position=(0,0) alignment=2>
    <AddText "NoSize" position=(0,0) size=(1,1)>
    <AddText position=(0,0) size=(1,1)>
    """)

    #expect(loaded.controls.map(\.name) == ["NoImage", "NoSize", "line4"])
    #expect(loaded.control(named: "NoImage")?.frame.width == 0)
    #expect(loaded.control(named: "NoSize")?.alignment == .left)
    #expect(loaded.conversionNotes.count == 6)
}

@Test func uisKeepsSixStateImages() throws {
    let loaded = try uis("""
    <DefineImage "Strip" path="a.bmp">
    <AddButton "A" image="Strip" position=(0,0) ImageStates=6>
    """)
    let image = try #require(loaded.resources.images["Strip"])

    #expect(image.stateCount == 6)
    #expect(image.sourceRectangle(for: .disabled, textureWidth: 60, textureHeight: 10)
        == Rectangle(x: 30, y: 0, width: 10, height: 10))
}

@Test func uisSizesItsWindowToFitWhenItDeclaresNoSize() throws {
    let loaded = try uis("<AddText \"A\" position=(10,20) size=(30,40)>")

    #expect(loaded.window.size.width == 40)
    #expect(loaded.window.size.height == 60)
}

@Test(arguments: [
    "<AddText \"A\" position=(0,0)",
    "<AddText \"A",
    "<AddText \"A\" position=(0,0 >",
    "<Begin>",
    "<End>",
    "< >",
    "<AddText \"A\" <AddText \"B\">"
])
func uisRejectsBrokenSyntax(text: String) {
    #expect(throws: UIScriptError.self) {
        try uis(text)
    }
}

// The real files are not in the repository, so this runs only where they exist locally.
private let localUIScripts: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("../../stash.local/uiscripts")
    .standardizedFileURL

@Test(.enabled(if: FileManager.default.fileExists(atPath: localUIScripts.path)))
func uisReadsEveryLocalFile() throws {
    let files = try FileManager.default.contentsOfDirectory(at: localUIScripts, includingPropertiesForKeys: nil)
        .filter { $0.pathExtension == "uis" }
        .sorted { $0.path < $1.path }
    var noteCounts: [String: Int] = [:]
    var attributeCounts: [String: Int] = [:]
    var controlCount = 0
    var visualCount = 0
    var settingCount = 0
    for file in files {
        do {
            let script = try UIScript(uisContentsOf: file)
            controlCount += script.controls.count
            visualCount += script.visuals.count
            settingCount += script.settings.count
            for note in script.conversionNotes {
                let message = note.message.replacingOccurrences(of: "'[^']*'", with: "'...'", options: .regularExpression)
                noteCounts[message, default: 0] += 1
            }
            for ignored in script.ignoredAttributes {
                attributeCounts[ignored.attribute, default: 0] += 1
            }
        } catch {
            Issue.record("\(file.lastPathComponent): \(error.localizedDescription)")
        }
    }
    print("Read \(files.count) .uis files: \(controlCount) controls, \(visualCount) visuals, \(settingCount) settings")
    for (message, count) in noteCounts.sorted(by: { $0.value > $1.value }) {
        print("  \(count)x \(message)")
    }
    let attributes = attributeCounts.sorted { $0.value > $1.value }.prefix(25).map { "\($0.key) \($0.value)" }
    print("  Ignored attributes: \(attributes.joined(separator: ", "))")
}

// MARK: Tiger view features

@Test func edgeOffsetsAnchorAndStretchAgainstTheWindowSize() throws {
    let view = UIScriptView(script: try script("""
    <Region name='anchored' x='0' y='0' width='20' height='10' edgeOffsetRight='5' edgeOffsetBottom='7'/>
    <Region name='stretched' x='0' y='0' width='20' height='10' edgeOffsetLeft='3' edgeOffsetRight='5'/>
    <Region name='overshoot' x='0' y='0' width='20' height='10' edgeOffsetLeft='300' edgeOffsetRight='5'/>
    <Region name='plain' x='1' y='2' width='20' height='10'/>
    """))

    #expect(view.bounds(named: "anchored", at: .zero) == Rectangle(x: 75, y: 63, width: 20, height: 10))
    #expect(view.bounds(named: "stretched", at: .zero) == Rectangle(x: 3, y: 0, width: 92, height: 10))

    view.setWindowSize(Vector2(x: 200, y: 180))
    let origin = Vector2(x: 10, y: 20)
    #expect(view.bounds(named: "anchored", at: origin) == Rectangle(x: 185, y: 183, width: 20, height: 10))
    #expect(view.bounds(named: "stretched", at: origin) == Rectangle(x: 13, y: 20, width: 192, height: 10))
    #expect(view.bounds(named: "overshoot", at: .zero)?.width == 0)
    #expect(view.bounds(named: "plain", at: .zero) == Rectangle(x: 1, y: 2, width: 20, height: 10))
}

@Test func windowSizeStopsAtTheDocumentsMinimum() throws {
    let view = UIScriptView(script: try UIScript(data: Data("""
    <UIScript>
      <Window width="400" height="255" minWidth="350" minHeight="196"/>
      <Region name="anchored" x="0" y="0" width="20" height="10" edgeOffsetRight="5" edgeOffsetBottom="7"/>
    </UIScript>
    """.utf8)))

    #expect(view.windowSize == Vector2(x: 400, y: 255))

    view.setWindowSize(Vector2(x: 300, y: 500))
    #expect(view.windowSize == Vector2(x: 350, y: 500))
    #expect(view.bounds(named: "anchored", at: .zero) == Rectangle(x: 325, y: 483, width: 20, height: 10))

    view.setWindowSize(Vector2(x: 600, y: 100))
    #expect(view.windowSize == Vector2(x: 600, y: 196))
    #expect(view.bounds(named: "anchored", at: .zero) == Rectangle(x: 575, y: 179, width: 20, height: 10))
}

@Test func windowSizeWithoutAMinimumTakesAnySize() throws {
    let view = UIScriptView(script: try script("<Region name='r' x='0' y='0' width='20' height='10'/>"))

    view.setWindowSize(Vector2(x: 10, y: 4))
    #expect(view.windowSize == Vector2(x: 10, y: 4))
}

@Test func anchoringUsesASizeTakenFromTheImage() throws {
    let loaded = try script("<Image name='art' path='a.bmp'/><Button name='b' x='0' y='0' image='art' edgeOffsetRight='8'/>")
    let view = UIScriptView(script: loaded, loadImage: { _ in stubTexture(width: 20, height: 20) })

    #expect(view.bounds(named: "b", at: .zero) == Rectangle(x: 72, y: 0, width: 20, height: 20))
}

@Test func selectedButtonsStayOnAndStillReportPresses() throws {
    let view = UIScriptView(script: try script("<Button name='a' \(tenByTen)/>"))

    #expect(!view.isSelected(named: "a"))
    view.setSelected(true, named: "a")
    #expect(view.isSelected(named: "a"))
    #expect(view.pressButton(at: Vector2(x: 5, y: 5), origin: .zero) == .pressed(control: "a"))
    view.setSelected(false, named: "a")
    #expect(!view.isSelected(named: "a"))
}

@Test func uiScriptReadsTextAlignment() throws {
    let loaded = try script("<Text name='a' \(tenByTen) alignment='right'/><Text name='b' \(tenByTen)/>")

    #expect(loaded.control(named: "a")?.alignment == .right)
    #expect(loaded.control(named: "b")?.alignment == .left)
    #expect(throws: UIScriptError.invalidAttribute(element: "Text", attribute: "alignment", value: "middle", line: 1)) {
        try script("<Text name='a' \(tenByTen) alignment='middle'/>")
    }
}

// MARK: Leopard view features

private let sliders = """
<Slider name='across' x='0' y='0' width='102' height='10' minValue='10' maxValue='20'/>
<Slider name='down' x='200' y='0' width='10' height='102'/>
<Slider name='forced' x='300' y='0' width='10' height='102' orientation='horizontal'/>
<ProgressBar name='score' x='0' y='50' width='100' height='10' maxValue='50'/>
<Button name='plain' x='0' y='100' width='10' height='10'/>
"""

@Test func uiScriptReadsSlidersAndProgressBars() throws {
    let loaded = try script(sliders)

    #expect(loaded.control(named: "across")?.valueRange == 10...20)
    #expect(loaded.control(named: "down")?.valueRange == nil)
    #expect(loaded.control(named: "forced")?.orientation == .horizontal)
    #expect(loaded.control(named: "score")?.type == .progressBar)
    #expect(loaded.control(named: "score")?.valueRange == 0...50)
}

@Test func uiScriptRejectsBadValueRangesAndOrientations() {
    #expect(throws: UIScriptError.invalidValueRange(owner: "a")) {
        try script("<Slider name='a' \(tenByTen) minValue='5' maxValue='5'/>")
    }
    #expect(throws: UIScriptError.invalidValueRange(owner: "a")) {
        try script("<Text name='a' \(tenByTen) maxValue='5'/>")
    }
    #expect(throws: UIScriptError.invalidOrientation(owner: "a")) {
        try script("<Text name='a' \(tenByTen) orientation='vertical'/>")
    }
    #expect(throws: UIScriptError.invalidAttribute(element: "Slider", attribute: "orientation", value: "sideways", line: 1)) {
        try script("<Slider name='a' \(tenByTen) orientation='sideways'/>")
    }
}

@Test func uiScriptReadsAFillColor() throws {
    let loaded = try script("<Style name='s' fillColor='#102030'/>")

    #expect(loaded.styles["s"]?.fillColor == Color(r: 16, g: 32, b: 48, a: 255))
}

@Test func valuesStartAtTheLowestAndStayInRange() throws {
    let view = UIScriptView(script: try script(sliders))

    #expect(view.value(named: "across") == 10)
    #expect(view.value(named: "score") == 0)
    #expect(view.value(named: "plain") == nil)

    view.setValue(99, named: "across")
    #expect(view.value(named: "across") == 20)
    view.setValue(-99, named: "across")
    #expect(view.value(named: "across") == 10)
    view.setValue(.nan, named: "across")
    #expect(view.value(named: "across") == 10)
    view.setValue(25, named: "score")
    #expect(view.value(named: "score") == 25)
    view.setValue(5, named: "plain")
    #expect(view.value(named: "plain") == nil)
}

@Test func sliderFractionStaysInsideTheTrack() {
    func fraction(_ pointer: Float) -> Float {
        UIScriptView.sliderFraction(pointer: pointer, trackStart: 100, trackLength: 102, thumbLength: 10, grab: 5)
    }

    #expect(fraction(0) == 0)
    #expect(fraction(106) == 0)
    #expect(fraction(151) == 0.5)
    #expect(fraction(196) == 1)
    #expect(fraction(999) == 1)
    #expect(UIScriptView.sliderFraction(pointer: 5, trackStart: 0, trackLength: 10, thumbLength: 10, grab: 0) == 0)
}

@Test func draggingAHorizontalSliderReportsItsNewValue() throws {
    let view = UIScriptView(script: try script(sliders))
    let origin = Vector2(x: 1000, y: 1000)

    // The track's middle: a press away from the thumb centers it on the pointer.
    #expect(view.beginSliderDrag(at: Vector2(x: 1051, y: 1005), origin: origin))
    #expect(view.dragSlider(to: Vector2(x: 1051, y: 1005), origin: origin) == .changed(control: "across", value: 15))
    #expect(view.value(named: "across") == 15)

    // A pointer that has not moved reports nothing.
    #expect(view.dragSlider(to: Vector2(x: 1051, y: 1005), origin: origin) == nil)

    // The drag continues outside the track, and vertical movement does not matter.
    #expect(view.dragSlider(to: Vector2(x: 5000, y: 0), origin: origin) == .changed(control: "across", value: 20))
}

@Test func slidersFollowTheirOrientationOrShape() throws {
    let view = UIScriptView(script: try script(sliders))

    #expect(view.beginSliderDrag(at: Vector2(x: 205, y: 51), origin: .zero))
    #expect(view.dragSlider(to: Vector2(x: 205, y: 51), origin: .zero) == .changed(control: "down", value: 0.5))

    #expect(view.beginSliderDrag(at: Vector2(x: 305, y: 51), origin: .zero))
    // This tall track is forced horizontal, so its little width leaves the thumb no room.
    #expect(view.dragSlider(to: Vector2(x: 305, y: 51), origin: .zero) == nil)
    #expect(view.value(named: "forced") == 0)
}

@Test func hiddenAndDisabledSlidersCannotBeDragged() throws {
    let view = UIScriptView(script: try script(sliders))
    let point = Vector2(x: 51, y: 5)

    #expect(!view.beginSliderDrag(at: Vector2(x: 500, y: 500), origin: .zero))
    view.setDisabled(true, named: "across")
    #expect(!view.beginSliderDrag(at: point, origin: .zero))
    view.setDisabled(false, named: "across")
    view.setHidden(true, named: "across")
    #expect(!view.beginSliderDrag(at: point, origin: .zero))
    view.setHidden(false, named: "across")

    #expect(view.beginSliderDrag(at: point, origin: .zero))
    view.setHidden(true, named: "across")
    #expect(view.dragSlider(to: point, origin: .zero) == nil)
    #expect(view.value(named: "across") == 10)
}

@Test func setBoundsReplacesADocumentPositionAndOffsets() throws {
    let view = UIScriptView(script: try script("""
    <Region name='r' x='0' y='0' width='20' height='10' edgeOffsetRight='5'/>
    """))

    view.setBounds(Rectangle(x: 1, y: 2, width: 3, height: 4), named: "r")
    #expect(view.bounds(named: "r", at: Vector2(x: 10, y: 20)) == Rectangle(x: 11, y: 22, width: 3, height: 4))
}

private let tooltipBody = """
<String name='tip' table='t' index='1'/>
<String name='empty' table='t' index='2'/>
<Button name='under' x='0' y='0' width='50' height='50' tooltip='tip'/>
<Button name='blank' x='100' y='0' width='50' height='50' tooltip='empty'/>
<Button name='bare' x='200' y='0' width='50' height='50'/>
<Text name='cover' x='0' y='0' width='10' height='10'/>
"""

private func tooltipView() throws -> UIScriptView {
    UIScriptView(script: try script(tooltipBody), resolveString: { $0.index == 1 ? "Hello" : "" })
}

@Test func tooltipsWaitForThePointerToRest() throws {
    let view = try tooltipView()
    let over = Vector2(x: 25, y: 25)

    view.updateTooltip(pointer: over, origin: .zero, elapsed: 0.2)
    #expect(view.pendingTooltip == nil)
    view.updateTooltip(pointer: over, origin: .zero, elapsed: 0.4)
    #expect(view.pendingTooltip == "under")

    // A held button starts the wait again.
    view.updateTooltip(pointer: over, origin: .zero, elapsed: -.infinity)
    #expect(view.pendingTooltip == nil)

    view.updateTooltip(pointer: over, origin: .zero, elapsed: 1)
    #expect(view.pendingTooltip == "under")
    view.updateTooltip(pointer: Vector2(x: 500, y: 500), origin: .zero, elapsed: 1)
    #expect(view.pendingTooltip == nil)
    view.updateTooltip(pointer: over, origin: .zero, elapsed: 0.1)
    #expect(view.pendingTooltip == nil)
}

@Test func onlyTheTopmostVisibleControlShowsItsTooltip() throws {
    let view = try tooltipView()
    let covered = Vector2(x: 5, y: 5)

    view.updateTooltip(pointer: covered, origin: .zero, elapsed: 1)
    #expect(view.pendingTooltip == nil)
    view.setHidden(true, named: "cover")
    view.updateTooltip(pointer: covered, origin: .zero, elapsed: 1)
    #expect(view.pendingTooltip == "under")
    view.setHidden(true, named: "under")
    view.updateTooltip(pointer: covered, origin: .zero, elapsed: 1)
    #expect(view.pendingTooltip == nil)

    for point in [Vector2(x: 125, y: 25), Vector2(x: 225, y: 25)] {
        view.updateTooltip(pointer: point, origin: .zero, elapsed: 1)
        #expect(view.pendingTooltip == nil)
    }
}

@Test func tooltipsStayOnScreen() {
    let screen = Vector2(x: 200, y: 200)
    let control = Rectangle(x: 10, y: 10, width: 20, height: 20)

    let below = UIScriptView.tooltipBounds(textWidth: 50, textHeight: 12, below: control, screen: screen)
    #expect(below == Rectangle(x: 10, y: 34, width: 58, height: 20))

    let nearBottom = Rectangle(x: 10, y: 180, width: 20, height: 20)
    let above = UIScriptView.tooltipBounds(textWidth: 50, textHeight: 12, below: nearBottom, screen: screen)
    #expect(above.y == 156)

    let nearRight = Rectangle(x: 190, y: 10, width: 10, height: 10)
    #expect(UIScriptView.tooltipBounds(textWidth: 50, textHeight: 12, below: nearRight, screen: screen).x == 142)
    #expect(UIScriptView.tooltipBounds(textWidth: 500, textHeight: 12, below: nearRight, screen: screen).x == 0)
}

@Test func clearFocusRemovesFocusFromTextFields() throws {
    let view = UIScriptView(script: try script("<TextField name='a' \(tenByTen)/>"))
    let field = try #require(view.textField(named: "a"))

    field.setFocused(true)
    #expect(field.isFocused)
    view.clearFocus()
    #expect(!field.isFocused)
}

@Test func theDemoStandWorksFromItsSettingsInEitherPlace() throws {
    let stand = try UIScript(uisContentsOf: demoResource("lemonadestand.uis"))
    let view = UIScriptView(script: stand)

    #expect(stand.conversionNotes.isEmpty)
    #expect(stand.ignoredAttributes.isEmpty)
    #expect(stand.setting(named: "PanelPosition")?.position == Vector2(x: 165, y: 32))
    #expect(view.isHidden(named: "StandOpenArt"))
    #expect(view.isHidden(named: "StandClosedArt"))
    #expect(stand.control(named: "PriceSlider")?.valueRange == 1...10)
    #expect(stand.control(named: "StockBar")?.type == .progressBar)

    // The document fixes nothing about where it goes, so its parts follow the origin.
    let inPanel = try #require(view.bounds(named: "ServeButton", at: Vector2(x: 165, y: 640)))
    let inWindow = try #require(view.bounds(named: "ServeButton", at: Vector2(x: 500, y: 90)))
    #expect(inPanel.width == inWindow.width)
    #expect(inWindow.x - inPanel.x == 335)
}

@Test func theDemoModePanelsLoadCleanly() throws {
    for name in ["statspanel.uix", "optionspanel.uix"] {
        let panel = try UIScript(contentsOf: demoResource(name))
        #expect(panel.ignoredAttributes.isEmpty)
        #expect(panel.window.size.height == 160)
    }
}

// MARK: CST text

// These cover the deprecated CSTCatalog adapter: how it turns SwiftCST's tables into its own shapes.
// SwiftCST's own tests cover reading the format.

private func cst(_ text: String) -> CSTFile {
    CSTFile(data: Data(text.utf8))
}

/// Writes tables to a new temporary directory, which the caller removes.
private func temporaryTextDirectory(_ files: [String: String], under path: String = "") throws -> (root: URL, tables: URL) {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("HudiniCST-\(UUID().uuidString)")
    let tables = path.isEmpty ? root : root.appendingPathComponent(path)
    try FileManager.default.createDirectory(at: tables, withIntermediateDirectories: true)
    for (name, text) in files {
        try Data(text.utf8).write(to: tables.appendingPathComponent(name))
    }
    return (root, tables)
}

@Test func cstReadsTheEncodingsRealFilesUse() {
    let withMark = CSTFile(data: Data([0xEF, 0xBB, 0xBF]) + Data("1 ^Hint^".utf8))
    #expect(withMark.entries["1"] == "Hint")

    let utf8 = cst("1 ^Caf\u{E9}^")
    #expect(utf8.entries["1"] == "Caf\u{E9}")

    // 0xE9 and 0x92 are not valid UTF-8 here. In Windows-1252 they are an e-acute and a curly quote.
    let legacy = CSTFile(data: Data("1 ^Caf".utf8) + Data([0xE9, 0x92]) + Data("^".utf8))
    #expect(legacy.entries["1"] == "Caf\u{E9}\u{2019}")
}

@Test func cstKnowsEntriesWithoutKeysByTheirPosition() {
    let file = cst("""
    ^Zero^
    \t^One^
    ^Two
    still two^
    ^Three^
    """)

    #expect(file.entries["0"] == "Zero")
    #expect(file.entries["1"] == "One")
    #expect(file.entries["2"] == "Two\nstill two")
    #expect(file.entries["3"] == "Three")
    #expect(file.problems.isEmpty)
}

@Test func cstPositionCountsEveryEntry() {
    let file = cst("10 ^Keyed^\n^Second^\nword ^Keyed^\n^Fourth^")

    #expect(file.entries["1"] == "Second")
    #expect(file.entries["3"] == "Fourth")
}

@Test func cstFindsAnEntryByTheLineAboveItAndByPosition() {
    let file = cst("""
    kErrOne
    ^First^
    kErrTwo

    ^Second^
    ^Third^
    """)

    #expect(file.entries["kErrOne"] == "First")
    #expect(file.entries["0"] == "First")
    #expect(file.entries["kErrTwo"] == "Second")
    #expect(file.entries["1"] == "Second")
    #expect(file.entries["2"] == "Third")
    #expect(file.entries.count == 5)
}

@Test func cstLetsARealKeyWinOverALineAbove() {
    let file = cst("7\n^Numbered^\nname\n^Named^\nname ^Real^\n^Fourth^\nname\n^Fifth^")

    #expect(file.entries["7"] == "Numbered")
    #expect(file.entries["1"] == "Named")
    #expect(file.entries["name"] == "Real")
    #expect(file.entries["3"] == "Fourth")
    #expect(file.entries["4"] == "Fifth")
    #expect(file.problems.isEmpty)
}

@Test func cstReportsAnUnclosedValueAndKeepsTheEntriesAfterIt() {
    let file = cst("""
    1 ^Fine^
    2 ^Never closed
    3 ^Still found^
    ^Position three would collide^
    5 ^Never closed either
    of the file
    """)

    #expect(file.entries["1"] == "Fine")
    #expect(file.entries["2"] == nil)
    #expect(file.entries["3"] == "Still found")
    #expect(file.entries["5"] == nil)
    // The skipped value still takes a position, so the keyless value's position is 3. The key
    // written in the file wins, as SwiftCST specifies, so that isn't a problem to report.
    #expect(file.problems.map(\.line) == [2, 5])
}

@Test func cstKeepsTheFirstOfARepeatedKeyAndReportsTheOther() {
    let file = cst("1 ^First^\n1 ^Second^")

    #expect(file.entries["1"] == "First")
    #expect(file.problems.map(\.line) == [2])
}

@Test func catalogFormatsPlaceholdersAsSwiftCSTDoes() {
    #expect(CSTCatalog.format("%s has %03d, 100%% %d", with: ["Maya", "-5"]) == "Maya has -05, 100% %d")
}

@Test func catalogLoadsTablesAndLooksUpText() throws {
    let (root, tables) = try temporaryTextDirectory([
        "_174_livepanelstrings.cst": "1 ^Hello %s^\n2 ^Plain^",
        "_7_UPPER.CST": "1 ^Upper^",
        "notes.txt": "1 ^Ignored^",
        "_x_badid.cst": "1 ^Ignored^",
        "gamecompdrawacard.cst": "1 ^Ignored^"
    ])
    defer { try? FileManager.default.removeItem(at: root) }
    let catalog = try CSTCatalog(directory: tables)

    #expect(catalog.tableIDs == [7, 174])
    #expect(catalog.table(174)?.entries["2"] == "Plain")
    #expect(catalog.table(1) == nil)
    #expect(catalog.text(table: 174, key: "1", arguments: ["Maya"]) == "Hello Maya")
    #expect(catalog.text(table: 174, key: "9") == nil)
    #expect(catalog.text(table: 9, key: "1") == nil)
    #expect(catalog.text(table: 7, key: "1") == "Upper")
}

@Test func catalogResolvesDocumentStringResources() throws {
    let (root, tables) = try temporaryTextDirectory(["_174_a.cst": "1 ^One^"])
    defer { try? FileManager.default.removeItem(at: root) }
    let catalog = try CSTCatalog(directory: tables)
    let loaded = try uis("""
    <Begin><SetSharedProperties stringDir="UIText" stringTable=174>
    <DefineString "Found" stringIndex=1>
    <DefineString "Absent" stringIndex=2>
    <End>
    <DefineString "NoTable" stringIndex=1>
    <AddText "A" position=(0,0) size=(1,1) text="Found">
    <AddText "B" position=(0,0) size=(1,1) text="Absent">
    """)
    let view = UIScriptView(script: loaded, resolveString: catalog.text(for:))

    #expect(view.text(named: "A") == "One")
    #expect(view.text(named: "B") == "UIText:174#2")
    #expect(view.missingStrings == ["Absent", "NoTable"])
    #expect(UIScriptView(script: loaded).missingStrings.count == 3)
}

@Test func catalogFollowsReferencesBetweenTables() throws {
    let (root, tables) = try temporaryTextDirectory([
        "_1_a.cst": """
        1 ^\u{2}<cst><cst_id>2</cst_id><string_id>5</string_id><string arg="1">%s</string></cst>^
        2 ^\u{2}<cst><cst_id>2</cst_id><string_id>9</string_id></cst>^
        3 ^\u{2}<cst><cst_id>9</cst_id><string_id>5</string_id></cst>^
        4 ^\u{2}<cst><cst_id>1</cst_id><string_id>4</string_id></cst>^
        5 ^\u{2}<cst>broken^
        """,
        "_2_b.cst": "5 ^Kicked out by %s^"
    ])
    defer { try? FileManager.default.removeItem(at: root) }
    let catalog = try CSTCatalog(directory: tables)

    #expect(catalog.text(table: 1, key: "1", arguments: ["Maya"]) == "Kicked out by Maya")
    #expect(catalog.text(table: 1, key: "2") == nil)
    #expect(catalog.text(table: 1, key: "3") == nil)
    // A reference to a reference stops rather than risking a loop.
    #expect(catalog.text(table: 1, key: "4") == nil)
    #expect(catalog.text(table: 1, key: "5") == "\u{2}<cst>broken")
}

@Test(arguments: ["uitext/english.dir", "uitext.dir"])
func catalogFindsEitherInstallLayout(path: String) throws {
    let (root, _) = try temporaryTextDirectory(["_1_a.cst": "1 ^Found^"], under: path)
    defer { try? FileManager.default.removeItem(at: root) }

    #expect(try CSTCatalog(gameData: root).text(table: 1, key: "1") == "Found")
}

@Test func catalogFailsClearlyWhenThereIsNoText() throws {
    let (root, _) = try temporaryTextDirectory(["_1_a.cst": "1 ^Found^"], under: "uitext/english.dir")
    defer { try? FileManager.default.removeItem(at: root) }
    let missing = root.appendingPathComponent("missing")

    #expect(throws: CSTError.noTextDirectory(gameData: root.path, language: "french")) {
        try CSTCatalog(gameData: root, language: "french")
    }
    #expect(throws: CSTError.unreadable(path: missing.path)) {
        try CSTCatalog(directory: missing)
    }
}

@Test func theDemoHasTextForEveryStringItsInterfacesUse() throws {
    // The demo reads its text with SwiftCST, as games now do.
    let directory = demoResource("uitext")
    let text = UIText(directory: directory)
    let tableIDs = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        .compactMap { name in name.split(separator: "_").first.flatMap { Int($0) } }
    let documents = [
        try UIScript(contentsOf: demoResource("livepanel1024.uix")),
        try UIScript(contentsOf: demoResource("statspanel.uix")),
        try UIScript(contentsOf: demoResource("optionspanel.uix")),
        try UIScript(contentsOf: demoResource("movelot.uix")),
        try UIScript(uisContentsOf: demoResource("lemonadestand.uis")),
        try UIScript(uisContentsOf: demoResource("debugbar.uis"))
    ]

    #expect(tableIDs.count == 6)
    for id in tableIDs {
        #expect(try text.table(for: id)?.problems == [])
    }
    for document in documents {
        let view = UIScriptView(script: document) { resource in
            resource.table.split(separator: ":").last.flatMap { Int($0) }
                .flatMap { try? text.textIfPresent(for: $0, key: resource.index) }
        }
        #expect(view.missingStrings.isEmpty)
    }
}

// The real files are not in the repository, so this runs only where an install is configured.
@Test(arguments: ["TSO_BETA_DIR", "TSO_CLASSIC_DIR", "TSO_GAME_DIR"])
func catalogReadsEveryLocalVersion(variable: String) throws {
    guard let install = ProcessInfo.processInfo.environment[variable] else {
        return
    }
    let gameData = URL(fileURLWithPath: install).appendingPathComponent("gamedata")
    guard FileManager.default.fileExists(atPath: gameData.path) else {
        return
    }
    let catalog = try CSTCatalog(gameData: gameData)
    var entryCount = 0
    var problems: [String] = []
    var referenceCount = 0
    var brokenReferences: [String] = []
    for id in catalog.tableIDs {
        let table = try #require(catalog.table(id))
        entryCount += table.entries.count
        problems += table.problems.map { "\(id):\($0.line) \($0.message)" }
        for (key, value) in table.entries where value.hasPrefix("\u{2}") {
            referenceCount += 1
            if catalog.text(table: id, key: key) == nil {
                brokenReferences.append("\(id):\(key)")
            }
        }
    }
    let scripts = try FileManager.default
        .contentsOfDirectory(at: gameData.appendingPathComponent("uiscripts"), includingPropertiesForKeys: nil)
        .filter { $0.pathExtension.lowercased() == "uis" }
    var stringCount = 0
    var missing: [String] = []
    for file in scripts {
        let script = try UIScript(uisContentsOf: file)
        for (name, resource) in script.resources.strings {
            stringCount += 1
            if catalog.text(for: resource) == nil {
                missing.append("\(file.lastPathComponent):\(name) \(resource.table)#\(resource.index)")
            }
        }
    }
    print("\(variable): \(catalog.tableIDs.count) tables, \(entryCount) entries, \(problems.count) problems, \(referenceCount) references (\(brokenReferences.count) broken), \(stringCount) .uis strings (\(missing.count) missing)")
    for problem in problems.prefix(12) {
        print("  problem \(problem)")
    }
    for name in missing.sorted().prefix(12) {
        print("  missing \(name)")
    }
    if variable == "TSO_GAME_DIR" {
        // FreeSO looks up placement errors by the names above their values.
        let names = try #require(catalog.table(137)).entries.keys.filter { $0.hasPrefix("kPErr") }
        print("  table 137 names: \(names.count)")
        #expect(!names.isEmpty)
    }
    #expect(brokenReferences.isEmpty)
    #expect(catalog.tableIDs.count > 100)
}

// MARK: Text areas, monospace styles, and double-clicks

// Three 20-pixel lines, with the area's padding and line gaps.
private let threeLines = Rectangle(x: 0, y: 0, width: 200, height: 80)

@Test func uiScriptReadsATextArea() throws {
    let loaded = try script("""
        <TextArea name='notes' \(tenByTen) text='one&#10;two' placeholder='Notes' \
        maximumLength='20' readOnly='true' follows='true'/>
        """)

    #expect(loaded.ignoredAttributes.isEmpty)
    let control = try #require(loaded.control(named: "notes"))
    #expect(control.type == .textArea)
    #expect(control.follows)
    let view = UIScriptView(script: loaded)
    let area = try #require(view.textArea(named: "notes"))
    #expect(area.isReadOnly)
    #expect(area.follows)
    #expect(view.text(named: "notes") == "one\ntwo")

    view.setText("three", named: "notes")
    #expect(area.text == "three")
}

@Test func uiScriptTextAreasAcceptLongerTextByDefault() throws {
    let long = String(repeating: "a", count: 70_000)
    let view = UIScriptView(script: try script("<TextArea name='log' \(tenByTen) text='\(long)'/>"))

    #expect(view.text(named: "log")?.count == 65_536)
}

@Test func uiScriptRefusesTextAreaAttributesOnOtherControlsAndTheReverse() {
    #expect(throws: UIScriptError.invalidFollows(owner: "a")) {
        try script("<TextField name='a' \(tenByTen) follows='true'/>")
    }
    #expect(throws: UIScriptError.invalidSecure(owner: "a")) {
        try script("<TextArea name='a' \(tenByTen) secure='true'/>")
    }
    #expect(throws: UIScriptError.invalidSelectable(owner: "a")) {
        try script("<TextArea name='a' \(tenByTen) selectable='true'/>")
    }
}

@Test func scrollButtonsAndSlidersCanScrollATextArea() throws {
    let view = UIScriptView(script: try script("""
        <TextArea name='log' x='0' y='0' width='200' height='80'/>
        <Button name='up' x='300' y='0' width='10' height='10' scrolls='log' direction='up'/>
        <Slider name='bar' x='300' y='20' width='10' height='60' scrolls='log'/>
        """))
    let area = try #require(view.textArea(named: "log"))
    area.text = (1...10).map(String.init).joined(separator: "\n")
    // A document's area uses the theme's 14-pixel body size, so four lines fit.
    area.prepareLines(for: threeLines)
    area.scroll(toFraction: 1)
    #expect(area.firstVisibleLine == 6)

    #expect(view.pressButton(at: Vector2(x: 305, y: 5), origin: .zero) == nil)
    #expect(area.firstVisibleLine == 5)

    // Dragging the slider's thumb to the top of its track shows the first line, reporting nothing.
    #expect(view.beginSliderDrag(at: Vector2(x: 305, y: 75), origin: .zero))
    #expect(view.dragSlider(to: Vector2(x: 305, y: 0), origin: .zero) == nil)
    #expect(area.firstVisibleLine == 0)
}

@Test func textAreasKeepLineBreaksAndOnlyTheCharactersTheyDraw() {
    let area = TextArea(text: "one\r\ntwo\rthree\nfour\u{e9}", maximumLength: 100)

    #expect(area.text == "one\ntwo\nthree\nfour")
    #expect(area.type("\nfive"))
    #expect(area.text == "one\ntwo\nthree\nfour\nfive")
}

@Test func aTextAreaThatDoesNotFollowOpensAtItsTopAndStaysPut() {
    let area = TextArea(text: (1...10).map(String.init).joined(separator: "\n"), maximumLength: 100, fontSize: 20)
    area.prepareLines(for: threeLines)
    #expect(area.firstVisibleLine == 0)

    area.scroll(byLines: -2)
    area.text += "\n11"
    area.prepareLines(for: threeLines)
    #expect(area.firstVisibleLine == 2)
}

@Test func aFollowingTextAreaStaysAtItsLastLineUnlessScrolledBack() {
    let area = TextArea(text: (1...10).map(String.init).joined(separator: "\n"), maximumLength: 100, fontSize: 20, follows: true)
    area.prepareLines(for: threeLines)
    #expect(area.firstVisibleLine == 7)

    area.text += "\n11"
    area.prepareLines(for: threeLines)
    #expect(area.firstVisibleLine == 8)

    area.scroll(byLines: 3)
    area.text += "\n12"
    area.prepareLines(for: threeLines)
    #expect(area.firstVisibleLine == 5)
}

@Test func typingBringsTheCaretBackIntoView() {
    let area = TextArea(text: (1...10).map(String.init).joined(separator: "\n"), maximumLength: 100, fontSize: 20)
    area.prepareLines(for: threeLines)
    #expect(area.firstVisibleLine == 0)

    #expect(area.type("!"))
    area.prepareLines(for: threeLines)
    #expect(area.firstVisibleLine == 7)
}

@Test func readOnlyTextAreasRefuseFocus() {
    let area = TextArea(maximumLength: 8, isReadOnly: true)

    area.setFocused(true)
    #expect(!area.isFocused)
}

@Test func secondClickOnTheSameItemSoonAfterIsADoubleClick() {
    let (list, bounds) = pickList(itemCount: 3)

    #expect(list.select(at: row(1, of: bounds), in: bounds, time: 0) == .selected(1))
    #expect(list.select(at: row(1, of: bounds), in: bounds, time: 0.3) == .submitted(1))
    // A third click starts over.
    #expect(list.select(at: row(1, of: bounds), in: bounds, time: 0.4) == nil)
    // Too slow, or on another item, is not a double-click.
    #expect(list.select(at: row(1, of: bounds), in: bounds, time: 2) == nil)
    #expect(list.select(at: row(2, of: bounds), in: bounds, time: 2.2) == .selected(2))
}

@Test func doubleClickingAnAlreadySelectedItemStillSubmits() {
    let (list, bounds) = pickList(itemCount: 3)
    list.selectedIndex = 1

    #expect(list.select(at: row(1, of: bounds), in: bounds, time: 0) == nil)
    #expect(list.select(at: row(1, of: bounds), in: bounds, time: 0.2) == .submitted(1))
}

@Test func logListsReportNoDoubleClicks() {
    let (list, bounds) = scrollableList(itemCount: 3)

    #expect(list.select(at: row(0, of: bounds), in: bounds, time: 0) == nil)
    #expect(list.select(at: row(0, of: bounds), in: bounds, time: 0.1) == nil)
}

@Test func viewReportsADoubleClickAsSubmittedWithTheItemsText() throws {
    let view = UIScriptView(script: try script(lotList))
    let list = try #require(view.list(named: "lots"))
    list.items = ["Maple", "Oak"]

    #expect(view.selectListItem(at: Vector2(x: 10, y: 23), origin: .zero, time: 0) == .selected(control: "lots", index: 1))
    #expect(view.selectListItem(at: Vector2(x: 10, y: 23), origin: .zero, time: 0.2) == .submitted(control: "lots", text: "Oak"))
    #expect(list.selectedIndex == 1)
}

@Test func uiScriptReadsAStylesFont() throws {
    let loaded = try script("<Style name='code' font='monospace'/><Style name='plain' font='interface'/><Style name='none'/>")

    #expect(loaded.ignoredAttributes.isEmpty)
    #expect(loaded.styles["code"]?.font == .monospace)
    #expect(loaded.styles["plain"]?.font == .interface)
    #expect(loaded.styles["none"]?.font == nil)
    #expect(throws: UIScriptError.self) {
        try script("<Style name='code' font='serif'/>")
    }
}

@Test func aMonospacedThemeDrawsInItsMonospaceFontOrKeepsItsOwn() {
    var monospace = Font()
    monospace.baseSize = 12
    monospace.texture.id = 1
    var unloaded = Font()
    unloaded.baseSize = 30

    #expect(InterfaceTheme(monospaceFont: monospace).monospaced.font?.baseSize == 12)
    #expect(InterfaceTheme().monospaced.font == nil)
    // A font that failed to load counts as none, so text stays in the interface font.
    #expect(InterfaceTheme(monospaceFont: unloaded).monospaced.font == nil)
}

// MARK: Title bars from documents

// Without a window, text measures as empty, so each toolbar item is 20 pixels of padding wide. In a
// 400-wide frame, the last item spans x 372 to 392 and the one before it 348 to 368. The close
// button spans x 6 to 26, and a minimize button after it 26 to 46.
private let frameBounds = Rectangle(x: 0, y: 0, width: 400, height: 200)
private let titleBarDocument = """
    <ToolbarItem name='back' title='Back'/>
    <ToolbarItem name='go' title='Go'/>
    <TitleField name='address' placeholder='Path'/>
    """

private func documentFrame(_ body: String = titleBarDocument) throws -> (WindowFrame, UIScriptView) {
    let view = UIScriptView(script: try script(body))
    return (WindowFrame(view: view), view)
}

@Test func uiScriptReadsTitleBarElements() throws {
    let loaded = try script(titleBarDocument)

    #expect(loaded.ignoredAttributes.isEmpty)
    #expect(loaded.toolbarItems == [.init(name: "back", title: "Back"), .init(name: "go", title: "Go")])
    #expect(loaded.titleField == .init(name: "address", placeholder: "Path"))
    #expect(try script("").titleField == nil)
}

@Test func uiScriptRefusesASecondTitleFieldOrASharedName() {
    #expect(throws: UIScriptError.self) {
        try script("<TitleField name='a'/><TitleField name='b'/>")
    }
    #expect(throws: UIScriptError.duplicateName("go")) {
        try script("<ToolbarItem name='go' title='Go'/><Button name='go' \(tenByTen)/>")
    }
    #expect(throws: UIScriptError.self) {
        try script("<ToolbarItem name='go'/>")
    }
}

@Test func aViewHoldsItsTitleFieldsTextByName() throws {
    let view = UIScriptView(script: try script(titleBarDocument))

    #expect(view.text(named: "address") == "")
    view.setText("/home", named: "address")
    #expect(view.text(named: "address") == "/home")
}

@Test func toolbarItemsReportPressesUnlessDisabled() throws {
    let (frame, view) = try documentFrame()

    #expect(frame.press(at: Vector2(x: 380, y: 15), in: frameBounds) == [.view(.pressed(control: "go"))])
    #expect(frame.press(at: Vector2(x: 355, y: 15), in: frameBounds) == [.view(.pressed(control: "back"))])
    view.setDisabled(true, named: "go")
    #expect(frame.press(at: Vector2(x: 380, y: 15), in: frameBounds) == [])
}

@Test func closeAndMinimizeAreRequestsAndMinimizeIsOffByDefault() throws {
    let (frame, _) = try documentFrame("")

    #expect(frame.press(at: Vector2(x: 15, y: 15), in: frameBounds) == [.closeRequested])
    #expect(!frame.isMinimizeButton(at: Vector2(x: 35, y: 15), in: frameBounds))
    frame.showsMinimizeButton = true
    #expect(frame.press(at: Vector2(x: 35, y: 15), in: frameBounds) == [.minimizeRequested])
    frame.showsCloseButton = false
    // With no close button, minimize takes the first place.
    #expect(frame.press(at: Vector2(x: 15, y: 15), in: frameBounds) == [.minimizeRequested])
}

@Test func aTitleFieldEditSubmitsUnderItsName() throws {
    let (frame, view) = try documentFrame()

    #expect(frame.press(at: Vector2(x: 200, y: 15), in: frameBounds) == [])
    #expect(frame.isEditingTitle)
    frame.typeTitle("  /docs ")
    #expect(view.text(named: "address") == "  /docs ")

    #expect(frame.submitTitleEdit() == [.view(.submitted(control: "address", text: "/docs"))])
    #expect(!frame.isEditingTitle)
    #expect(view.text(named: "address") == "/docs")
}

@Test func aToolbarClickKeepsTheTitleEditAndSeesWhatWasTyped() throws {
    let (frame, view) = try documentFrame()
    _ = frame.press(at: Vector2(x: 200, y: 15), in: frameBounds)
    frame.typeTitle("/docs")

    #expect(frame.press(at: Vector2(x: 380, y: 15), in: frameBounds) == [.view(.pressed(control: "go"))])
    #expect(frame.isEditingTitle)
    #expect(view.text(named: "address") == "/docs")
}

@Test func aClickElsewhereCancelsTheTitleEditAndPutsTheOldTextBack() throws {
    let (frame, view) = try documentFrame()
    view.setText("/home", named: "address")
    _ = frame.press(at: Vector2(x: 200, y: 15), in: frameBounds)
    frame.typeTitle("/docs")

    #expect(frame.press(at: Vector2(x: 200, y: 100), in: frameBounds) == [])
    #expect(!frame.isEditingTitle)
    #expect(view.text(named: "address") == "/home")
}

@Test func aRefusedTitleStaysInEdit() throws {
    let (frame, view) = try documentFrame()
    frame.validateTitle = { $0.isEmpty ? "Type a path" : nil }
    _ = frame.press(at: Vector2(x: 200, y: 15), in: frameBounds)
    frame.typeTitle("   ")

    #expect(frame.submitTitleEdit() == [])
    #expect(frame.isEditingTitle)
    #expect(frame.titleValidationMessage == "Type a path")
    #expect(view.text(named: "address") == "   ")
}

@Test func aDisabledTitleFieldCannotBeEditedAndDrags() throws {
    let (frame, view) = try documentFrame()
    view.setDisabled(true, named: "address")

    #expect(frame.press(at: Vector2(x: 200, y: 15), in: frameBounds) == [])
    #expect(!frame.isEditingTitle)
    #expect(frame.beginDragging(at: Vector2(x: 200, y: 15), within: frameBounds))
}

@Test func aFrameAroundAViewDragsFromNoneOfItsItems() throws {
    let (frame, view) = try documentFrame()
    view.setSelected(true, named: "go")

    #expect(!frame.beginDragging(at: Vector2(x: 380, y: 15), within: frameBounds))
    #expect(!frame.beginDragging(at: Vector2(x: 200, y: 15), within: frameBounds))
}

@Test func aFrameAroundAViewFitsItAndSharesItsTheme() throws {
    let (frame, view) = try documentFrame("")

    let bounds = frame.place(at: Vector2(x: 0, y: 0))
    // The test documents' window is 100 by 80.
    #expect(bounds.width == 100)
    #expect(bounds.height == 80 + Float(WindowFrame.titleHeight))

    frame.theme = InterfaceTheme(textSizes: .init(body: 22))
    #expect(view.theme.textSizes.body == 22)
}

// MARK: Window manager

// Without a window, the screen measures as empty, so every window sits at the corner, 100 by 110.
private func managedFrame(_ body: String = "<TextField name='entry' x='0' y='0' width='50' height='20'/>") throws -> WindowFrame {
    WindowFrame(view: UIScriptView(script: try script(body)))
}

@Test func windowsOpenInFrontAndAPressBringsOneForward() throws {
    let manager = WindowManager()
    let back = try managedFrame()
    let front = try managedFrame()

    manager.open(back)
    manager.open(front)
    #expect(manager.windows.map(ObjectIdentifier.init) == [back, front].map(ObjectIdentifier.init))
    #expect(manager.frontWindow === front)
    #expect(manager.window(at: Vector2(x: 10, y: 10)) === front)

    manager.bringToFront(back)
    #expect(manager.frontWindow === back)
    // Opening one that's already open brings it forward rather than adding it again.
    manager.open(front)
    #expect(manager.windows.count == 2)
    #expect(manager.frontWindow === front)
}

@Test func aWindowLeavingTheFrontGivesUpTheKeyboard() throws {
    let manager = WindowManager()
    let first = try managedFrame()
    manager.open(first)
    let field = try #require(first.view?.textField(named: "entry"))
    field.setFocused(true)

    manager.open(try managedFrame())
    #expect(!field.isFocused)
}

@Test func modalWindowsStayAboveTheRestAndHoldTheInput() throws {
    let manager = WindowManager()
    let plain = try managedFrame()
    let modal = try managedFrame()
    let confirm = try managedFrame()

    manager.open(modal, modal: true)
    manager.open(plain)
    #expect(manager.hasModal)
    // A window opened under a modal one stays under it.
    #expect(manager.frontWindow === modal)

    manager.focusWindow(at: Vector2(x: 10, y: 10))
    manager.bringToFront(plain)
    #expect(manager.frontWindow === modal)

    // Modals stack, the newest on top.
    manager.open(confirm, modal: true)
    #expect(manager.frontWindow === confirm)
    manager.close(confirm)
    #expect(manager.frontWindow === modal)
    manager.close(modal)
    #expect(!manager.hasModal)
    #expect(manager.frontWindow === plain)
}

@Test func aWindowOpenedBelowAModalOneLeavesTheModalsKeyboardAlone() throws {
    let manager = WindowManager()
    let modal = try managedFrame()
    manager.open(modal, modal: true)
    let field = try #require(modal.view?.textField(named: "entry"))
    field.setFocused(true)

    manager.open(try managedFrame())
    #expect(field.isFocused)
}

@Test func minimizedWindowsStayOpenButOutOfTheWay() throws {
    let manager = WindowManager()
    let back = try managedFrame()
    let front = try managedFrame()
    manager.open(back)
    manager.open(front)

    #expect(manager.minimize(front))
    #expect(manager.isOpen(front))
    #expect(manager.isMinimized(front))
    #expect(manager.minimizedWindows.map(ObjectIdentifier.init) == [ObjectIdentifier(front)])
    #expect(manager.frontWindow === back)
    #expect(manager.window(at: Vector2(x: 10, y: 10)) === back)
    #expect(!manager.minimize(front))

    manager.restore(front)
    #expect(!manager.isMinimized(front))
    #expect(manager.frontWindow === front)
}

@Test func modalWindowsCannotBeMinimized() throws {
    let manager = WindowManager()
    let modal = try managedFrame()
    manager.open(modal, modal: true)

    #expect(!manager.minimize(modal))
    #expect(manager.frontWindow === modal)
}

@Test func closingForgetsTheWindowAndOnlyCountsOnce() throws {
    let manager = WindowManager()
    let window = try managedFrame()
    manager.open(window)

    #expect(manager.close(window))
    #expect(!manager.close(window))
    #expect(!manager.isOpen(window))
    #expect(manager.frontWindow == nil)
    #expect(!manager.contains(Vector2(x: 10, y: 10)))
    #expect(manager.bounds(of: window) == nil)
}

@Test func managedWindowsKnowWhereTheyAre() throws {
    let manager = WindowManager()
    let window = try managedFrame()
    manager.open(window, at: Vector2(x: 0, y: 0))

    #expect(manager.bounds(of: window) == Rectangle(x: 0, y: 0, width: 100, height: 80 + Float(WindowFrame.titleHeight)))
    #expect(manager.contains(Vector2(x: 50, y: 50)))
    #expect(!manager.contains(Vector2(x: 150, y: 50)))
}

@Test func eachWindowsEventsReachItsOwnHandler() throws {
    let manager = WindowManager()
    let budget = try managedFrame()
    let other = try managedFrame()
    var budgetEvents: [WindowFrame.Event] = []
    var otherEvents: [WindowFrame.Event] = []
    manager.open(budget) { budgetEvents.append($0) }
    manager.open(other) { otherEvents.append($0) }

    let delivered = manager.deliver([.closeRequested, .view(.pressed(control: "ok"))], from: budget)

    #expect(budgetEvents == [.closeRequested, .view(.pressed(control: "ok"))])
    #expect(otherEvents.isEmpty)
    #expect(delivered == [
        WindowManager.Event(window: budget, event: .closeRequested),
        WindowManager.Event(window: budget, event: .view(.pressed(control: "ok"))),
    ])
}

@Test(arguments: ["menu.uix"] + ["tools", "overview", "status", "budget", "confirm", "demand", "help", "citypanel"].map { "city/\($0).uix" })
func demoMenuAndCityDocumentsLoadCleanly(name: String) throws {
    let loaded = try UIScript(contentsOf: demoResource(name))

    #expect(loaded.ignoredAttributes.isEmpty)
}

// MARK: Style roles and dark twins

@Test func stylesTakeColorRolesAndKeepFixedColorsApart() throws {
    let loaded = try script("<Style name='quiet' textColor='secondaryText' fillColor='accent' borderColor='#102030'/>")
    let quiet = try #require(loaded.styles["quiet"])

    #expect(loaded.ignoredAttributes.isEmpty)
    #expect(quiet.colors.textColor == .role(.secondaryText))
    #expect(quiet.colors.fillColor == .role(.accent))
    #expect(quiet.colors.borderColor == .fixed(Color(r: 16, g: 32, b: 48, a: 255)))
    // The plain properties hold only what was written as a fixed color.
    #expect(quiet.textColor == nil)
    #expect(quiet.borderColor == Color(r: 16, g: 32, b: 48, a: 255))

    let resolved = quiet.resolved(in: .standard)
    #expect(resolved.textColor == InterfaceTheme.standard.secondaryText)
    #expect(resolved.fillColor == InterfaceTheme.standard.accent)
    #expect(resolved.borderColor == Color(r: 16, g: 32, b: 48, a: 255))
    #expect(resolved.backgroundColor == nil)
}

@Test func everyColorRoleResolvesToTheThemeItNames() {
    let theme = InterfaceTheme.standard

    #expect(UIScript.ColorRole.text.color(in: theme) == theme.text)
    #expect(UIScript.ColorRole.disabledText.color(in: theme) == theme.secondaryText)
    #expect(UIScript.ColorRole.highlightedText.color(in: theme) == theme.text)
    #expect(UIScript.ColorRole.panel.color(in: theme) == theme.panel)
    #expect(UIScript.ColorRole.inputBackground.color(in: theme) == theme.inputBackground)
    #expect(UIScript.ColorRole.border.color(in: theme) == theme.border)
    #expect(UIScript.ColorRole.selection.color(in: theme) == theme.selectedItem)
}

@Test func stylesTakeSizeRoles() throws {
    let loaded = try script("<Style name='heading' fontSize='largeTitle'/><Style name='fine' fontSize='caption'/>")
    let theme = InterfaceTheme(textSizes: .init(tooltip: 9, largeTitle: 30))

    #expect(loaded.styles["heading"]?.size == .role(.largeTitle))
    #expect(loaded.styles["heading"]?.fontSize == nil)
    #expect(loaded.styles["heading"]?.resolved(in: theme).fontSize == 30)
    #expect(loaded.styles["fine"]?.resolved(in: theme).fontSize == 9)
    #expect(UIScript.SizeRole.body.size(in: theme) == theme.textSizes.body)
    #expect(UIScript.SizeRole.title.size(in: theme) == theme.textSizes.title)
    #expect(throws: UIScriptError.invalidAttribute(element: "Style", attribute: "fontSize", value: "huge", line: 1)) {
        try script("<Style name='bad' fontSize='huge'/>")
    }
}

@Test func darkTwinsReplaceTheirColorsOnlyOnADarkTheme() throws {
    let loaded = try script("""
        <Style name='brand' textColor='#1E5AA0' darkTextColor='#8CB8F0' darkBorderColor='accent'/>
        """)
    let brand = try #require(loaded.styles["brand"])
    let light = InterfaceTheme(panel: .white, isDark: false)
    let dark = InterfaceTheme(panel: .white, isDark: true)

    #expect(brand.darkColors.textColor == .fixed(Color(r: 140, g: 184, b: 240, a: 255)))
    #expect(brand.resolved(in: light).textColor == Color(r: 30, g: 90, b: 160, a: 255))
    #expect(brand.resolved(in: dark).textColor == Color(r: 140, g: 184, b: 240, a: 255))
    // A twin with no light color leaves the light theme to the host's default.
    #expect(brand.resolved(in: light).borderColor == nil)
    #expect(brand.resolved(in: dark).borderColor == dark.accent)
    #expect(throws: UIScriptError.self) {
        try script("<Style name='bad' darkTextColor='reddish'/>")
    }
}

@Test func aThemeKnowsWhetherItIsDark() {
    #expect(InterfaceTheme.standard.isDark)
    #expect(!InterfaceTheme(panel: Color(r: 240, g: 240, b: 245, a: 255)).isDark)
    #expect(InterfaceTheme(panel: Color(r: 240, g: 240, b: 245, a: 255), isDark: true).isDark)
    #expect(!InterfaceTheme(panel: .black, isDark: false).isDark)
    #expect(InterfaceTheme.standard.monospaced.isDark)
}

@Test func aViewResolvesRolesAgainWhenItsThemeChanges() throws {
    let view = UIScriptView(script: try script("""
        <Style name='s' textColor='accent' fontSize='title'/>
        <List name='l' \(tenByTen) style='s'/>
        <Button name='b' \(tenByTen) style='s'/>
        """))
    let list = try #require(view.list(named: "l"))
    #expect(list.textColor == InterfaceTheme.standard.accent)
    #expect(list.fontSize == InterfaceTheme.standard.textSizes.title)

    let blue = Color(r: 110, g: 180, b: 240, a: 255)
    view.theme = InterfaceTheme(accent: blue, textSizes: .init(title: 24))

    #expect(list.textColor == blue)
    #expect(list.fontSize == 24)
    let button = try #require(view.script.control(named: "b"))
    #expect(view.resolvedStyle(for: button)?.textColor == blue)
}

@Test func uisStylesAreFixedColors() throws {
    let bar = try UIScript(uisContentsOf: demoResource("debugbar.uis"))
    let styled = try #require(bar.controls.first { bar.style(for: $0)?.colors.textColor != nil })
    let style = try #require(bar.style(for: styled))

    #expect(style.colors.textColor?.fixedColor != nil)
    #expect(style.darkColors == UIScript.StyleColors())
}

// MARK: Resizable windows

private func resizableScript(minimum: Bool) throws -> UIScript {
    let minSize = minimum ? "minWidth='120' minHeight='60'" : ""
    return try UIScript(data: Data("<UIScript><Window width='200' height='100' \(minSize) resizable='true'/></UIScript>".utf8))
}

@Test func uiScriptReadsResizable() throws {
    #expect(!(try script("").window.isResizable))
    let loaded = try resizableScript(minimum: true)
    #expect(loaded.window.isResizable)
    #expect(loaded.ignoredAttributes.isEmpty)
}

@Test func onlyAResizableWindowHasAGrip() throws {
    let fixed = WindowFrame(view: UIScriptView(script: try script("")))
    let bounds = fixed.place(at: .zero)
    let corner = Vector2(x: bounds.width - 5, y: bounds.height - 5)

    #expect(!fixed.isResizable)
    #expect(!fixed.isResizeGrip(at: corner, in: bounds))
    #expect(!fixed.beginResizing(at: corner, in: bounds))

    let resizable = WindowFrame(view: UIScriptView(script: try resizableScript(minimum: true)))
    let resizableBounds = resizable.place(at: .zero)
    #expect(resizable.isResizable)
    #expect(resizable.isResizeGrip(at: Vector2(x: 195, y: 125), in: resizableBounds))
    #expect(!resizable.isResizeGrip(at: Vector2(x: 100, y: 60), in: resizableBounds))
}

@Test func draggingTheGripResizesWithinTheDocumentsSmallestSizeAndTheScreen() throws {
    let view = UIScriptView(script: try resizableScript(minimum: true))
    let frame = WindowFrame(view: view)
    let bounds = frame.place(at: .zero)
    let screen = Vector2(x: 400, y: 300)

    #expect(frame.beginResizing(at: Vector2(x: 195, y: 125), in: bounds))
    #expect(frame.isResizing)
    frame.resize(to: Vector2(x: 245, y: 145), isHeld: true, in: bounds, screen: screen)
    #expect(view.windowSize.x == 250)
    #expect(view.windowSize.y == 120)
    // Smaller than the document allows stops at its minimum.
    frame.resize(to: Vector2(x: 0, y: 0), isHeld: true, in: bounds, screen: screen)
    #expect(view.windowSize.x == 120)
    #expect(view.windowSize.y == 60)
    // Larger than the screen stops at its edge, with the title bar counted.
    frame.resize(to: Vector2(x: 900, y: 900), isHeld: false, in: bounds, screen: screen)
    #expect(view.windowSize.x == 400)
    #expect(view.windowSize.y == 300 - Float(WindowFrame.titleHeight))
    #expect(!frame.isResizing)
    // The frame follows the content.
    #expect(frame.place(at: .zero).height == 300)
}

@Test func aResizableWindowWithoutAMinimumStaysAtLeastItsDocumentsSize() throws {
    let view = UIScriptView(script: try resizableScript(minimum: false))
    let frame = WindowFrame(view: view)
    let bounds = frame.place(at: .zero)

    #expect(frame.beginResizing(at: Vector2(x: 195, y: 125), in: bounds))
    frame.resize(to: Vector2(x: 0, y: 0), isHeld: false, in: bounds, screen: Vector2(x: 400, y: 300))
    #expect(view.windowSize.x == 200)
    #expect(view.windowSize.y == 100)
}
