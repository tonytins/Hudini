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
    let area = TextArea(text: "one two three", maximumLength: 7, fontSize: 20, width: 200)
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

@Test func uiScriptDecodesNamedResourcesStylesVisualsAndControls() throws {
    let data = Data(
        """
        {
          "window": {
            "size": { "width": 500, "height": 255 },
            "minSize": { "width": 350, "height": 196 }
          },
          "resources": {
            "images": {
              "scrollbar": { "path": "ui/scrollbar.bmp" }
            },
            "strings": {
              "sendTooltip": { "table": "UIText", "index": 5 }
            }
          },
          "styles": {
            "chatEntry": { "textColor": "#FFF99D", "fontSize": 8 }
          },
          "visuals": [
            {
              "name": "chatBackground",
              "image": "scrollbar",
              "frame": { "x": 19, "y": 39, "width": 341, "height": 166 }
            }
          ],
          "controls": [
            {
              "name": "chatEntry",
              "type": "textField",
              "legacyID": 5,
              "frame": {
                "x": 52, "y": 216, "width": 299, "height": 17,
                "edgeOffsets": { "left": 38, "right": 67, "bottom": 22 }
              },
              "style": "chatEntry",
              "placeholder": { "literal": "Type a message" },
              "tooltip": "sendTooltip"
            },
            {
              "name": "send",
              "type": "button",
              "frame": { "x": 360, "y": 210, "width": 24, "height": 24 },
              "image": "scrollbar",
              "text": { "string": "sendTooltip" }
            }
          ]
        }
        """.utf8
    )

    let script = try UIScript(data: data)

    #expect(script.window.size.width == 500)
    #expect(script.window.minSize?.height == 196)
    #expect(script.resources.images["scrollbar"]?.path == "ui/scrollbar.bmp")
    #expect(script.styles["chatEntry"]?.fontSize == 8)
    #expect(script.visuals.first?.name == "chatBackground")
    #expect(script.controls[0].type == UIScript.ControlType.textField)
    #expect(script.controls[0].frame.edgeOffsets?.right == 67)
    #expect(script.controls[0].tooltip == "sendTooltip")
    #expect(script.controls[0].placeholder == .literal("Type a message"))
    #expect(script.controls[1].text == UIScript.Text.string("sendTooltip"))
}

@Test func uiScriptRejectsUnknownFieldsAndControlTypes() throws {
    let unknownFieldData = Data(
        """
        {
          "window": { "size": { "width": 100, "height": 80 } },
          "futureOptionalSection": { "note": "safe to ignore" }
        }
        """.utf8
    )
    #expect(throws: DecodingError.self) {
        try UIScript(data: unknownFieldData)
    }

    let unknownControlData = Data(
        """
        {
          "window": { "size": { "width": 100, "height": 80 } },
          "controls": [
            {
              "name": "unknown",
              "type": "futureControl",
              "frame": { "x": 0, "y": 0, "width": 10, "height": 10 }
            }
          ]
        }
        """.utf8
    )
    #expect(throws: DecodingError.self) {
        try UIScript(data: unknownControlData)
    }
}

@Test func uiScriptRejectsUnknownReferencesAndInvalidFrames() {
    let unknownStyleData = Data(
        """
        {
          "window": { "size": { "width": 100, "height": 80 } },
          "controls": [
            {
              "name": "ok",
              "type": "button",
              "frame": { "x": 0, "y": 0, "width": 10, "height": 10 },
              "style": "missing"
            }
          ]
        }
        """.utf8
    )
    do {
        _ = try UIScript(data: unknownStyleData)
        Issue.record("Expected an unknown style reference to fail validation.")
    } catch let error as UIScriptError {
        #expect(error == .unknownReference(owner: "ok", property: "style", reference: "missing"))
    } catch {
        Issue.record("Unexpected error: \(error)")
    }

    let unknownPlaceholderData = Data(
        """
        {
          "window": { "size": { "width": 100, "height": 80 } },
          "controls": [
            {
              "name": "entry",
              "type": "textField",
              "frame": { "x": 0, "y": 0, "width": 40, "height": 10 },
              "placeholder": { "string": "missing" }
            }
          ]
        }
        """.utf8
    )
    do {
        _ = try UIScript(data: unknownPlaceholderData)
        Issue.record("Expected an unknown placeholder reference to fail validation.")
    } catch let error as UIScriptError {
        #expect(error == .unknownReference(owner: "entry", property: "placeholder", reference: "missing"))
    } catch {
        Issue.record("Unexpected error: \(error)")
    }

    let invalidPlaceholderData = Data(
        """
        {
          "window": { "size": { "width": 100, "height": 80 } },
          "controls": [
            {
              "name": "button",
              "type": "button",
              "frame": { "x": 0, "y": 0, "width": 40, "height": 10 },
              "placeholder": { "literal": "Invalid here" }
            }
          ]
        }
        """.utf8
    )
    do {
        _ = try UIScript(data: invalidPlaceholderData)
        Issue.record("Expected a placeholder on a non-text-field to fail validation.")
    } catch let error as UIScriptError {
        #expect(error == .invalidPlaceholder(owner: "button"))
    } catch {
        Issue.record("Unexpected error: \(error)")
    }

    let invalidFrameData = Data(
        """
        {
          "window": { "size": { "width": 100, "height": 80 } },
          "controls": [
            {
              "name": "bad",
              "type": "text",
              "frame": { "x": 0, "y": 0, "width": -1, "height": 10 }
            }
          ]
        }
        """.utf8
    )
    do {
        _ = try UIScript(data: invalidFrameData)
        Issue.record("Expected a negative frame size to fail validation.")
    } catch let error as UIScriptError {
        #expect(error == .invalidFrame(owner: "bad"))
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}

private func demoResource(_ name: String) -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("../../Sources/hudini-demo/Resources/\(name)")
        .standardizedFileURL
}

private func script(styles: String = "{}", controls: String = "[]", window: String = #"{ "size": { "width": 100, "height": 80 } }"#) throws -> UIScript {
    try UIScript(data: Data(#"{ "window": \#(window), "styles": \#(styles), "controls": \#(controls) }"#.utf8))
}

@Test func uiScriptDecodesHexColors() throws {
    let styles = ##"{ "plain": { "textColor": "#FFF99D" }, "faded": { "textColor": "#10203040" } }"##
    let decoded = try script(styles: styles)

    #expect(decoded.styles["plain"]?.textColor == Color(r: 255, g: 249, b: 157, a: 255))
    #expect(decoded.styles["faded"]?.textColor == Color(r: 16, g: 32, b: 48, a: 64))
}

@Test(arguments: ["FFF99D", "#FFF", "#GGGGGG", "#+12345", "#FFF99D0", "", "#１２３４５６"])
func uiScriptRejectsInvalidColors(color: String) {
    let styles = #"{ "bad": { "backgroundColor": "\#(color)" } }"#
    #expect(throws: DecodingError.self) {
        try script(styles: styles)
    }
}

@Test(arguments: [0, -4])
func uiScriptRejectsNonpositiveFontSizes(fontSize: Int) {
    #expect(throws: UIScriptError.invalidFontSize(style: "bad")) {
        try script(styles: #"{ "bad": { "fontSize": \#(fontSize) } }"#)
    }
}

@Test func uiScriptRejectsDuplicateControlNames() {
    let control = #"{ "name": "twin", "type": "text", "frame": { "x": 0, "y": 0, "width": 1, "height": 1 } }"#
    #expect(throws: UIScriptError.duplicateName("twin")) {
        try script(controls: "[\(control), \(control)]")
    }
}

@Test func uiScriptRejectsMinimumSizeLargerThanWindow() {
    let window = #"{ "size": { "width": 100, "height": 80 }, "minSize": { "width": 101, "height": 80 } }"#
    #expect(throws: UIScriptError.invalidMinimumWindowSize) {
        try script(window: window)
    }
}

@Test func uiScriptFindsAControlsStyleAndScreenBounds() throws {
    let decoded = try script(
        styles: #"{ "label": { "fontSize": 9 } }"#,
        controls: #"[{ "name": "a", "type": "text", "style": "label", "frame": { "x": 5, "y": 6, "width": 7, "height": 8 } }]"#
    )
    let control = decoded.controls[0]

    #expect(decoded.style(for: control)?.fontSize == 9)
    #expect(control.frame.rectangle(at: Vector2(x: 10, y: 20)) == Rectangle(x: 15, y: 26, width: 7, height: 8))
}

@Test func chatDialogControlsFitInsideItsWindow() throws {
    let chat = try UIScript(contentsOf: demoResource("chatdialog.json"))

    for control in chat.controls {
        #expect(control.frame.x + control.frame.width <= chat.window.size.width, "\(control.name) is too wide")
        #expect(control.frame.y + control.frame.height <= chat.window.size.height, "\(control.name) is too tall")
    }
}

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

private func frameJSON(x: Int = 0) -> String {
    #"{ "x": \#(x), "y": 0, "width": 10, "height": 10 }"#
}

private func scrollControls(type: String, scrolls: String) -> String {
    #"""
    [
      { "name": "history", "type": "list", "frame": \#(frameJSON()) },
      { "name": "label", "type": "text", "frame": \#(frameJSON()) },
      { "name": "scroller", "type": "\#(type)", "frame": \#(frameJSON()), "scrolls": \#(scrolls) }
    ]
    """#
}

@Test func scrollBindingsDecodeForSlidersAndButtons() throws {
    let slider = try script(controls: scrollControls(type: "slider", scrolls: #"{ "list": "history" }"#))
    #expect(slider.control(named: "scroller")?.scrolls?.list == "history")
    #expect(slider.control(named: "scroller")?.scrolls?.direction == nil)

    let button = try script(controls: scrollControls(type: "button", scrolls: #"{ "list": "history", "direction": "up" }"#))
    #expect(button.control(named: "scroller")?.scrolls?.direction == .up)
}

@Test(arguments: [
    ("slider", #"{ "list": "history", "direction": "up" }"#),
    ("button", #"{ "list": "history" }"#),
    ("text", #"{ "list": "history" }"#),
    ("slider", #"{ "list": "label" }"#),
])
func uiScriptRejectsMismatchedScrollBindings(type: String, scrolls: String) {
    #expect(throws: UIScriptError.invalidScrollBinding(owner: "scroller")) {
        try script(controls: scrollControls(type: type, scrolls: scrolls))
    }
}

@Test func uiScriptRejectsScrollBindingsToMissingLists() {
    let controls = scrollControls(type: "slider", scrolls: #"{ "list": "missing" }"#)
    #expect(throws: UIScriptError.unknownReference(owner: "scroller", property: "scrolls", reference: "missing")) {
        try script(controls: controls)
    }
}

@Test(arguments: [
    #"{ "name": "entry", "type": "textField", "frame": { "x": 0, "y": 0, "width": 1, "height": 1 }, "maximumLength": 0 }"#,
    #"{ "name": "entry", "type": "button", "frame": { "x": 0, "y": 0, "width": 1, "height": 1 }, "maximumLength": 5 }"#,
])
func uiScriptRejectsInvalidMaximumLengths(control: String) {
    #expect(throws: UIScriptError.invalidMaximumLength(owner: "entry")) {
        try script(controls: "[\(control)]")
    }
}

@Test func viewBuildsControlsAndFindsThemByKind() throws {
    let view = UIScriptView(script: try UIScript(contentsOf: demoResource("chatdialog.json")))

    #expect(view.list(named: "chatHistory") != nil)
    #expect(view.textField(named: "chatEntry") != nil)
    #expect(view.list(named: "chatEntry") == nil)
    #expect(view.textField(named: "missing") == nil)
}

@Test func viewAppliesDocumentSettingsToTextFields() throws {
    let view = UIScriptView(script: try UIScript(contentsOf: demoResource("chatdialog.json")))
    let entry = try #require(view.textField(named: "chatEntry"))

    entry.text = String(repeating: "a", count: 500)
    #expect(entry.length == 120)
}

@Test func viewScrollButtonsMoveTheirListWithoutReportingAnEvent() throws {
    let view = UIScriptView(script: try UIScript(contentsOf: demoResource("chatdialog.json")))
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
    let view = UIScriptView(script: try script(controls: #"""
    [
      { "name": "lower", "type": "button", "frame": \#(frameJSON()) },
      { "name": "upper", "type": "button", "frame": \#(frameJSON()) }
    ]
    """#))
    let point = Vector2(x: 5, y: 5)

    #expect(view.pressButton(at: point, origin: .zero) == .pressed(control: "upper"))

    view.setHidden(true, forControlNamed: "upper")
    #expect(view.isHidden(controlNamed: "upper"))
    #expect(view.pressButton(at: point, origin: .zero) == .pressed(control: "lower"))

    view.setHidden(false, forControlNamed: "upper")
    #expect(view.pressButton(at: point, origin: .zero) == .pressed(control: "upper"))
    #expect(view.pressButton(at: Vector2(x: 50, y: 50), origin: .zero) == nil)
}

@Test func viewResolvesStringReferencesThroughTheHost() throws {
    let document = Data(#"""
    {
      "window": { "size": { "width": 100, "height": 80 } },
      "resources": { "strings": { "hint": { "table": "UIText", "index": 7 } } },
      "controls": [
        { "name": "entry", "type": "textField", "frame": { "x": 0, "y": 0, "width": 9, "height": 9 }, "text": { "string": "hint" } }
      ]
    }
    """#.utf8)
    let parsed = try UIScript(data: document)

    let resolved = UIScriptView(script: parsed) { "\($0.table) string \($0.index)" }
    #expect(resolved.textField(named: "entry")?.text == "UIText string 7")

    let unresolved = UIScriptView(script: parsed)
    #expect(unresolved.textField(named: "entry")?.text == "UIText#7")
}

@Test func livePanelDraftDecodesWithTheCurrentUIScriptModel() throws {
    let script = try UIScript(contentsOf: demoResource("livepanel1024.json"))

    #expect(script.window.size.width == 1024)
    #expect(script.controls.count == 12)
    #expect(script.controls.contains { $0.name == "peopleList" && $0.type == .list })
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
    let description = TextArea(text: "A place to explore.", maximumLength: 200, width: 300)
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
