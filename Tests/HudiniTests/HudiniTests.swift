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
