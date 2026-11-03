// These run without a window. Measuring text needs the font a window loads, so the checks
// here stay with what doesn't draw: the camera's math and what the text boxes accept.

import Foundation
import Hudini
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
    #expect(panel.resources.images["nextPage"]?.assetID == "0x0000049000000001")
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
