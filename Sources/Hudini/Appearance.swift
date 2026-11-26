import Foundation

/// The images, styles, and scroll bar art a game's windows share, read from one appearance
/// document that the game loads.
///
/// An appearance is a Hudini feature, not part of the UIScript spec. It holds UIScript's own
/// `<Image>` and `<Style>` elements, and a `<ScrollBar>` naming the images a list's or text area's
/// scroll bar draws with:
///
/// ```xml
/// <Appearance version="1">
///   <Image name="scrollThumb" path="scroll/thumb.png"/>
///   <Image name="scrollUp" path="scroll/up.png" stateCount="4"/>
///   <ScrollBar thumb="scrollThumb" thumbCap="6" up="scrollUp"/>
///   <Style name="chatText" textColor="#FFF99D" fontSize="body"/>
/// </Appearance>
/// ```
///
/// The document rules are UIScript's: elements sit directly under the root and hold no text, an
/// unknown element refuses the document, and an unknown attribute is skipped and listed in
/// `ignoredAttributes`. See `docs/design/2026-11-25-appearance.md`.
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

    /// Attributes this reader did not recognize and ignored.
    public let ignoredAttributes: [UIScript.IgnoredAttribute]

    /// The images a scroll bar draws with. A part without an image draws from the theme.
    public struct ScrollBar: Sendable, Equatable {
        /// The bar's width in pixels, above 0. The arrows are as tall as the bar is wide.
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

        /// The names of every image the bar draws with.
        public var imageNames: [String] {
            [up, down, thumb, track].compactMap { $0 }
        }
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
        ignoredAttributes: [UIScript.IgnoredAttribute]
    ) {
        self.version = version
        self.images = images
        self.styles = styles
        self.scrollBar = scrollBar
        self.ignoredAttributes = ignoredAttributes
    }

    private func validate() throws {
        try UIScript.validate(images: images, styles: styles)
        guard let scrollBar else {
            return
        }
        for (property, name) in [("up", scrollBar.up), ("down", scrollBar.down), ("thumb", scrollBar.thumb), ("track", scrollBar.track)] {
            if let name, images[name] == nil {
                throw UIScriptError.unknownReference(owner: "ScrollBar", property: property, reference: name)
            }
        }
    }
}
