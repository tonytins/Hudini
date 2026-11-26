// The appearance document a game's windows share (docs/design/2026-11-25-appearance.md): its
// reader, its checks, its fonts (docs/design/2026-11-25-fonts.md), and windows inheriting from it.

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
    #expect(messages[2].contains("'Image', 'Style', 'Font', 'Fonts', and 'ScrollBar'"))
}

@Test func anAppearanceLoadsFromAFile() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("hudini-appearance-\(UUID()).xml")
    try Data("<Appearance version='1'><ScrollBar width='12'/></Appearance>".utf8).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }

    #expect(try Appearance(contentsOf: url).scrollBar?.width == 12)
}

// MARK: Fonts (docs/design/2026-11-25-fonts.md)

@Test func anAppearanceReadsItsFontsAndTheThemesFonts() throws {
    let loaded = try appearance("""
        <Font name='text' path='fonts/ComicNeue-Regular.ttf' size='32'/>
        <Font name='tiles' path='fonts/B612Mono-Bold.ttf' size='48'/>
        <Fonts default='text' monospace='tiles'/>
        """)

    #expect(loaded.fonts["text"] == UIScript.FontResource(path: "fonts/ComicNeue-Regular.ttf", size: 32))
    #expect(loaded.fonts["tiles"] == UIScript.FontResource(path: "fonts/B612Mono-Bold.ttf", size: 48))
    #expect(loaded.themeFonts == Appearance.ThemeFonts(default: "text", monospace: "tiles"))
    #expect(loaded.ignoredAttributes.isEmpty)
}

@Test func withoutFontsAnAppearanceKeepsTheThemes() throws {
    let loaded = try appearance("<Font name='text' path='text.ttf' size='32'/>")

    #expect(loaded.themeFonts == nil)
    // A <Fonts> may fill one font and leave the other to the theme.
    #expect(try appearance("<Font name='t' path='t.ttf' size='9'/><Fonts monospace='t'/>").themeFonts
        == Appearance.ThemeFonts(default: nil, monospace: "t"))
}

@Test func anAppearanceStyleNamesAFontOrATypeface() throws {
    let loaded = try appearance("""
        <Font name='tiles' path='tiles.ttf' size='48'/>
        <Style name='tile' font='tiles' fontSize='title'/>
        <Style name='code' font='monospace'/>
        <Style name='plain' font='interface'/>
        """)

    #expect(loaded.styles["tile"]?.fontName == "tiles")
    #expect(loaded.styles["tile"]?.font == nil)
    #expect(loaded.styles["code"]?.font == .monospace)
    #expect(loaded.styles["code"]?.fontName == nil)
    #expect(loaded.styles["plain"]?.font == .interface)
    // Resolving a style against a theme keeps the font it names.
    #expect(loaded.styles["tile"]?.resolved(in: .standard).fontName == "tiles")
}

@Test func anAppearanceChecksItsFonts() {
    #expect(throws: UIScriptError.missingAttribute(element: "Font", attribute: "name", line: 1)) {
        try appearance("<Font path='a.ttf' size='9'/>")
    }
    #expect(throws: UIScriptError.missingAttribute(element: "Font", attribute: "path", line: 1)) {
        try appearance("<Font name='a' size='9'/>")
    }
    #expect(throws: UIScriptError.missingAttribute(element: "Font", attribute: "size", line: 1)) {
        try appearance("<Font name='a' path='a.ttf'/>")
    }
    #expect(throws: UIScriptError.invalidAttribute(element: "Font", attribute: "size", value: "0", line: 1)) {
        try appearance("<Font name='a' path='a.ttf' size='0'/>")
    }
    #expect(throws: UIScriptError.invalidAttribute(element: "Font", attribute: "size", value: "12.5", line: 1)) {
        try appearance("<Font name='a' path='a.ttf' size='12.5'/>")
    }
    #expect(throws: UIScriptError.duplicateName("a")) {
        try appearance("<Font name='a' path='a.ttf' size='9'/><Font name='a' path='b.ttf' size='9'/>")
    }
    // A style's font already means these, so a <Font> can't take them.
    #expect(throws: UIScriptError.invalidAttribute(element: "Font", attribute: "name", value: "monospace", line: 1)) {
        try appearance("<Font name='monospace' path='a.ttf' size='9'/>")
    }
    #expect(throws: UIScriptError.invalidAttribute(element: "Font", attribute: "name", value: "interface", line: 1)) {
        try appearance("<Font name='interface' path='a.ttf' size='9'/>")
    }
    #expect(throws: UIScriptError.duplicateElement("Fonts", line: 1)) {
        try appearance("<Fonts/><Fonts/>")
    }
    #expect(throws: UIScriptError.unknownReference(owner: "Fonts", property: "default", reference: "missing")) {
        try appearance("<Fonts default='missing'/>")
    }
    #expect(throws: UIScriptError.unknownReference(owner: "Fonts", property: "monospace", reference: "missing")) {
        try appearance("<Fonts monospace='missing'/>")
    }
    #expect(throws: UIScriptError.unknownReference(owner: "tile", property: "font", reference: "missing")) {
        try appearance("<Style name='tile' font='missing'/>")
    }
}

@Test func aFontsUnknownAttributesAreSkippedAndListed() throws {
    let loaded = try appearance("<Font name='a' path='a.ttf' size='9' codepoints='latin'/><Fonts default='a' bold='a'/>")

    #expect(loaded.ignoredAttributes.map(\.attribute) == ["codepoints", "bold"])
}

@Test func aWindowCantNameAFont() {
    // Fonts are an appearance feature: a window keeps the spec's two typefaces.
    #expect(throws: UIScriptError.invalidAttribute(element: "Style", attribute: "font", value: "tiles", line: 1)) {
        try UIScript(data: Data("<UIScript version='1'><Style name='s' font='tiles'/><Window width='9' height='9'/></UIScript>".utf8))
    }
    #expect(throws: UIScriptError.unknownElement("Font", line: 1)) {
        try UIScript(data: Data("<UIScript version='1'><Font name='a' path='a.ttf' size='9'/><Window width='9' height='9'/></UIScript>".utf8))
    }
}

// MARK: Inheriting

private let shared = """
    <Appearance version='1'>
      <Image name='scrollThumb' path='shared/thumb.png'/>
      <Image name='scrollUp' path='shared/up.png' stateCount='4'/>
      <Image name='logo' path='shared/logo.png'/>
      <Image name='unused' path='shared/unused.png'/>
      <ScrollBar thumb='scrollThumb' thumbCap='4' up='scrollUp'/>
      <Style name='chatText' textColor='#FFF99D' fontSize='body'/>
      <Style name='unusedStyle' textColor='#000000'/>
    </Appearance>
    """

private func window(_ body: String, appearance: Appearance? = nil) throws -> UIScript {
    try UIScript(data: Data("<UIScript version='1'><Window width='400' height='300'/>\(body)</UIScript>".utf8),
                 appearance: appearance)
}

private func sharedAppearance() throws -> Appearance {
    try Appearance(data: Data(shared.utf8))
}

@Test func aWindowUsesSharedStylesAndImagesAsItsOwn() throws {
    let chat = try window("""
        <Visual name='badge' image='logo' x='0' y='0' width='10' height='10'/>
        <List name='history' x='0' y='20' width='200' height='100' style='chatText'/>
        """, appearance: try sharedAppearance())

    #expect(chat.style(for: try #require(chat.control(named: "history")))?.textColor == Color(r: 255, g: 249, b: 157, a: 255))
    #expect(chat.resources.images["logo"]?.path == "shared/logo.png")
    #expect(chat.scrollBar?.thumb == "scrollThumb")
    #expect(chat.scrollBar?.thumbCap == 4)
    #expect(chat.resources.images["scrollThumb"]?.path == "shared/thumb.png")
    #expect(chat.resources.images["scrollUp"]?.stateCount == 4)
}

@Test func onlyWhatAWindowUsesIsCopiedIn() throws {
    let chat = try window("<List name='history' x='0' y='0' width='200' height='100' style='chatText'/>",
                          appearance: try sharedAppearance())

    #expect(Set(chat.resources.images.keys) == ["scrollThumb", "scrollUp"])
    #expect(Set(chat.styles.keys) == ["chatText"])
}

@Test func aWindowWithoutAListOrTextAreaTakesNoScrollBar() throws {
    let buttons = try window("<Button name='ok' x='0' y='0' width='40' height='20' style='chatText'/>",
                             appearance: try sharedAppearance())

    #expect(buttons.scrollBar == nil)
    #expect(buttons.resources.images.isEmpty)

    let notes = try window("<TextArea name='notes' x='0' y='0' width='200' height='100'/>", appearance: try sharedAppearance())
    #expect(notes.scrollBar?.thumb == "scrollThumb")
}

@Test func aWindowOverridesASharedNameWhole() throws {
    let privateChat = try window("""
        <Image name='scrollThumb' path='private/thumb.png'/>
        <Style name='chatText' fontSize='title'/>
        <List name='history' x='0' y='0' width='200' height='100' style='chatText'/>
        """, appearance: try sharedAppearance())

    #expect(privateChat.resources.images["scrollThumb"]?.path == "private/thumb.png")
    // The window's other scroll bar image still comes from the appearance.
    #expect(privateChat.resources.images["scrollUp"]?.path == "shared/up.png")
    // Replaced whole: the window's style has no text color from the shared one.
    let style = privateChat.styles["chatText"]
    #expect(style?.size == .role(.title))
    #expect(style?.textColor == nil)
}

@Test func aNameNeitherDefinesIsStillRefused() throws {
    #expect(throws: UIScriptError.unknownReference(owner: "history", property: "style", reference: "missing")) {
        try window("<List name='history' x='0' y='0' width='200' height='100' style='missing'/>",
                   appearance: try sharedAppearance())
    }
    // Without the appearance, a window that leans on it is refused, as VentureOS refuses it.
    #expect(throws: UIScriptError.unknownReference(owner: "history", property: "style", reference: "chatText")) {
        try window("<List name='history' x='0' y='0' width='200' height='100' style='chatText'/>")
    }
}

@Test func withoutAnAppearanceAWindowReadsAsBefore() throws {
    let plain = try window("<List name='history' x='0' y='0' width='200' height='100'/>")

    #expect(plain.scrollBar == nil)
    #expect(plain.resources.images.isEmpty)
}

@Test func aViewLoadsInheritedImagesLikeItsOwn() throws {
    let chat = try window("""
        <Visual name='badge' image='logo' x='0' y='0' width='10' height='10'/>
        <List name='history' x='0' y='20' width='200' height='100'/>
        """, appearance: try sharedAppearance())
    var asked: [String] = []
    let view = UIView(script: chat, loadImage: { resource in
        asked.append(resource.path ?? "")
        return nil
    })

    #expect(Set(asked) == ["shared/logo.png", "shared/thumb.png", "shared/up.png"])
    #expect(view.missingImages == ["logo", "scrollThumb", "scrollUp"])
}

@Test func aWindowFileReadsWithAnAppearance() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("hudini-window-\(UUID()).uix")
    try Data("<UIScript version='1'><Window width='9' height='9'/><Text name='t' x='0' y='0' width='9' height='9' style='chatText'/></UIScript>".utf8).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }

    let loaded = try UIScript(contentsOf: url, appearance: try sharedAppearance())
    #expect(loaded.styles["chatText"] != nil)
}
