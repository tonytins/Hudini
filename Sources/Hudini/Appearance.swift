import Foundation

/// The images, styles, fonts, and scroll bar art a game's windows share, read from one appearance
/// document that the game loads.
///
/// An appearance is a Hudini feature, not part of the UIScript spec. It holds UIScript's own
/// `<Image>` and `<Style>` elements, a `<ScrollBar>` naming the images a list's or text area's
/// scroll bar draws with, and `<Font>` files, which `<Fonts>` makes the theme's fonts and a
/// `<Style>` can name in its `font`:
///
/// ```xml
/// <Appearance version="1">
///   <Image name="scrollThumb" path="scroll/thumb.png"/>
///   <Image name="scrollUp" path="scroll/up.png" stateCount="4"/>
///   <ScrollBar thumb="scrollThumb" thumbCap="6" up="scrollUp"/>
///   <Font name="text" path="fonts/ComicNeue-Regular.ttf" size="32"/>
///   <Font name="tiles" path="fonts/B612Mono-Bold.ttf" size="48"/>
///   <Fonts default="text"/>
///   <Style name="chatText" textColor="#FFF99D" fontSize="body"/>
///   <Style name="tile" font="tiles" fontSize="title"/>
/// </Appearance>
/// ```
///
/// The document rules are UIScript's: elements sit directly under the root and hold no text, an
/// unknown element refuses the document, and an unknown attribute is skipped and listed in
/// `ignoredAttributes`. See `docs/design/2026-11-25-appearance.md` and
/// `docs/design/2026-11-25-fonts.md`.
public struct Appearance: Sendable {
    /// The newest appearance version this reader understands. A newer one is refused.
    public static let supportedVersion = 1

    /// The scroll bar's width when the appearance doesn't give one, matching the classic bar.
    public static let defaultScrollBarWidth: Float = 15

    /// The version the document declares, which defaults to 1.
    public let version: Int

    /// Images keyed by name, which windows share.
    public let images: [String: UIScript.ImageResource]

    /// Styles keyed by name, which windows share.
    public let styles: [String: UIScript.Style]

    /// The art lists' and text areas' scroll bars draw with, or `nil` for the theme's classic bar.
    public let scrollBar: ScrollBar?

    /// Font files keyed by name, which `themeFonts` and styles name.
    public let fonts: [String: UIScript.FontResource]

    /// The fonts that replace the theme's, or `nil` to keep the theme's.
    public let themeFonts: ThemeFonts?

    /// Names a style's `font` takes for the theme's fonts, which a `<Font>` can't use.
    static let reservedFontNames: Set<String> = ["interface", "monospace"]

    /// Attributes this reader did not recognize and ignored.
    public let ignoredAttributes: [UIScript.IgnoredAttribute]

    /// The images a scroll bar draws with. A part without an image draws from the theme.
    ///
    /// The track and thumb come either from `thumb` and `track`, each stretched, or from one packed
    /// `slider` image, as The Sims Online draws them. See
    /// `docs/design/2026-11-26-packed-scroll-bar.md`.
    public struct ScrollBar: Sendable, Equatable {
        /// The bar's width in pixels, above 0. The arrows are as tall as the bar is wide. With
        /// `slider`, it's left at the default and unused: the bar is as wide as its art.
        public let width: Float

        /// The up arrow's image. With four states, it shows normal, pressed, hovered, and disabled.
        public let up: String?

        /// The down arrow's image, sliced as `up` is.
        public let down: String?

        /// The thumb's image, stretched to the thumb's length.
        public let thumb: String?

        /// Pixels at the thumb image's top and bottom that keep their size while its middle
        /// stretches. Zero stretches the whole image.
        public let thumbCap: Float

        /// An image stretched behind the thumb, between the arrows.
        public let track: String?

        /// One image holding the track and the thumb: the track in its top three-quarters, whose
        /// thirds keep their ends' shape while the middle stretches, and the thumb in its bottom
        /// quarter, drawn at its own size. With it, every part of the bar is drawn at its own
        /// size. It can't be combined with `thumb`, `track`, `thumbCap`, or `width`.
        public let slider: String?

        init(
            width: Float = Appearance.defaultScrollBarWidth,
            up: String? = nil,
            down: String? = nil,
            thumb: String? = nil,
            thumbCap: Float = 0,
            track: String? = nil,
            slider: String? = nil
        ) {
            self.width = width
            self.up = up
            self.down = down
            self.thumb = thumb
            self.thumbCap = thumbCap
            self.track = track
            self.slider = slider
        }

        /// The names of every image the bar draws with.
        public var imageNames: [String] {
            [up, down, thumb, track, slider].compactMap { $0 }
        }
    }

    /// The fonts an appearance's `<Fonts>` puts in place of the theme's, by `<Font>` name. A
    /// font left out keeps the theme's.
    public struct ThemeFonts: Sendable, Equatable {
        /// The font text uses without a `font` in its style, or with `font="interface"`. It
        /// replaces `InterfaceTheme.font`.
        public let `default`: String?

        /// The font a style with `font="monospace"` uses. It replaces
        /// `InterfaceTheme.monospaceFont`.
        public let monospace: String?
    }

    /// Parses and validates an appearance document, which must be UTF-8.
    public init(data: Data) throws {
        let appearance = try UIScriptParser.parseAppearance(data)
        try appearance.validate()
        self = appearance
    }

    /// Loads and validates an appearance document from a file URL.
    public init(contentsOf url: URL) throws {
        try self.init(data: Data(contentsOf: url))
    }

    init(
        version: Int,
        images: [String: UIScript.ImageResource],
        styles: [String: UIScript.Style],
        scrollBar: ScrollBar?,
        fonts: [String: UIScript.FontResource] = [:],
        themeFonts: ThemeFonts? = nil,
        ignoredAttributes: [UIScript.IgnoredAttribute]
    ) {
        self.version = version
        self.images = images
        self.styles = styles
        self.scrollBar = scrollBar
        self.fonts = fonts
        self.themeFonts = themeFonts
        self.ignoredAttributes = ignoredAttributes
    }

    private func validate() throws {
        try UIScript.validate(images: images, styles: styles)
        for (name, style) in styles {
            if let fontName = style.fontName, fonts[fontName] == nil {
                throw UIScriptError.unknownReference(owner: name, property: "font", reference: fontName)
            }
        }
        if let themeFonts {
            for (property, name) in [("default", themeFonts.default), ("monospace", themeFonts.monospace)] {
                if let name, fonts[name] == nil {
                    throw UIScriptError.unknownReference(owner: "Fonts", property: property, reference: name)
                }
            }
        }
        guard let scrollBar else {
            return
        }
        for (property, name) in [("up", scrollBar.up), ("down", scrollBar.down), ("thumb", scrollBar.thumb), ("track", scrollBar.track), ("slider", scrollBar.slider)] {
            if let name, images[name] == nil {
                throw UIScriptError.unknownReference(owner: "ScrollBar", property: property, reference: name)
            }
        }
    }
}
