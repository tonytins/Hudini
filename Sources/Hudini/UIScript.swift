import Foundation
import Raylib

/// A loaded Hudini interface document.
///
/// UIScript documents describe presentation. The host game remains responsible
/// for control state, actions, and resolving image and localized-string data.
/// See `doc/UISCRIPT.md` for the XML format.
public struct UIScript: Sendable {
    /// The newest document version this reader understands.
    public static let supportedVersion = 1

    /// The named features this reader understands in a document's `requires` list.
    public static let supportedFeatures: Set<String> = []

    /// The document's format version.
    public let version: Int

    /// The features the document says a reader must understand.
    public let requiredFeatures: [String]

    /// Window-level size settings.
    public let window: Window

    /// Named image and localized-string references.
    public let resources: Resources

    /// Named styles referenced by controls.
    public let styles: [String: Style]

    /// Named decorative visuals drawn independently of controls.
    public let visuals: [Visual]

    /// The controls in document order.
    public let controls: [Control]

    /// Attributes this reader did not recognize and ignored.
    ///
    /// Newer documents may add optional attributes, so these are not errors. A
    /// misspelled attribute also lands here, so hosts may want to log them.
    public let ignoredAttributes: [IgnoredAttribute]

    /// Parses and validates a UIScript XML document, which must be UTF-8.
    public init(data: Data) throws {
        let document = try UIScriptParser.parse(data)
        try document.validate()
        self = document
    }

    /// Loads and validates a UIScript XML document from a file URL.
    public init(contentsOf url: URL) throws {
        try self.init(data: Data(contentsOf: url))
    }

    init(
        version: Int,
        requiredFeatures: [String],
        window: Window,
        resources: Resources,
        styles: [String: Style],
        visuals: [Visual],
        controls: [Control],
        ignoredAttributes: [IgnoredAttribute]
    ) {
        self.version = version
        self.requiredFeatures = requiredFeatures
        self.window = window
        self.resources = resources
        self.styles = styles
        self.visuals = visuals
        self.controls = controls
        self.ignoredAttributes = ignoredAttributes
    }

    /// Returns the style a control refers to, or `nil` when it has none.
    public func style(for control: Control) -> Style? {
        control.style.flatMap { styles[$0] }
    }

    /// Returns the control with this name, or `nil` when there is none.
    public func control(named name: String) -> Control? {
        controls.first { $0.name == name }
    }

    /// Returns the visual with this name, or `nil` when there is none.
    public func visual(named name: String) -> Visual? {
        visuals.first { $0.name == name }
    }

    private func validate() throws {
        guard window.size.width > 0, window.size.height > 0 else {
            throw UIScriptError.invalidWindowSize
        }
        if let minimumSize = window.minSize,
           minimumSize.width <= 0 || minimumSize.height <= 0
            || minimumSize.width > window.size.width
            || minimumSize.height > window.size.height {
            throw UIScriptError.invalidMinimumWindowSize
        }
        for (name, style) in styles {
            if let fontSize = style.fontSize, fontSize <= 0 {
                throw UIScriptError.invalidFontSize(style: name)
            }
        }
        for (name, image) in resources.images {
            guard image.path != nil || image.assetID != nil else {
                throw UIScriptError.invalidImageResource(image: name)
            }
            guard image.stateCount == 1 || image.stateCount == 4 else {
                throw UIScriptError.invalidStateCount(image: name)
            }
        }
        try validateUniqueNames(visuals.map(\.name) + controls.map(\.name))

        for visual in visuals {
            try validateReference(
                visual.image,
                in: resources.images,
                owner: visual.name,
                property: "image"
            )
            try validate(frame: visual.frame, owner: visual.name)
        }

        for control in controls {
            if control.placeholder != nil, control.type != .textField {
                throw UIScriptError.invalidPlaceholder(owner: control.name)
            }
            if let maximumLength = control.maximumLength,
               maximumLength <= 0 || control.type != .textField {
                throw UIScriptError.invalidMaximumLength(owner: control.name)
            }
            if let binding = control.scrolls {
                try validate(binding, of: control)
            }
            if let style = control.style, styles[style] == nil {
                throw UIScriptError.unknownReference(
                    owner: control.name,
                    property: "style",
                    reference: style
                )
            }
            if let image = control.image {
                guard control.type == .button else {
                    throw UIScriptError.invalidImage(owner: control.name)
                }
                try validateReference(
                    image,
                    in: resources.images,
                    owner: control.name,
                    property: "image"
                )
            } else if control.frame.width == nil || control.frame.height == nil {
                throw UIScriptError.missingSize(owner: control.name)
            }
            if case let .string(stringName)? = control.text,
               resources.strings[stringName] == nil {
                throw UIScriptError.unknownReference(
                    owner: control.name,
                    property: "text",
                    reference: stringName
                )
            }
            if case let .string(stringName)? = control.placeholder,
               resources.strings[stringName] == nil {
                throw UIScriptError.unknownReference(
                    owner: control.name,
                    property: "placeholder",
                    reference: stringName
                )
            }
            if let tooltip = control.tooltip,
               resources.strings[tooltip] == nil {
                throw UIScriptError.unknownReference(
                    owner: control.name,
                    property: "tooltip",
                    reference: tooltip
                )
            }
            try validate(frame: control.frame, owner: control.name)
        }
    }

    private func validate(_ binding: ScrollBinding, of control: Control) throws {
        guard let target = self.control(named: binding.list) else {
            throw UIScriptError.unknownReference(
                owner: control.name,
                property: "scrolls",
                reference: binding.list
            )
        }
        let hasValidDirection = switch control.type {
        case .slider: binding.direction == nil
        case .button: binding.direction != nil
        default: false
        }
        guard target.type == .list, hasValidDirection else {
            throw UIScriptError.invalidScrollBinding(owner: control.name)
        }
    }

    private func validateUniqueNames(_ names: [String]) throws {
        var seenNames: Set<String> = []
        for name in names where !seenNames.insert(name).inserted {
            throw UIScriptError.duplicateName(name)
        }
    }

    private func validateReference<Value>(
        _ reference: String,
        in resources: [String: Value],
        owner: String,
        property: String
    ) throws {
        guard resources[reference] != nil else {
            throw UIScriptError.unknownReference(
                owner: owner,
                property: property,
                reference: reference
            )
        }
    }

    private func validate(frame: Frame, owner: String) throws {
        guard (frame.width ?? 0) >= 0, (frame.height ?? 0) >= 0 else {
            throw UIScriptError.invalidFrame(owner: owner)
        }
    }

    /// An attribute the reader did not recognize.
    public struct IgnoredAttribute: Sendable, Equatable {
        /// The name of the element holding the attribute.
        public let element: String

        /// The attribute's name.
        public let attribute: String

        /// The line of the element in the document.
        public let line: Int
    }

    /// Window-level size settings.
    public struct Window: Sendable {
        /// The initial window size in pixels.
        public let size: Size

        /// The smallest user-resizable window size, when specified.
        public let minSize: Size?
    }

    /// A width and height in pixels.
    public struct Size: Sendable {
        /// The width.
        public let width: Float

        /// The height.
        public let height: Float
    }

    /// The named resources used by a document.
    public struct Resources: Sendable {
        /// Image resources keyed by their document-local names.
        public let images: [String: ImageResource]

        /// Localized strings keyed by their document-local names.
        public let strings: [String: StringResource]
    }

    /// The state a button image shows.
    ///
    /// The raw value is the state's slice in a four-state image, counted from the left.
    public enum ButtonState: Int, Sendable {
        /// The button is idle.
        case normal = 0

        /// The pointer is holding the button down.
        case pressed = 1

        /// The pointer is over the button.
        case hovered = 2

        /// The button is disabled.
        case disabled = 3
    }

    /// A reference to an image asset resolved by the host game.
    ///
    /// A resource has a path, an asset ID, or both. The host decides which to use.
    public struct ImageResource: Sendable {
        /// A host-defined asset path.
        public let path: String?

        /// A host-defined asset identifier, kept exactly as the document writes it.
        public let assetID: String?

        /// How many equal-width slices the image holds, either one or four.
        ///
        /// A four-state image holds one slice per `ButtonState`. An image with one
        /// slice shows it in every state. The value defaults to one.
        public let stateCount: Int

        /// Returns the part of the image to draw for `state`.
        public func sourceRectangle(
            for state: ButtonState,
            textureWidth: Float,
            textureHeight: Float
        ) -> Rectangle {
            let sliceWidth = textureWidth / Float(stateCount)
            let slice = stateCount == 4 ? state.rawValue : 0
            return Rectangle(x: Float(slice) * sliceWidth, y: 0, width: sliceWidth, height: textureHeight)
        }
    }

    /// A localized string reference resolved by the host game.
    public struct StringResource: Sendable {
        /// The host-defined string table or localization domain.
        public let table: String

        /// The string's index within its table.
        public let index: Int
    }

    /// A named collection of visual properties.
    ///
    /// Documents write colors as `#RRGGBB` or `#RRGGBBAA`.
    public struct Style: Sendable {
        /// The primary text color.
        public let textColor: Color?

        /// The selected text color.
        public let selectedTextColor: Color?

        /// The highlighted text color.
        public let highlightedTextColor: Color?

        /// The disabled text color.
        public let disabledTextColor: Color?

        /// The background color.
        public let backgroundColor: Color?

        /// The border color.
        public let borderColor: Color?

        /// The font size in pixels. It must be positive.
        public let fontSize: Int?
    }

    /// A rectangle placed in the window's pixel coordinate space.
    ///
    /// A button or visual with an image may leave out its size to use the image's.
    /// `UIScriptView.bounds(named:at:)` reports the final bounds.
    public struct Frame: Sendable {
        /// The horizontal position.
        public let x: Float

        /// The vertical position.
        public let y: Float

        /// The width, or `nil` to use the image's.
        public let width: Float?

        /// The height, or `nil` to use the image's.
        public let height: Float?

        /// Optional offsets from the window edges used during resizing.
        public let edgeOffsets: EdgeOffsets?
    }

    /// Distances from a frame to the corresponding window edges.
    public struct EdgeOffsets: Sendable {
        /// The distance from the left edge.
        public let left: Float?

        /// The distance from the right edge.
        public let right: Float?

        /// The distance from the top edge.
        public let top: Float?

        /// The distance from the bottom edge.
        public let bottom: Float?
    }

    /// A decorative image positioned independently from a control.
    public struct Visual: Sendable {
        /// The stable document-local name.
        public let name: String

        /// The name of an image in `resources.images`.
        public let image: String

        /// The visual's position and optional size and resize offsets.
        public let frame: Frame
    }

    /// A supported control category.
    public enum ControlType: Sendable {
        /// Static text.
        case text

        /// Formatted or styled text content.
        case formattedText

        /// A clickable button.
        case button

        /// A single-line or multiline text input.
        case textField

        /// A selectable list.
        case list

        /// A range or scroll control.
        case slider

        /// A named area Hudini positions and the host draws into.
        case region
    }

    /// Text content expressed literally or by a localized-string reference.
    public enum Text: Sendable, Equatable {
        /// Literal text.
        case literal(String)

        /// The name of a string in `resources.strings`.
        case string(String)
    }

    /// The direction a scroll button moves through its list.
    public enum ScrollDirection: String, Sendable {
        /// Toward the top of the list, which holds the oldest content.
        case up

        /// Toward the bottom of the list, which holds the newest content.
        case down
    }

    /// Connects a slider or button to the list it scrolls.
    ///
    /// A slider shows the list's position and has no direction. A button
    /// requires a direction.
    public struct ScrollBinding: Sendable, Equatable {
        /// The name of the list control.
        public let list: String

        /// The direction a button scrolls.
        public let direction: ScrollDirection?
    }

    /// A control described by a UIScript document.
    public struct Control: Sendable {
        /// The stable document-local name.
        public let name: String

        /// The control category.
        public let type: ControlType

        /// An optional legacy identifier retained for `.uis` conversion or host use.
        public let legacyID: Int?

        /// The control's position and optional size and resize offsets.
        public let frame: Frame

        /// The name of a style in the document's styles.
        public let style: String?

        /// Literal or localized text displayed by the control.
        public let text: Text?

        /// Literal or localized guidance displayed while a text field is empty.
        public let placeholder: Text?

        /// The name of an image in `resources.images`.
        public let image: String?

        /// The name of a localized string in `resources.strings`.
        public let tooltip: String?

        /// The most characters a text field accepts.
        public let maximumLength: Int?

        /// The list a slider or button scrolls.
        public let scrolls: ScrollBinding?
    }
}

/// Errors raised while reading or validating a UIScript document.
public enum UIScriptError: Error, LocalizedError, Sendable, Equatable {
    /// The document is not UTF-8.
    case unsupportedEncoding

    /// The document declares a DOCTYPE, which UIScript does not allow.
    case doctypeNotAllowed

    /// The document is not well-formed XML.
    case malformed(line: Int, column: Int)

    /// The root element is not `UIScript`.
    case invalidRoot(String)

    /// The document's version is newer than this reader supports.
    case unsupportedVersion(Int)

    /// The document requires a feature this reader does not understand.
    case unsupportedFeature(String)

    /// An element is not part of the format.
    case unknownElement(String, line: Int)

    /// An element appears inside one that does not hold elements.
    case unexpectedNesting(String, line: Int)

    /// Text appears outside of an attribute.
    case unexpectedText(line: Int)

    /// A required element is absent.
    case missingElement(String)

    /// An element that may appear once appears again.
    case duplicateElement(String, line: Int)

    /// An element lacks a required attribute.
    case missingAttribute(element: String, attribute: String, line: Int)

    /// An attribute's value cannot be used.
    case invalidAttribute(element: String, attribute: String, value: String, line: Int)

    /// An element has two attributes that cannot be used together.
    case conflictingAttributes(element: String, first: String, second: String, line: Int)

    /// The initial window size has a nonpositive dimension.
    case invalidWindowSize

    /// The minimum window size has a nonpositive dimension or exceeds the window size.
    case invalidMinimumWindowSize

    /// A style has a nonpositive font size.
    case invalidFontSize(style: String)

    /// Two controls or visuals share a name, or two resources of a kind do.
    case duplicateName(String)

    /// An image resource has neither a path nor an asset ID.
    case invalidImageResource(image: String)

    /// An image resource has a state count other than one or four.
    case invalidStateCount(image: String)

    /// An image is attached to a control other than a button.
    case invalidImage(owner: String)

    /// A control without an image leaves out its width or height.
    case missingSize(owner: String)

    /// A visual or control has a negative frame size.
    case invalidFrame(owner: String)

    /// A name refers to a missing resource or style.
    case unknownReference(owner: String, property: String, reference: String)

    /// A placeholder is attached to a control other than a text field.
    case invalidPlaceholder(owner: String)

    /// A maximum length is not positive or is attached to a control other than a text field.
    case invalidMaximumLength(owner: String)

    /// A scroll binding targets a control other than a list, or does not suit its control.
    case invalidScrollBinding(owner: String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedEncoding:
            "UIScript documents must be UTF-8."
        case .doctypeNotAllowed:
            "UIScript documents must not declare a DOCTYPE."
        case let .malformed(line, column):
            "UIScript document is not well-formed XML near line \(line), column \(column)."
        case let .invalidRoot(name):
            "UIScript root element must be 'UIScript', not '\(name)'."
        case let .unsupportedVersion(version):
            "UIScript version \(version) is newer than this reader supports (\(UIScript.supportedVersion)). Update Hudini to load this document."
        case let .unsupportedFeature(feature):
            "UIScript document requires feature '\(feature)', which this reader does not support. Update Hudini to load this document."
        case let .unknownElement(name, line):
            "UIScript line \(line): element '\(name)' is not supported."
        case let .unexpectedNesting(name, line):
            "UIScript line \(line): element '\(name)' must be a direct child of 'UIScript'."
        case let .unexpectedText(line):
            "UIScript line \(line): text must be written in an attribute."
        case let .missingElement(name):
            "UIScript document needs a '\(name)' element."
        case let .duplicateElement(name, line):
            "UIScript line \(line): only one '\(name)' element is allowed."
        case let .missingAttribute(element, attribute, line):
            "UIScript line \(line): '\(element)' needs a '\(attribute)' attribute."
        case let .invalidAttribute(element, attribute, value, line):
            "UIScript line \(line): '\(element)' cannot use '\(value)' for '\(attribute)'."
        case let .conflictingAttributes(element, first, second, line):
            "UIScript line \(line): '\(element)' cannot have both '\(first)' and '\(second)'."
        case .invalidWindowSize:
            "UIScript window size must be positive."
        case .invalidMinimumWindowSize:
            "UIScript minimum window size must be positive and no larger than the window size."
        case let .invalidFontSize(style):
            "UIScript font size for style '\(style)' must be positive."
        case let .duplicateName(name):
            "UIScript name '\(name)' is used more than once."
        case let .invalidImageResource(image):
            "UIScript image '\(image)' needs a 'path' or an 'assetID'."
        case let .invalidStateCount(image):
            "UIScript state count for image '\(image)' must be 1 or 4."
        case let .invalidImage(owner):
            "UIScript image for '\(owner)' requires a button control."
        case let .missingSize(owner):
            "UIScript control '\(owner)' needs a width and height, because it has no image to take them from."
        case let .invalidFrame(owner):
            "UIScript frame for '\(owner)' cannot have a negative size."
        case let .unknownReference(owner, property, reference):
            "UIScript \(property) for '\(owner)' refers to unknown '\(reference)'."
        case let .invalidPlaceholder(owner):
            "UIScript placeholder for '\(owner)' requires a text field control."
        case let .invalidMaximumLength(owner):
            "UIScript maximum length for '\(owner)' must be positive and requires a text field control."
        case let .invalidScrollBinding(owner):
            "UIScript scrolls for '\(owner)' must target a list, from a slider without a direction or a button with one."
        }
    }
}
