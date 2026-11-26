// The appearance document a game's windows share (docs/design/2026-11-25-appearance.md): its
// reader and its checks. Windows don't inherit from it yet.

import Foundation
@testable import Hudini
import Raylib
import Testing

private func appearance(_ body: String, root: String = "<Appearance version='1'>") throws -> Appearance {
    try Appearance(data: Data("\(root)\(body)</Appearance>".utf8))
}

@Test func anAppearanceReadsItsImagesStylesAndScrollBar() throws {
    let loaded = try appearance("""
        <Image name='thumb' path='scroll/thumb.png'/>
        <Image name='up' path='scroll/up.png' assetID='0x0000031200000001' stateCount='4'/>
        <Image name='down' assetID='0x0000031100000001' stateCount='4'/>
        <Image name='track' path='scroll/track.png'/>
        <ScrollBar width='16' thumb='thumb' thumbCap='6' up='up' down='down' track='track'/>
        <Style name='chatText' textColor='#FFF99D' fontSize='body'/>
        """)

    #expect(loaded.version == 1)
    #expect(loaded.images["thumb"]?.path == "scroll/thumb.png")
    #expect(loaded.images["thumb"]?.assetID == nil)
    // Both, as UIScript's <Image> allows: the game's loadImage picks.
    #expect(loaded.images["up"]?.path == "scroll/up.png")
    #expect(loaded.images["up"]?.assetID == "0x0000031200000001")
    #expect(loaded.images["up"]?.stateCount == 4)
    #expect(loaded.images["down"]?.path == nil)
    #expect(loaded.styles["chatText"]?.textColor == Color(r: 255, g: 249, b: 157, a: 255))
    #expect(loaded.scrollBar == Appearance.ScrollBar(
        width: 16, up: "up", down: "down", thumb: "thumb", thumbCap: 6, track: "track"
    ))
    #expect(loaded.scrollBar?.imageNames == ["up", "down", "thumb", "track"])
    #expect(loaded.ignoredAttributes.isEmpty)
}

@Test func anEmptyAppearanceIsValid() throws {
    let loaded = try appearance("", root: "<Appearance>")

    #expect(loaded.version == 1)
    #expect(loaded.images.isEmpty && loaded.styles.isEmpty)
    #expect(loaded.scrollBar == nil)
}

@Test func aScrollBarsAttributesAreOptional() throws {
    let loaded = try appearance("<ScrollBar/>")

    #expect(loaded.scrollBar == Appearance.ScrollBar(width: 15, up: nil, down: nil, thumb: nil, thumbCap: 0, track: nil))
    #expect(loaded.scrollBar?.imageNames == [])
}

@Test func unknownAttributesAreSkippedAndListed() throws {
    let loaded = try appearance("<ScrollBar width='15' glow='true'/><Image name='a' path='a.png' tint='red'/>",
                                root: "<Appearance version='1' theme='dark'>")

    #expect(loaded.ignoredAttributes.map(\.element) == ["Appearance", "ScrollBar", "Image"])
    #expect(loaded.ignoredAttributes.map(\.attribute) == ["theme", "glow", "tint"])
}

@Test func aNewerAppearanceIsRefusedBeforeItsContents() {
    // The unknown element would refuse it too, but the version says what to do about it.
    #expect(throws: UIScriptError.unsupportedAppearanceVersion(2)) {
        try appearance("<Gloss/>", root: "<Appearance version='2'>")
    }
    #expect(throws: UIScriptError.invalidAttribute(element: "Appearance", attribute: "version", value: "one", line: 1)) {
        try appearance("", root: "<Appearance version='one'>")
    }
}

@Test func onlyAnAppearanceRootReadsAsOne() {
    #expect(throws: UIScriptError.invalidAppearanceRoot("UIScript")) {
        try Appearance(data: Data("<UIScript version='1'><Window width='9' height='9'/></UIScript>".utf8))
    }
    // And the reverse: a window isn't an appearance.
    #expect(throws: UIScriptError.invalidRoot("Appearance")) {
        try UIScript(data: Data("<Appearance version='1'/>".utf8))
    }
}

@Test(arguments: [
    ("<Button name='b' x='0' y='0' width='9' height='9'/>", "Button"),
    ("<String name='s' table='1' index='1'/>", "String"),
    ("<Window width='9' height='9'/>", "Window"),
    ("<Style name='s'><Image name='i' path='i.png'/></Style>", "Image"),
])
func anAppearanceHoldsOnlyImagesStylesAndAScrollBar(body: String, element: String) {
    #expect(throws: UIScriptError.unexpectedAppearanceElement(element, line: 1)) {
        try appearance(body)
    }
}

@Test func anAppearanceChecksWhatAWindowChecks() {
    #expect(throws: UIScriptError.duplicateElement("ScrollBar", line: 1)) {
        try appearance("<ScrollBar/><ScrollBar/>")
    }
    #expect(throws: UIScriptError.invalidAttribute(element: "ScrollBar", attribute: "width", value: "0", line: 1)) {
        try appearance("<ScrollBar width='0'/>")
    }
    #expect(throws: UIScriptError.invalidAttribute(element: "ScrollBar", attribute: "thumbCap", value: "-1", line: 1)) {
        try appearance("<ScrollBar thumbCap='-1'/>")
    }
    #expect(throws: UIScriptError.unknownReference(owner: "ScrollBar", property: "thumb", reference: "missing")) {
        try appearance("<ScrollBar thumb='missing'/>")
    }
    #expect(throws: UIScriptError.duplicateName("a")) {
        try appearance("<Image name='a' path='a.png'/><Image name='a' path='b.png'/>")
    }
    #expect(throws: UIScriptError.invalidImageResource(image: "a")) {
        try appearance("<Image name='a'/>")
    }
    #expect(throws: UIScriptError.invalidStateCount(image: "a")) {
        try appearance("<Image name='a' path='a.png' stateCount='3'/>")
    }
    #expect(throws: UIScriptError.invalidFontSize(style: "s")) {
        try appearance("<Style name='s' fontSize='-2'/>")
    }
    #expect(throws: UIScriptError.unexpectedText(line: 1)) {
        try appearance("text")
    }
    #expect(throws: UIScriptError.doctypeNotAllowed) {
        try Appearance(data: Data("<!DOCTYPE a><Appearance/>".utf8))
    }
}

@Test func appearanceErrorsSayAppearance() {
    let messages = [
        UIScriptError.invalidAppearanceRoot("UIScript"),
        .unsupportedAppearanceVersion(2),
        .unexpectedAppearanceElement("Button", line: 3),
    ].map { $0.errorDescription ?? "" }

    #expect(messages.allSatisfy { $0.hasPrefix("Appearance") })
    #expect(messages[2].contains("'Image', 'Style', and 'ScrollBar'"))
}

@Test func anAppearanceLoadsFromAFile() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("hudini-appearance-\(UUID()).xml")
    try Data("<Appearance version='1'><ScrollBar width='12'/></Appearance>".utf8).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }

    #expect(try Appearance(contentsOf: url).scrollBar?.width == 12)
}
