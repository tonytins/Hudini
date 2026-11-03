import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif
import Raylib

/// Reads the XML form of a UIScript document into the model, without validating references.
enum UIScriptParser {
    static func parse(_ data: Data) throws -> UIScript {
        // Encodings such as UTF-16 hold zero bytes and could hide a DOCTYPE from the check below.
        guard !data.contains(0), String(data: data, encoding: .utf8) != nil else {
            throw UIScriptError.unsupportedEncoding
        }
        // XMLParser expands internal entities without telling its delegate, so a
        // document must not be able to declare any.
        guard data.range(of: Data("<!DOCTYPE".utf8)) == nil else {
            throw UIScriptError.doctypeNotAllowed
        }

        let collector = ElementCollector()
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = collector
        let succeeded = parser.parse()
        if let failure = collector.failure {
            throw failure
        }
        guard succeeded, let root = collector.root else {
            throw UIScriptError.malformed(line: parser.lineNumber, column: parser.columnNumber)
        }
        return try buildScript(root: root, elements: collector.elements)
    }

    private static func buildScript(root: Element, elements: [Element]) throws -> UIScript {
        let rootReader = AttributeReader(root)
        let version = try rootReader.integer("version") ?? 1
        let requiredFeatures = rootReader.string("requires")?
            .split(whereSeparator: \.isWhitespace)
            .map(String.init) ?? []

        var window: UIScript.Window?
        var images: [String: UIScript.ImageResource] = [:]
        var strings: [String: UIScript.StringResource] = [:]
        var styles: [String: UIScript.Style] = [:]
        var visuals: [UIScript.Visual] = []
        var controls: [UIScript.Control] = []
        var ignoredAttributes = rootReader.unusedAttributes()

        for element in elements {
            let reader = AttributeReader(element)
            switch element.name {
            case "Window":
                guard window == nil else {
                    throw UIScriptError.duplicateElement("Window", line: element.line)
                }
                window = try makeWindow(reader)
            case "Image":
                let name = try reader.requiredString("name")
                guard images[name] == nil else {
                    throw UIScriptError.duplicateName(name)
                }
                images[name] = UIScript.ImageResource(
                    path: reader.string("path"),
                    assetID: reader.string("assetID"),
                    stateCount: try reader.integer("stateCount") ?? 1
                )
            case "String":
                let name = try reader.requiredString("name")
                guard strings[name] == nil else {
                    throw UIScriptError.duplicateName(name)
                }
                strings[name] = UIScript.StringResource(
                    table: try reader.requiredString("table"),
                    index: try reader.requiredInteger("index")
                )
            case "Style":
                let name = try reader.requiredString("name")
                guard styles[name] == nil else {
                    throw UIScriptError.duplicateName(name)
                }
                styles[name] = try makeStyle(reader)
            case "Visual":
                visuals.append(UIScript.Visual(
                    name: try reader.requiredString("name"),
                    image: try reader.requiredString("image"),
                    frame: try makeFrame(reader)
                ))
            default:
                guard let type = controlTypes[element.name] else {
                    throw UIScriptError.unknownElement(element.name, line: element.line)
                }
                controls.append(try makeControl(type: type, reader))
            }
            ignoredAttributes += reader.unusedAttributes()
        }

        guard let window else {
            throw UIScriptError.missingElement("Window")
        }
        return UIScript(
            version: version,
            requiredFeatures: requiredFeatures,
            window: window,
            resources: UIScript.Resources(images: images, strings: strings),
            styles: styles,
            visuals: visuals,
            controls: controls,
            ignoredAttributes: ignoredAttributes
        )
    }

    private static let controlTypes: [String: UIScript.ControlType] = [
        "Text": .text,
        "FormattedText": .formattedText,
        "Button": .button,
        "TextField": .textField,
        "List": .list,
        "Slider": .slider,
        "Region": .region
    ]

    private static func makeWindow(_ reader: AttributeReader) throws -> UIScript.Window {
        let size = UIScript.Size(
            width: try reader.requiredNumber("width"),
            height: try reader.requiredNumber("height")
        )
        let minWidth = try reader.number("minWidth")
        let minHeight = try reader.number("minHeight")
        switch (minWidth, minHeight) {
        case (nil, nil):
            return UIScript.Window(size: size, minSize: nil)
        case let (width?, height?):
            return UIScript.Window(size: size, minSize: UIScript.Size(width: width, height: height))
        case (nil, _):
            throw reader.missing("minWidth")
        case (_, nil):
            throw reader.missing("minHeight")
        }
    }

    private static func makeStyle(_ reader: AttributeReader) throws -> UIScript.Style {
        UIScript.Style(
            textColor: try reader.color("textColor"),
            selectedTextColor: try reader.color("selectedTextColor"),
            highlightedTextColor: try reader.color("highlightedTextColor"),
            disabledTextColor: try reader.color("disabledTextColor"),
            backgroundColor: try reader.color("backgroundColor"),
            borderColor: try reader.color("borderColor"),
            fontSize: try reader.integer("fontSize")
        )
    }

    private static func makeFrame(_ reader: AttributeReader) throws -> UIScript.Frame {
        let left = try reader.number("edgeOffsetLeft")
        let right = try reader.number("edgeOffsetRight")
        let top = try reader.number("edgeOffsetTop")
        let bottom = try reader.number("edgeOffsetBottom")
        let hasEdgeOffsets = left != nil || right != nil || top != nil || bottom != nil
        return UIScript.Frame(
            x: try reader.requiredNumber("x"),
            y: try reader.requiredNumber("y"),
            width: try reader.number("width"),
            height: try reader.number("height"),
            edgeOffsets: hasEdgeOffsets
                ? UIScript.EdgeOffsets(left: left, right: right, top: top, bottom: bottom)
                : nil
        )
    }

    private static func makeControl(
        type: UIScript.ControlType,
        _ reader: AttributeReader
    ) throws -> UIScript.Control {
        let name = try reader.requiredString("name")
        return UIScript.Control(
            name: name,
            type: type,
            legacyID: try reader.integer("legacyID"),
            frame: try makeFrame(reader),
            style: reader.string("style"),
            text: try reader.text(literal: "text", reference: "string"),
            placeholder: try reader.text(literal: "placeholder", reference: "placeholderString"),
            image: reader.string("image"),
            tooltip: reader.string("tooltip"),
            maximumLength: try reader.integer("maximumLength"),
            scrolls: try makeScrollBinding(owner: name, reader),
            isReadOnly: try reader.boolean("readOnly") ?? false
        )
    }

    private static func makeScrollBinding(
        owner: String,
        _ reader: AttributeReader
    ) throws -> UIScript.ScrollBinding? {
        let direction = try reader.scrollDirection("direction")
        guard let list = reader.string("scrolls") else {
            guard direction == nil else {
                throw UIScriptError.invalidScrollBinding(owner: owner)
            }
            return nil
        }
        return UIScript.ScrollBinding(list: list, direction: direction)
    }
}

private struct Element {
    let name: String
    let attributes: [String: String]
    let line: Int
}

/// Gathers the document's elements, which all sit directly under the root.
private final class ElementCollector: NSObject, XMLParserDelegate {
    private(set) var root: Element?
    private(set) var elements: [Element] = []
    private(set) var failure: UIScriptError?
    private var depth = 0

    private func fail(_ error: UIScriptError, _ parser: XMLParser) {
        failure = error
        parser.abortParsing()
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String] = [:]
    ) {
        let element = Element(name: elementName, attributes: attributes, line: parser.lineNumber)
        switch depth {
        case 0:
            guard elementName == "UIScript" else {
                return fail(.invalidRoot(elementName), parser)
            }
            root = element
            // A newer document may use elements this reader rejects, so report its
            // version or features first. Those errors say what to do about it.
            if let problem = compatibilityProblem(with: attributes) {
                return fail(problem, parser)
            }
        case 1:
            elements.append(element)
        default:
            return fail(.unexpectedNesting(elementName, line: parser.lineNumber), parser)
        }
        depth += 1
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?
    ) {
        depth -= 1
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if string.contains(where: { !$0.isWhitespace }) {
            fail(.unexpectedText(line: parser.lineNumber), parser)
        }
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        fail(.unexpectedText(line: parser.lineNumber), parser)
    }

    private func compatibilityProblem(with attributes: [String: String]) -> UIScriptError? {
        if let value = attributes["version"] {
            guard let version = Int(value), version >= 1 else {
                return .invalidAttribute(element: "UIScript", attribute: "version", value: value, line: 1)
            }
            if version > UIScript.supportedVersion {
                return .unsupportedVersion(version)
            }
        }
        let features = attributes["requires"]?.split(whereSeparator: \.isWhitespace) ?? []
        return features
            .first { !UIScript.supportedFeatures.contains(String($0)) }
            .map { .unsupportedFeature(String($0)) }
    }
}

/// Converts an element's attributes to typed values and tracks which ones were used.
private final class AttributeReader {
    private let element: Element
    private var usedAttributes: Set<String> = []

    init(_ element: Element) {
        self.element = element
    }

    func string(_ attribute: String) -> String? {
        usedAttributes.insert(attribute)
        return element.attributes[attribute]
    }

    func missing(_ attribute: String) -> UIScriptError {
        .missingAttribute(element: element.name, attribute: attribute, line: element.line)
    }

    func requiredString(_ attribute: String) throws -> String {
        guard let value = string(attribute) else {
            throw missing(attribute)
        }
        return value
    }

    private func invalid(_ attribute: String, _ value: String) -> UIScriptError {
        .invalidAttribute(element: element.name, attribute: attribute, value: value, line: element.line)
    }

    func integer(_ attribute: String) throws -> Int? {
        guard let value = string(attribute) else {
            return nil
        }
        guard let integer = Int(value) else {
            throw invalid(attribute, value)
        }
        return integer
    }

    func requiredInteger(_ attribute: String) throws -> Int {
        guard let integer = try integer(attribute) else {
            throw missing(attribute)
        }
        return integer
    }

    func number(_ attribute: String) throws -> Float? {
        guard let value = string(attribute) else {
            return nil
        }
        guard let number = Float(value), number.isFinite else {
            throw invalid(attribute, value)
        }
        return number
    }

    func requiredNumber(_ attribute: String) throws -> Float {
        guard let number = try number(attribute) else {
            throw missing(attribute)
        }
        return number
    }

    func boolean(_ attribute: String) throws -> Bool? {
        switch string(attribute) {
        case nil:
            nil
        case "true":
            true
        case "false":
            false
        case let value?:
            throw invalid(attribute, value)
        }
    }

    func color(_ attribute: String) throws -> Color? {
        guard let value = string(attribute) else {
            return nil
        }
        guard let color = Self.color(fromHex: value) else {
            throw invalid(attribute, value)
        }
        return color
    }

    func scrollDirection(_ attribute: String) throws -> UIScript.ScrollDirection? {
        guard let value = string(attribute) else {
            return nil
        }
        guard let direction = UIScript.ScrollDirection(rawValue: value) else {
            throw invalid(attribute, value)
        }
        return direction
    }

    func text(literal: String, reference: String) throws -> UIScript.Text? {
        switch (string(literal), string(reference)) {
        case (nil, nil):
            return nil
        case let (value?, nil):
            return .literal(value)
        case let (nil, name?):
            return .string(name)
        case (_?, _?):
            throw UIScriptError.conflictingAttributes(
                element: element.name,
                first: literal,
                second: reference,
                line: element.line
            )
        }
    }

    func unusedAttributes() -> [UIScript.IgnoredAttribute] {
        element.attributes.keys
            .filter { !usedAttributes.contains($0) }
            .sorted()
            .map { UIScript.IgnoredAttribute(element: element.name, attribute: $0, line: element.line) }
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
