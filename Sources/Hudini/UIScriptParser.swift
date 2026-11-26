import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif
import Raylib

/// Reads the XML form of a UIScript document, or of an appearance, into the model, without
/// validating references.
enum UIScriptParser {
    static func parse(_ data: Data) throws -> UIScript {
        let (root, elements) = try collect(data, kind: .uiScript)
        return try buildScript(root: root, elements: elements)
    }

    static func parseAppearance(_ data: Data) throws -> Appearance {
        let (root, elements) = try collect(data, kind: .appearance)
        return try buildAppearance(root: root, elements: elements)
    }

    // Checks what the XML parser can't, parses, and returns the root and the elements under it.
    private static func collect(_ data: Data, kind: DocumentKind) throws -> (root: Element, elements: [Element]) {
        // Encodings such as UTF-16 hold zero bytes and could hide a DOCTYPE from the check below.
        guard !data.contains(0), String(data: data, encoding: .utf8) != nil else {
            throw UIScriptError.unsupportedEncoding
        }
        // XMLParser expands internal entities without telling its delegate, so a
        // document must not be able to declare any.
        guard data.range(of: Data("<!DOCTYPE".utf8)) == nil else {
            throw UIScriptError.doctypeNotAllowed
        }

        let collector = ElementCollector(kind: kind)
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
        return (root, collector.elements)
    }

    private static func buildAppearance(root: Element, elements: [Element]) throws -> Appearance {
        let rootReader = AttributeReader(root)
        let version = try rootReader.integer("version") ?? 1
        var images: [String: UIScript.ImageResource] = [:]
        var styles: [String: UIScript.Style] = [:]
        var scrollBar: Appearance.ScrollBar?
        var fonts: [String: UIScript.FontResource] = [:]
        var themeFonts: Appearance.ThemeFonts?
        var ignoredAttributes = rootReader.unusedAttributes()

        for element in elements {
            let reader = AttributeReader(element)
            switch element.name {
            case "Image":
                let name = try reader.requiredString("name")
                guard images[name] == nil else {
                    throw UIScriptError.duplicateName(name)
                }
                images[name] = try makeImage(reader)
            case "Style":
                let name = try reader.requiredString("name")
                guard styles[name] == nil else {
                    throw UIScriptError.duplicateName(name)
                }
                styles[name] = try makeStyle(reader, allowsNamedFont: true)
            case "Font":
                let name = try reader.requiredString("name")
                guard !Appearance.reservedFontNames.contains(name) else {
                    throw reader.invalid("name", name)
                }
                guard fonts[name] == nil else {
                    throw UIScriptError.duplicateName(name)
                }
                fonts[name] = try makeFont(reader)
            case "Fonts":
                guard themeFonts == nil else {
                    throw UIScriptError.duplicateElement("Fonts", line: element.line)
                }
                themeFonts = Appearance.ThemeFonts(default: reader.string("default"), monospace: reader.string("monospace"))
            case "ScrollBar":
                guard scrollBar == nil else {
                    throw UIScriptError.duplicateElement("ScrollBar", line: element.line)
                }
                scrollBar = try makeScrollBar(reader)
            default:
                throw UIScriptError.unexpectedAppearanceElement(element.name, line: element.line)
            }
            ignoredAttributes += reader.unusedAttributes()
        }
        return Appearance(
            version: version,
            images: images,
            styles: styles,
            scrollBar: scrollBar,
            fonts: fonts,
            themeFonts: themeFonts,
            ignoredAttributes: ignoredAttributes
        )
    }

    private static func makeFont(_ reader: AttributeReader) throws -> UIScript.FontResource {
        let path = try reader.requiredString("path")
        guard let size = try reader.integer("size") else {
            throw reader.missing("size")
        }
        guard size > 0 else {
            throw reader.invalid("size", String(size))
        }
        return UIScript.FontResource(path: path, size: size)
    }

    private static func makeScrollBar(_ reader: AttributeReader) throws -> Appearance.ScrollBar {
        let width = try reader.number("width") ?? Appearance.defaultScrollBarWidth
        guard width > 0 else {
            throw reader.invalid("width", reader.string("width") ?? "")
        }
        let thumbCap = try reader.number("thumbCap") ?? 0
        guard thumbCap >= 0 else {
            throw reader.invalid("thumbCap", reader.string("thumbCap") ?? "")
        }
        return Appearance.ScrollBar(
            width: width,
            up: reader.string("up"),
            down: reader.string("down"),
            thumb: reader.string("thumb"),
            thumbCap: thumbCap,
            track: reader.string("track")
        )
    }

    private static func makeImage(_ reader: AttributeReader) throws -> UIScript.ImageResource {
        UIScript.ImageResource(
            path: reader.string("path"),
            assetID: reader.string("assetID"),
            stateCount: try reader.integer("stateCount") ?? 1
        )
    }

    private static func buildScript(root: Element, elements: [Element]) throws -> UIScript {
        let rootReader = AttributeReader(root)
        let version = try rootReader.integer("version") ?? 1
        let requiredFeatures = rootReader.string("requires")?
            .split(whereSeparator: \.isWhitespace)
            .map(String.init) ?? []

        var window: UIScript.Window?
        // The element that gave the window or panel, so a second of either reports both names.
        var windowElement: Element?
        var panelEdge: UIScript.PanelEdge?
        // The first title bar, tab, sidebar, or pane element, which a panel refuses wherever it
        // appears.
        var firstWindowOnlyElement: Element?
        var images: [String: UIScript.ImageResource] = [:]
        var strings: [String: UIScript.StringResource] = [:]
        var styles: [String: UIScript.Style] = [:]
        var visuals: [UIScript.Visual] = []
        var controls: [UIScript.Control] = []
        var toolbarItems: [UIScript.ToolbarItem] = []
        var titleField: UIScript.TitleField?
        var tabs: [UIScript.Tab] = []
        var sidebarElement: Element?
        var sidebarName = ""
        var sidebarWidth: Float = 0
        // Panes in document order, with the element each came from and whether it holds anything.
        var panes: [(pane: UIScript.Pane, element: Element)] = []
        // The controls that name a pane with `pane`, in document order.
        var flatPaneControls: [(control: String, pane: String)] = []
        var ignoredAttributes = rootReader.unusedAttributes()

        // Reads a visual or control, directly under the root or inside `container`, a tab or pane,
        // and returns its name.
        func readContent(_ element: Element, in container: Element?) throws -> String {
            let reader = AttributeReader(element)
            defer { ignoredAttributes += reader.unusedAttributes() }
            if element.name == "Visual" {
                let visual = UIScript.Visual(
                    name: try reader.requiredString("name"),
                    image: try reader.requiredString("image"),
                    frame: try makeFrame(reader),
                    isInitiallyHidden: false
                )
                visuals.append(visual)
                return visual.name
            }
            guard let type = controlTypes[element.name] else {
                guard let container else {
                    throw UIScriptError.unknownElement(element.name, line: element.line)
                }
                throw UIScriptError.invalidChild(element.name, parent: container.name, line: element.line)
            }
            let control = try makeControl(type: type, reader)
            if reader.string("tab") != nil {
                throw UIScriptError.tabAttributeOnControl(owner: control.name, line: element.line)
            }
            if let pane = reader.string("pane") {
                guard container == nil else {
                    throw UIScriptError.containedControlNamesPane(owner: control.name, line: element.line)
                }
                flatPaneControls.append((control.name, pane))
            }
            controls.append(control)
            return control.name
        }

        for element in elements {
            let reader = AttributeReader(element)
            switch element.name {
            case "Window", "Panel":
                if let windowElement {
                    guard windowElement.name == element.name else {
                        throw UIScriptError.conflictingElements(
                            first: windowElement.name, second: element.name, line: element.line
                        )
                    }
                    throw UIScriptError.duplicateElement(element.name, line: element.line)
                }
                windowElement = element
                if element.name == "Panel" {
                    window = try makePanelWindow(reader)
                    panelEdge = try makePanelEdge(reader)
                } else {
                    window = try makeWindow(reader)
                }
            case "Image":
                let name = try reader.requiredString("name")
                guard images[name] == nil else {
                    throw UIScriptError.duplicateName(name)
                }
                images[name] = try makeImage(reader)
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
            case "ToolbarItem":
                firstWindowOnlyElement = firstWindowOnlyElement ?? element
                toolbarItems.append(UIScript.ToolbarItem(
                    name: try reader.requiredString("name"),
                    title: try reader.requiredString("title"),
                    tab: reader.string("tab")
                ))
            case "Tab":
                firstWindowOnlyElement = firstWindowOnlyElement ?? element
                let name = try reader.requiredString("name")
                tabs.append(UIScript.Tab(
                    name: name,
                    contents: try element.children.map { try readContent($0, in: element) }
                ))
            case "Pane":
                firstWindowOnlyElement = firstWindowOnlyElement ?? element
                let name = try reader.requiredString("name")
                let title = try reader.requiredString("title")
                let pane = UIScript.Pane(
                    name: name,
                    title: title,
                    contents: try element.children.map { try readContent($0, in: element) }
                )
                panes.append((pane, element))
            case "Sidebar":
                if sidebarElement != nil {
                    throw UIScriptError.duplicateElement("Sidebar", line: element.line)
                }
                firstWindowOnlyElement = firstWindowOnlyElement ?? element
                sidebarElement = element
                sidebarName = try reader.requiredString("name")
                sidebarWidth = try reader.requiredNumber("width")
                guard sidebarWidth > 0 else {
                    throw reader.invalid("width", reader.string("width") ?? "")
                }
                // A sidebar that holds controls places them itself, which Hudini doesn't read.
                // `edge` is left unread: the spec lets a reader draw the sidebar on the left.
                if !element.children.isEmpty {
                    throw UIScriptError.unsupportedSidebar(line: element.line)
                }
            case "TitleField":
                guard titleField == nil else {
                    throw UIScriptError.duplicateElement("TitleField", line: element.line)
                }
                firstWindowOnlyElement = firstWindowOnlyElement ?? element
                titleField = UIScript.TitleField(
                    name: try reader.requiredString("name"),
                    placeholder: reader.string("placeholder")
                )
            default:
                // Read with its own reader, which lists its ignored attributes.
                _ = try readContent(element, in: nil)
                if let child = element.children.first {
                    throw UIScriptError.unexpectedNesting(child.name, line: child.line)
                }
                continue
            }
            if !Self.holders.contains(element.name), let child = element.children.first {
                throw UIScriptError.unexpectedNesting(child.name, line: child.line)
            }
            ignoredAttributes += reader.unusedAttributes()
        }

        guard let window else {
            throw UIScriptError.missingElement("Window")
        }
        if panelEdge != nil, let firstWindowOnlyElement {
            throw UIScriptError.notAllowedInPanel(firstWindowOnlyElement.name, line: firstWindowOnlyElement.line)
        }
        let sidebar = try makeSidebar(
            element: sidebarElement, name: sidebarName, width: sidebarWidth,
            panes: panes, flatPaneControls: flatPaneControls
        )
        return UIScript(
            version: version,
            requiredFeatures: requiredFeatures,
            window: window,
            panelEdge: panelEdge,
            resources: UIScript.Resources(images: images, strings: strings),
            styles: styles,
            visuals: visuals,
            controls: controls,
            toolbarItems: toolbarItems,
            titleField: titleField,
            tabs: tabs,
            sidebar: sidebar,
            ignoredAttributes: ignoredAttributes
        )
    }

    /// The elements that may hold others in a document Hudini reads.
    private static let holders: Set<String> = ["Tab", "Pane", "Sidebar"]

    /// Puts the panes in their sidebar, adding the controls that name a pane with `pane`, or
    /// returns `nil` when the document has neither.
    private static func makeSidebar(
        element: Element?,
        name: String,
        width: Float,
        panes: [(pane: UIScript.Pane, element: Element)],
        flatPaneControls: [(control: String, pane: String)]
    ) throws -> UIScript.Sidebar? {
        guard let element else {
            if let first = panes.first {
                throw UIScriptError.panesWithoutSidebar(line: first.element.line)
            }
            if let control = flatPaneControls.first {
                throw UIScriptError.unknownReference(owner: control.control, property: "pane", reference: control.pane)
            }
            return nil
        }
        // A sidebar without panes is a list the host fills, which Hudini doesn't read.
        guard !panes.isEmpty else {
            throw UIScriptError.unsupportedSidebar(line: element.line)
        }
        let paneNames = Set(panes.map(\.pane.name))
        for (control, pane) in flatPaneControls where !paneNames.contains(pane) {
            throw UIScriptError.unknownReference(owner: control, property: "pane", reference: pane)
        }
        let filled = panes.map { entry in
            let named = flatPaneControls.filter { $0.pane == entry.pane.name }.map(\.control)
            return (entry.pane, named)
        }
        if let (pane, _) = filled.first(where: { !$0.0.contents.isEmpty && !$0.1.isEmpty }) {
            throw UIScriptError.paneUsesBothForms(pane: pane.name)
        }
        return UIScript.Sidebar(
            name: name,
            width: width,
            content: .panes(filled.map { pane, named in
                UIScript.Pane(name: pane.name, title: pane.title, contents: pane.contents + named)
            })
        )
    }

    private static let controlTypes: [String: UIScript.ControlType] = [
        "Text": .text,
        "FormattedText": .formattedText,
        "Button": .button,
        "TextField": .textField,
        "TextArea": .textArea,
        "List": .list,
        "Slider": .slider,
        "ProgressBar": .progressBar,
        "Region": .region
    ]

    private static func makeWindow(_ reader: AttributeReader) throws -> UIScript.Window {
        try makeWindow(reader, isResizable: reader.boolean("resizable") ?? false)
    }

    /// Reads a panel's size. A panel takes `minWidth` and `minHeight`, which floor its layout when
    /// the host stretches it to the screen, but not `resizable`, which stays unread and is listed.
    private static func makePanelWindow(_ reader: AttributeReader) throws -> UIScript.Window {
        try makeWindow(reader, isResizable: false)
    }

    private static func makePanelEdge(_ reader: AttributeReader) throws -> UIScript.PanelEdge {
        let value = try reader.requiredString("edge")
        guard let edge = UIScript.PanelEdge(rawValue: value) else {
            throw reader.invalid("edge", value)
        }
        return edge
    }

    private static func makeWindow(_ reader: AttributeReader, isResizable: Bool) throws -> UIScript.Window {
        let size = UIScript.Size(
            width: try reader.requiredNumber("width"),
            height: try reader.requiredNumber("height")
        )
        let minWidth = try reader.number("minWidth")
        let minHeight = try reader.number("minHeight")
        switch (minWidth, minHeight) {
        case (nil, nil):
            return UIScript.Window(size: size, minSize: nil, isResizable: isResizable)
        case let (width?, height?):
            return UIScript.Window(size: size, minSize: UIScript.Size(width: width, height: height), isResizable: isResizable)
        case (nil, _):
            throw reader.missing("minWidth")
        case (_, nil):
            throw reader.missing("minHeight")
        }
    }

    // A window's style takes the spec's typefaces for `font`. An appearance's can also name one of
    // its `<Font>`s, which the appearance checks once it has read them all.
    private static func makeStyle(_ reader: AttributeReader, allowsNamedFont: Bool = false) throws -> UIScript.Style {
        var font: UIScript.Typeface?
        var fontName: String?
        if allowsNamedFont, let value = reader.string("font"), UIScript.Typeface(rawValue: value) == nil {
            fontName = value
        } else {
            font = try reader.typeface("font")
        }
        return UIScript.Style(
            colors: try makeStyleColors(reader, prefix: ""),
            darkColors: try makeStyleColors(reader, prefix: "dark"),
            size: try reader.styleSize("fontSize"),
            font: font,
            fontName: fontName
        )
    }

    // A dark twin is its color's attribute with `dark` before it, such as `darkTextColor`.
    private static func makeStyleColors(_ reader: AttributeReader, prefix: String) throws -> UIScript.StyleColors {
        func named(_ attribute: String) -> String {
            prefix.isEmpty ? attribute : prefix + attribute.prefix(1).uppercased() + attribute.dropFirst()
        }
        return UIScript.StyleColors(
            textColor: try reader.styleColor(named("textColor")),
            selectedTextColor: try reader.styleColor(named("selectedTextColor")),
            highlightedTextColor: try reader.styleColor(named("highlightedTextColor")),
            disabledTextColor: try reader.styleColor(named("disabledTextColor")),
            backgroundColor: try reader.styleColor(named("backgroundColor")),
            borderColor: try reader.styleColor(named("borderColor")),
            fillColor: try reader.styleColor(named("fillColor"))
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
        // Refused rather than ignored: a control left in place would do nothing.
        if reader.string("scrolls") != nil || reader.string("direction") != nil {
            throw UIScriptError.retiredScrolling(owner: name)
        }
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
            isReadOnly: try reader.boolean("readOnly") ?? false,
            isSecure: try reader.boolean("secure") ?? false,
            isSelectable: try reader.boolean("selectable") ?? false,
            alignment: try reader.alignment("alignment") ?? .left,
            valueRange: try makeValueRange(owner: name, reader),
            step: try reader.number("step"),
            follows: try reader.boolean("follows") ?? false,
            isInitiallyHidden: false
        )
    }

    private static func makeValueRange(
        owner: String,
        _ reader: AttributeReader
    ) throws -> ClosedRange<Float>? {
        let minimum = try reader.number("minValue")
        let maximum = try reader.number("maxValue")
        guard minimum != nil || maximum != nil else {
            return nil
        }
        let (lower, upper) = (minimum ?? 0, maximum ?? 1)
        guard lower < upper else {
            throw UIScriptError.invalidValueRange(owner: owner)
        }
        return lower...upper
    }

}

private struct Element {
    let name: String
    let attributes: [String: String]
    let line: Int
    /// The elements directly inside this one. Which elements may hold others, and what, is the
    /// document builder's to check.
    var children: [Element] = []
}

/// The kinds of document the XML reader reads, which differ in their root and what they report.
private enum DocumentKind {
    case uiScript
    case appearance
}

/// Gathers the document's elements, which sit directly under the root, with one level of
/// elements inside them.
private final class ElementCollector: NSObject, XMLParserDelegate {
    private(set) var root: Element?
    private(set) var elements: [Element] = []
    private(set) var failure: UIScriptError?
    private var depth = 0
    private let kind: DocumentKind

    init(kind: DocumentKind) {
        self.kind = kind
    }

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
            switch kind {
            case .uiScript where elementName != "UIScript":
                return fail(.invalidRoot(elementName), parser)
            case .appearance where elementName != "Appearance":
                return fail(.invalidAppearanceRoot(elementName), parser)
            default:
                break
            }
            root = element
            // A newer document may use elements this reader rejects, so report its
            // version or features first. Those errors say what to do about it.
            if let problem = compatibilityProblem(with: attributes) {
                return fail(problem, parser)
            }
        case 1:
            elements.append(element)
        case 2 where kind == .uiScript:
            elements[elements.count - 1].children.append(element)
        default:
            switch kind {
            case .uiScript:
                return fail(.unexpectedNesting(elementName, line: parser.lineNumber), parser)
            case .appearance:
                return fail(.unexpectedAppearanceElement(elementName, line: parser.lineNumber), parser)
            }
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
        if kind == .appearance {
            guard let value = attributes["version"] else {
                return nil
            }
            guard let version = Int(value), version >= 1 else {
                return .invalidAttribute(element: "Appearance", attribute: "version", value: value, line: 1)
            }
            return version > Appearance.supportedVersion ? .unsupportedAppearanceVersion(version) : nil
        }
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
            .first {
                !UIScript.supportedFeatures.contains(String($0)) && !UIScript.retiredFeatures.contains(String($0))
            }
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

    func invalid(_ attribute: String, _ value: String) -> UIScriptError {
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

    /// Reads a style's color: a role's name, or a hex color.
    func styleColor(_ attribute: String) throws -> UIScript.StyleColor? {
        guard let value = string(attribute) else {
            return nil
        }
        if let role = UIScript.ColorRole(rawValue: value) {
            return .role(role)
        }
        guard let color = Self.color(fromHex: value) else {
            throw invalid(attribute, value)
        }
        return .fixed(color)
    }

    /// Reads a style's font size: a role's name, or a whole number of pixels. Whether the number is
    /// positive is checked with the rest of the document.
    func styleSize(_ attribute: String) throws -> UIScript.StyleSize? {
        guard let value = string(attribute) else {
            return nil
        }
        if let role = UIScript.SizeRole(rawValue: value) {
            return .role(role)
        }
        guard let size = Int(value) else {
            throw invalid(attribute, value)
        }
        return .fixed(size)
    }

    func typeface(_ attribute: String) throws -> UIScript.Typeface? {
        guard let value = string(attribute) else {
            return nil
        }
        guard let typeface = UIScript.Typeface(rawValue: value) else {
            throw invalid(attribute, value)
        }
        return typeface
    }

    func alignment(_ attribute: String) throws -> UIScript.TextAlignment? {
        guard let value = string(attribute) else {
            return nil
        }
        guard let alignment = UIScript.TextAlignment(rawValue: value) else {
            throw invalid(attribute, value)
        }
        return alignment
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
