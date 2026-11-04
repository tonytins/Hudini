// These run without a window. Measuring text needs the font a window loads, so the checks
// here stay with what doesn't draw: the camera's math and what the text boxes accept.

import Foundation
@testable import Hudini
import Raylib
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
        .appendingPathComponent("../../Sources/hudini-demo/Resources/\(name)")
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

@Test func uiScriptRefusesRequiredFeaturesItDoesNotUnderstand() {
    #expect(throws: UIScriptError.unsupportedFeature("futureLayout")) {
        try script("<FutureThing/>", root: "requires='futureLayout'")
    }
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
    let view = UIScriptView(script: try UIScript(contentsOf: demoResource("chatdialog.xml")))

    #expect(view.list(named: "chatHistory") != nil)
    #expect(view.textField(named: "chatEntry") != nil)
    #expect(view.list(named: "chatEntry") == nil)
    #expect(view.textField(named: "missing") == nil)
}

@Test func viewAppliesDocumentSettingsToTextFields() throws {
    let view = UIScriptView(script: try UIScript(contentsOf: demoResource("chatdialog.xml")))
    let entry = try #require(view.textField(named: "chatEntry"))

    entry.text = String(repeating: "a", count: 500)
    #expect(entry.text.count == 120)
}

@Test func viewScrollButtonsMoveTheirListWithoutReportingAnEvent() throws {
    let view = UIScriptView(script: try UIScript(contentsOf: demoResource("chatdialog.xml")))
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
    let chat = try UIScript(contentsOf: demoResource("chatdialog.xml"))
    let view = UIScriptView(script: chat)

    for control in chat.controls {
        let bounds = try #require(view.bounds(named: control.name, at: .zero))
        #expect(bounds.x + bounds.width <= chat.window.size.width, "\(control.name) is too wide")
        #expect(bounds.y + bounds.height <= chat.window.size.height, "\(control.name) is too tall")
    }
}

// Both roadmap examples must work through the same model and view, with different compositions.
@Test func chatAndLivePanelShareOneModelWithoutSharingALayout() throws {
    let chat = try UIScript(contentsOf: demoResource("chatdialog.xml"))
    let panel = try UIScript(contentsOf: demoResource("livepanel1024.xml"))
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
    for name in ["chatdialog.xml", "livepanel1024.xml"] {
        #expect(try UIScript(contentsOf: demoResource(name)).ignoredAttributes.isEmpty, "\(name)")
    }
}

@Test func livePanelReadsWithTheCurrentModel() throws {
    let panel = try UIScript(contentsOf: demoResource("livepanel1024.xml"))

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

    let below = UIScriptView.tooltipBounds(textWidth: 50, below: control, screen: screen)
    #expect(below == Rectangle(x: 10, y: 34, width: 58, height: 20))

    let nearBottom = Rectangle(x: 10, y: 180, width: 20, height: 20)
    let above = UIScriptView.tooltipBounds(textWidth: 50, below: nearBottom, screen: screen)
    #expect(above.y == 156)

    let nearRight = Rectangle(x: 190, y: 10, width: 10, height: 10)
    #expect(UIScriptView.tooltipBounds(textWidth: 50, below: nearRight, screen: screen).x == 142)
    #expect(UIScriptView.tooltipBounds(textWidth: 500, below: nearRight, screen: screen).x == 0)
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
    for name in ["statspanel.xml", "optionspanel.xml"] {
        let panel = try UIScript(contentsOf: demoResource(name))
        #expect(panel.ignoredAttributes.isEmpty)
        #expect(panel.window.size.height == 160)
    }
}

// MARK: CST text

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

@Test func cstReadsEveryEntryLayoutRealFilesUse() {
    let file = cst("""
    1 ^Same line^
    \t2 ^Indented with a tab^
      3 ^Indented with spaces^
    4
    ^Value below its key^
    5 ^First line
    Second line^
    word ^A word as a key^
    6^No space^
    7 ^^

    """)

    #expect(file.entries["1"] == "Same line")
    #expect(file.entries["2"] == "Indented with a tab")
    #expect(file.entries["3"] == "Indented with spaces")
    #expect(file.entries["4"] == "Value below its key")
    #expect(file.entries["5"] == "First line\nSecond line")
    #expect(file.entries["word"] == "A word as a key")
    #expect(file.entries["6"] == "No space")
    #expect(file.entries["7"] == "")
    #expect(file.problems.isEmpty)
}

@Test func cstIgnoresComments() {
    let file = cst("""
    // A comment with 1 ^Not this^
    # Another with 2 ^Not this^
    /* A block with
    3 ^Not this^
    still going */
    /* One line */
    4 ^First
    // Not part of the value
    Last^
    5 ^Has // and # inside^
    """)

    #expect(file.entries.keys.sorted() == ["4", "5"])
    #expect(file.entries["4"] == "First\nLast")
    #expect(file.entries["5"] == "Has // and # inside")
}

@Test func theSpecExampleReadsAsDocumented() throws {
    let page = try String(contentsOf: demoResource("../../../doc/CST.md"), encoding: .utf8)
    let opening = try #require(page.range(of: "```text\n"))
    let closing = try #require(page.range(of: "```", range: opening.upperBound..<page.endIndex))
    let file = cst(String(page[opening.upperBound..<closing.lowerBound]))

    #expect(file.problems.isEmpty)
    #expect(file.entries["1"] == "A value after its key")
    #expect(file.entries["2"] == "An indented key")
    #expect(file.entries["3"] == "A key above its value")
    #expect(file.entries["4"] == "A value that runs\nacross lines")
    #expect(file.entries["ok button"] == "A key with spaces")
    #expect(file.entries["kErrNoFood"] == "A name above its value")
    #expect(file.entries["5"] == "A name above its value")
    #expect(file.entries["A note for translators."] == "A value with a note above it")
    #expect(file.entries["6"] == "A value with a note above it")
    #expect(file.entries["7"] == "A value on its own")
    #expect(file.entries["8"] == "Another value on its own")
    #expect(file.entries.count == 11)
}

@Test func cstNormalizesLineEndings() {
    let file = cst("1 ^One\r\nTwo^\r\n2 ^Three\rFour^\r3 ^Five\u{2028}Six^")

    #expect(file.entries["1"] == "One\nTwo")
    #expect(file.entries["2"] == "Three\nFour")
    #expect(file.entries["3"] == "Five\nSix")
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

@Test func cstTreatsTextBetweenEntriesAsNotes() {
    let file = cst("""
    #145#OptionStrs.cst
    The next ones are tool tips, so read on
    tooltips

    ^First^
    1st column
    ^Second^
    2 - refund
    ^Third^
    """)

    #expect(file.entries["0"] == "First")
    #expect(file.entries["1"] == "Second")
    #expect(file.entries["2"] == "Third")
    #expect(file.problems.isEmpty)
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

@Test func cstDoesNotTakeAKeyFromTextAfterAValue() {
    let file = cst("^p^ pause\n^q^ quit\n^r^")

    #expect(file.entries.keys.sorted() == ["0", "1", "2"])
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

@Test func cstKeepsAKeyWithSpaces() {
    let file = cst("ok button ^OK^\n24 012 ^Failed^")

    #expect(file.entries["ok button"] == "OK")
    #expect(file.entries["24 012"] == "Failed")
}

@Test func cstReadsMoreThanOneEntryOnALine() {
    let file = cst("7 ^One^ 8 ^Two^ ^Third^")

    #expect(file.entries["7"] == "One")
    #expect(file.entries["8"] == "Two")
    #expect(file.entries["2"] == "Third")
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
    // The skipped value still takes a position, so the keyless entry collides with key 3.
    #expect(file.problems.map(\.line) == [2, 4, 5])
}

@Test func cstKeepsTheFirstOfARepeatedKeyAndReportsTheOther() {
    let file = cst("1 ^First^\n1 ^Second^")

    #expect(file.entries["1"] == "First")
    #expect(file.problems.map(\.line) == [2])
}

@Test func cstClosingCaretOnItsOwnLineEndsAValue() {
    let file = cst("1 ^First line\nlast ^\n2 ^Next^\n3 ^One\n^\n4 ^After^")

    #expect(file.entries["1"] == "First line\nlast ")
    #expect(file.entries["2"] == "Next")
    #expect(file.entries["3"] == "One\n")
    #expect(file.entries["4"] == "After")
    #expect(file.problems.isEmpty)
}

@Test(arguments: [
    ("Hello %s!", ["Maya"], "Hello Maya!"),
    ("%s has %d of %i and %u", ["A", "1", "2", "3"], "A has 1 of 2 and 3"),
    ("%3d|%03d|%.3d", ["7", "7", "7"], "  7|007|007"),
    ("%.2d:%.2d", ["5", "30"], "05:30"),
    ("%3s", ["a"], "a"),
    ("100%%", [], "100%"),
    ("%ld properties", ["3"], "3 properties"),
    ("%d.%02d", ["5", "7"], "5.07"),
    ("<%> says", ["no"], "<%> says"),
    ("%s and %s", ["only"], "only and %s"),
    ("%d", [], "%d"),
    ("%.3d", [], "%.3d"),
    ("extra", ["ignored"], "extra"),
    ("10% off, %l, %. and %", ["no"], "10% off, %l, %. and %")
])
func cstFormatsPlaceholders(text: String, arguments: [String], expected: String) {
    #expect(CSTCatalog.format(text, with: arguments) == expected)
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
    let catalog = try CSTCatalog(directory: demoResource("uitext"))
    let documents = [
        try UIScript(contentsOf: demoResource("livepanel1024.xml")),
        try UIScript(contentsOf: demoResource("statspanel.xml")),
        try UIScript(contentsOf: demoResource("optionspanel.xml")),
        try UIScript(uisContentsOf: demoResource("lemonadestand.uis")),
        try UIScript(uisContentsOf: demoResource("debugbar.uis"))
    ]

    for id in catalog.tableIDs {
        #expect(catalog.table(id)?.problems.isEmpty == true)
    }
    for document in documents {
        #expect(UIScriptView(script: document, resolveString: catalog.text(for:)).missingStrings.isEmpty)
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
