import Foundation
import Raylib

/// A decoded Hudini interface document.
///
/// UIScript documents describe presentation. The host game remains responsible
/// for control state, actions, and resolving image and localized-string data.
public struct UIScript: Decodable, Sendable {
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

    /// Decodes and validates a UIScript JSON document.
    public init(data: Data) throws {
        let document = try JSONDecoder().decode(Self.self, from: data)
        try document.validate()
        self = document
    }

    /// Loads and validates a UIScript JSON document from a file URL.
    public init(contentsOf url: URL) throws {
        try self.init(data: Data(contentsOf: url))
    }

    /// Returns the style a control refers to, or `nil` when it has none.
    public func style(for control: Control) -> Style? {
        control.style.flatMap { styles[$0] }
    }

    /// Returns the control with this name, or `nil` when there is none.
    public func control(named name: String) -> Control? {
        controls.first { $0.name == name }
    }

    private enum CodingKeys: String, CodingKey {
        case window
        case resources
        case styles
        case visuals
        case controls
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try validateKnownKeys(in: decoder, allowing: [
            "window", "resources", "styles", "visuals", "controls"
        ])
        window = try container.decode(Window.self, forKey: .window)
        resources = try container.decodeIfPresent(Resources.self, forKey: .resources) ?? Resources()
        styles = try container.decodeIfPresent([String: Style].self, forKey: .styles) ?? [:]
        visuals = try container.decodeIfPresent([Visual].self, forKey: .visuals) ?? []
        controls = try container.decodeIfPresent([Control].self, forKey: .controls) ?? []
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
        try validateUniqueNames(visuals.map(\.name))
        try validateUniqueNames(controls.map(\.name))

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
                try validateReference(
                    image,
                    in: resources.images,
                    owner: control.name,
                    property: "image"
                )
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
        guard frame.width >= 0, frame.height >= 0 else {
            throw UIScriptError.invalidFrame(owner: owner)
        }
    }

    /// Window-level size settings.
    public struct Window: Decodable, Sendable {
        /// The initial window size in pixels.
        public let size: Size

        /// The smallest user-resizable window size, when specified.
        public let minSize: Size?

        private enum CodingKeys: String, CodingKey {
            case size
            case minSize
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            try validateKnownKeys(in: decoder, allowing: ["size", "minSize"])
            size = try container.decode(Size.self, forKey: .size)
            minSize = try container.decodeIfPresent(Size.self, forKey: .minSize)
        }
    }

    /// A width and height in pixels.
    public struct Size: Decodable, Sendable {
        /// The width.
        public let width: Float

        /// The height.
        public let height: Float

        private enum CodingKeys: String, CodingKey {
            case width
            case height
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            try validateKnownKeys(in: decoder, allowing: ["width", "height"])
            width = try container.decode(Float.self, forKey: .width)
            height = try container.decode(Float.self, forKey: .height)
        }
    }

    /// The named resources used by a document.
    public struct Resources: Decodable, Sendable {
        /// Image resources keyed by their document-local names.
        public let images: [String: ImageResource]

        /// Localized strings keyed by their document-local names.
        public let strings: [String: StringResource]

        /// Creates an empty resource collection.
        public init() {
            images = [:]
            strings = [:]
        }

        private enum CodingKeys: String, CodingKey {
            case images
            case strings
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            try validateKnownKeys(in: decoder, allowing: ["images", "strings"])
            images = try container.decodeIfPresent([String: ImageResource].self, forKey: .images) ?? [:]
            strings = try container.decodeIfPresent([String: StringResource].self, forKey: .strings) ?? [:]
        }
    }

    /// A reference to an image asset resolved by the host game.
    public struct ImageResource: Decodable, Sendable {
        /// A host-defined asset path or identifier.
        public let path: String

        private enum CodingKeys: String, CodingKey {
            case path
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            try validateKnownKeys(in: decoder, allowing: ["path"])
            path = try container.decode(String.self, forKey: .path)
        }
    }

    /// A localized string reference resolved by the host game.
    public struct StringResource: Decodable, Sendable {
        /// The host-defined string table or localization domain.
        public let table: String

        /// The string's index within its table.
        public let index: Int

        private enum CodingKeys: String, CodingKey {
            case table
            case index
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            try validateKnownKeys(in: decoder, allowing: ["table", "index"])
            table = try container.decode(String.self, forKey: .table)
            index = try container.decode(Int.self, forKey: .index)
        }
    }

    /// A named collection of visual properties.
    ///
    /// Documents write colors as `#RRGGBB` or `#RRGGBBAA`. Any other form fails
    /// decoding.
    public struct Style: Decodable, Sendable {
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

        private enum CodingKeys: String, CodingKey {
            case textColor
            case selectedTextColor
            case highlightedTextColor
            case disabledTextColor
            case backgroundColor
            case borderColor
            case fontSize
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            try validateKnownKeys(in: decoder, allowing: [
                "textColor", "selectedTextColor", "highlightedTextColor",
                "disabledTextColor", "backgroundColor", "borderColor", "fontSize"
            ])
            textColor = try Self.decodeColor(in: container, forKey: .textColor)
            selectedTextColor = try Self.decodeColor(in: container, forKey: .selectedTextColor)
            highlightedTextColor = try Self.decodeColor(in: container, forKey: .highlightedTextColor)
            disabledTextColor = try Self.decodeColor(in: container, forKey: .disabledTextColor)
            backgroundColor = try Self.decodeColor(in: container, forKey: .backgroundColor)
            borderColor = try Self.decodeColor(in: container, forKey: .borderColor)
            fontSize = try container.decodeIfPresent(Int.self, forKey: .fontSize)
        }

        private static func decodeColor(
            in container: KeyedDecodingContainer<CodingKeys>,
            forKey key: CodingKeys
        ) throws -> Color? {
            guard let hex = try container.decodeIfPresent(String.self, forKey: key) else {
                return nil
            }
            guard let color = color(fromHex: hex) else {
                throw DecodingError.dataCorruptedError(
                    forKey: key,
                    in: container,
                    debugDescription: "Color '\(hex)' must be #RRGGBB or #RRGGBBAA."
                )
            }
            return color
        }

        private static func color(fromHex hex: String) -> Color? {
            guard hex.hasPrefix("#") else {
                return nil
            }
            let digits = hex.dropFirst()
            guard digits.count == 6 || digits.count == 8,
                  digits.allSatisfy({ $0.isASCII && $0.isHexDigit }),
                  let value = UInt32(digits, radix: 16) else {
                return nil
            }
            let rgba = digits.count == 6 ? (value << 8) | 0xFF : value
            return Color(
                r: UInt8(truncatingIfNeeded: rgba >> 24),
                g: UInt8(truncatingIfNeeded: rgba >> 16),
                b: UInt8(truncatingIfNeeded: rgba >> 8),
                a: UInt8(truncatingIfNeeded: rgba)
            )
        }
    }

    /// A rectangle placed in the window's pixel coordinate space.
    public struct Frame: Decodable, Sendable {
        /// The horizontal position.
        public let x: Float

        /// The vertical position.
        public let y: Float

        /// The width.
        public let width: Float

        /// The height.
        public let height: Float

        /// Optional offsets from the window edges used during resizing.
        public let edgeOffsets: EdgeOffsets?

        /// Returns this frame as screen bounds for a window whose corner is at `origin`.
        public func rectangle(at origin: Vector2) -> Rectangle {
            Rectangle(x: origin.x + x, y: origin.y + y, width: width, height: height)
        }

        private enum CodingKeys: String, CodingKey {
            case x
            case y
            case width
            case height
            case edgeOffsets
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            try validateKnownKeys(in: decoder, allowing: [
                "x", "y", "width", "height", "edgeOffsets"
            ])
            x = try container.decode(Float.self, forKey: .x)
            y = try container.decode(Float.self, forKey: .y)
            width = try container.decode(Float.self, forKey: .width)
            height = try container.decode(Float.self, forKey: .height)
            edgeOffsets = try container.decodeIfPresent(EdgeOffsets.self, forKey: .edgeOffsets)
        }
    }

    /// Distances from a frame to the corresponding window edges.
    public struct EdgeOffsets: Decodable, Sendable {
        /// The distance from the left edge.
        public let left: Float?

        /// The distance from the right edge.
        public let right: Float?

        /// The distance from the top edge.
        public let top: Float?

        /// The distance from the bottom edge.
        public let bottom: Float?

        private enum CodingKeys: String, CodingKey {
            case left
            case right
            case top
            case bottom
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            try validateKnownKeys(in: decoder, allowing: ["left", "right", "top", "bottom"])
            left = try container.decodeIfPresent(Float.self, forKey: .left)
            right = try container.decodeIfPresent(Float.self, forKey: .right)
            top = try container.decodeIfPresent(Float.self, forKey: .top)
            bottom = try container.decodeIfPresent(Float.self, forKey: .bottom)
        }
    }

    /// A decorative image positioned independently from a control.
    public struct Visual: Decodable, Sendable {
        /// The stable document-local name.
        public let name: String

        /// The name of an image in `resources.images`.
        public let image: String

        /// The visual's pixel bounds and optional resize offsets.
        public let frame: Frame

        private enum CodingKeys: String, CodingKey {
            case name
            case image
            case frame
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            try validateKnownKeys(in: decoder, allowing: ["name", "image", "frame"])
            name = try container.decode(String.self, forKey: .name)
            image = try container.decode(String.self, forKey: .image)
            frame = try container.decode(Frame.self, forKey: .frame)
        }
    }

    /// A supported control category in the initial UIScript scaffold.
    public enum ControlType: String, Decodable, Sendable {
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
    }

    /// Text content expressed literally or by a localized-string reference.
    public enum Text: Decodable, Sendable, Equatable {
        /// Literal text.
        case literal(String)

        /// The name of a string in `resources.strings`.
        case string(String)

        private enum CodingKeys: String, CodingKey {
            case literal
            case string
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            try validateKnownKeys(in: decoder, allowing: ["literal", "string"])
            let literal = try container.decodeIfPresent(String.self, forKey: .literal)
            let string = try container.decodeIfPresent(String.self, forKey: .string)
            switch (literal, string) {
            case let (.some(value), .none):
                self = .literal(value)
            case let (.none, .some(value)):
                self = .string(value)
            default:
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Text must contain exactly one of 'literal' or 'string'."
                    )
                )
            }
        }
    }

    /// The direction a scroll button moves through its list.
    public enum ScrollDirection: String, Decodable, Sendable {
        /// Toward the top of the list, which holds the oldest content.
        case up

        /// Toward the bottom of the list, which holds the newest content.
        case down
    }

    /// Connects a slider or button to the list it scrolls.
    ///
    /// A slider shows the list's position and has no direction. A button
    /// requires a direction.
    public struct ScrollBinding: Decodable, Sendable, Equatable {
        /// The name of the list control.
        public let list: String

        /// The direction a button scrolls.
        public let direction: ScrollDirection?

        private enum CodingKeys: String, CodingKey {
            case list
            case direction
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            try validateKnownKeys(in: decoder, allowing: ["list", "direction"])
            list = try container.decode(String.self, forKey: .list)
            direction = try container.decodeIfPresent(ScrollDirection.self, forKey: .direction)
        }
    }

    /// A control described by a UIScript document.
    public struct Control: Decodable, Sendable {
        /// The stable document-local name.
        public let name: String

        /// The control category.
        public let type: ControlType

        /// An optional legacy identifier retained for adapter or host use.
        public let legacyID: Int?

        /// The control's pixel bounds and optional resize offsets.
        public let frame: Frame

        /// The name of a style in the document's `styles` section.
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

        private enum CodingKeys: String, CodingKey {
            case name
            case type
            case legacyID
            case frame
            case style
            case text
            case placeholder
            case image
            case tooltip
            case maximumLength
            case scrolls
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            try validateKnownKeys(in: decoder, allowing: [
                "name", "type", "legacyID", "frame", "style", "text",
                "placeholder", "image", "tooltip", "maximumLength", "scrolls"
            ])
            name = try container.decode(String.self, forKey: .name)
            type = try container.decode(ControlType.self, forKey: .type)
            legacyID = try container.decodeIfPresent(Int.self, forKey: .legacyID)
            frame = try container.decode(Frame.self, forKey: .frame)
            style = try container.decodeIfPresent(String.self, forKey: .style)
            text = try container.decodeIfPresent(Text.self, forKey: .text)
            placeholder = try container.decodeIfPresent(Text.self, forKey: .placeholder)
            image = try container.decodeIfPresent(String.self, forKey: .image)
            tooltip = try container.decodeIfPresent(String.self, forKey: .tooltip)
            maximumLength = try container.decodeIfPresent(Int.self, forKey: .maximumLength)
            scrolls = try container.decodeIfPresent(ScrollBinding.self, forKey: .scrolls)
        }
    }
}

private func validateKnownKeys(
    in decoder: Decoder,
    allowing knownKeys: [String]
) throws {
    let knownKeys = Set(knownKeys)
    let container = try decoder.container(keyedBy: AnyCodingKey.self)
    guard let unknownKey = container.allKeys.first(where: { !knownKeys.contains($0.stringValue) }) else {
        return
    }
    throw DecodingError.dataCorruptedError(
        forKey: unknownKey,
        in: container,
        debugDescription: "Unknown field '\(unknownKey.stringValue)' is not supported."
    )
}

private struct AnyCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}

/// Errors raised while validating a UIScript document.
public enum UIScriptError: Error, LocalizedError, Sendable, Equatable {
    /// The initial window size has a nonpositive dimension.
    case invalidWindowSize

    /// The minimum window size has a nonpositive dimension or exceeds the window size.
    case invalidMinimumWindowSize

    /// A style has a nonpositive font size.
    case invalidFontSize(style: String)

    /// Two controls or two visuals share a name.
    case duplicateName(String)

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
        case .invalidWindowSize:
            "UIScript window size must be positive."
        case .invalidMinimumWindowSize:
            "UIScript minimum window size must be positive and no larger than the window size."
        case let .invalidFontSize(style):
            "UIScript font size for style '\(style)' must be positive."
        case let .duplicateName(name):
            "UIScript name '\(name)' is used more than once."
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
