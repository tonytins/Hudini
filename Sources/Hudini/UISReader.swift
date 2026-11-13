import Foundation
import Raylib

/// Reads Maxis' `.uis` interface files into the UIScript model.
///
/// A `.uis` file looks like XML but is not: tags are never closed, the first string is a
/// positional name, values can be tuples such as `(19,39)`, comments start with `#`, and tag,
/// attribute, and reference names ignore case.
///
/// Only broken syntax fails. Real files reference things game code supplies, so anything the
/// model cannot represent lands in `conversionNotes` or `ignoredAttributes` instead.
enum UISReader {
    static func read(_ data: Data) throws -> UIScript {
        // Some files carry bytes that are not UTF-8. Latin-1 accepts any byte, so it always decodes.
        let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""
        var scanner = UISScanner(text)
        var builder = UISBuilder(tags: try scanner.tags())
        return try builder.build()
    }

    static func number(from value: String) -> Float? {
        Float(value.trimmingCharacters(in: .whitespaces)).flatMap { $0.isFinite ? $0 : nil }
    }

    static func numbers(from value: String) -> [Float]? {
        guard value.hasPrefix("("), value.hasSuffix(")") else {
            return nil
        }
        let numbers = value.dropFirst().dropLast().split(separator: ",").map {
            Float($0.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return numbers.contains(nil) ? nil : numbers.compactMap { $0 }
    }
}

private struct UISTag {
    let name: String
    let label: String?
    let attributes: [String: String]
    let line: Int

    var key: String { name.lowercased() }
}

private struct UISScanner {
    private let scalars: [Unicode.Scalar]
    private var index = 0
    private var line = 1

    init(_ text: String) {
        scalars = Array(text.unicodeScalars)
    }

    mutating func tags() throws -> [UISTag] {
        var tags: [UISTag] = []
        while let scalar = current {
            switch scalar {
            case "#":
                skipComment()
            case "<":
                tags.append(try tag())
            default:
                advance()
            }
        }
        return tags
    }

    private var current: Unicode.Scalar? {
        index < scalars.count ? scalars[index] : nil
    }

    private mutating func advance() {
        if current == "\n" {
            line += 1
        }
        index += 1
    }

    private mutating func skipComment() {
        while let scalar = current, scalar != "\n" {
            advance()
        }
    }

    private mutating func skipWhitespace() {
        while let scalar = current, scalar.properties.isWhitespace {
            advance()
        }
    }

    private mutating func word(endingAt isEnd: (Unicode.Scalar) -> Bool) -> String {
        var result = String.UnicodeScalarView()
        while let scalar = current, !scalar.properties.isWhitespace, !isEnd(scalar) {
            result.append(scalar)
            advance()
        }
        return String(result)
    }

    private mutating func enclosed(closingWith close: Unicode.Scalar, startLine: Int) throws -> String {
        advance()
        var result = String.UnicodeScalarView()
        while let scalar = current {
            if scalar == close {
                advance()
                return String(result)
            }
            result.append(scalar)
            advance()
        }
        throw UIScriptError.malformedUIS(line: startLine, reason: "A '\(close)' is missing.")
    }

    private mutating func tag() throws -> UISTag {
        let startLine = line
        advance()
        let name = word { $0 == ">" || $0 == "\"" || $0 == "#" || $0 == "<" }
        guard !name.isEmpty else {
            throw UIScriptError.malformedUIS(line: startLine, reason: "A tag has no name.")
        }
        var label: String?
        var attributes: [String: String] = [:]
        while true {
            skipWhitespace()
            guard let scalar = current else {
                throw UIScriptError.malformedUIS(line: startLine, reason: "Tag '\(name)' is never closed.")
            }
            switch scalar {
            case ">":
                advance()
                return UISTag(name: name, label: label, attributes: attributes, line: startLine)
            case "#":
                skipComment()
            case "<":
                throw UIScriptError.malformedUIS(line: startLine, reason: "Tag '\(name)' is never closed.")
            case "\"":
                let text = try enclosed(closingWith: "\"", startLine: line)
                if label == nil {
                    label = text
                }
            default:
                let key = word { $0 == "=" || $0 == ">" || $0 == "\"" || $0 == "#" || $0 == "<" }
                guard !key.isEmpty else {
                    advance()
                    continue
                }
                skipWhitespace()
                guard current == "=" else {
                    attributes[key.lowercased()] = ""
                    continue
                }
                advance()
                skipWhitespace()
                attributes[key.lowercased()] = try value()
            }
        }
    }

    private mutating func value() throws -> String {
        switch current {
        case "\"":
            return try enclosed(closingWith: "\"", startLine: line)
        case "(":
            return "(" + (try enclosed(closingWith: ")", startLine: line)) + ")"
        default:
            return word { $0 == ">" || $0 == "#" || $0 == "<" }
        }
    }
}

/// One tag's attributes, with its scope's shared properties merged in, tracking which were used.
private final class UISAttributes {
    private let attributes: [String: String]
    private var used: Set<String> = []

    init(_ attributes: [String: String]) {
        self.attributes = attributes
    }

    func string(_ key: String) -> String? {
        used.insert(key)
        return attributes[key]
    }

    func number(_ key: String) -> Float? {
        string(key).flatMap(UISReader.number(from:))
    }

    func integer(_ key: String) -> Int? {
        string(key).flatMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }

    func tuple(_ key: String) -> [Float]? {
        string(key).flatMap(UISReader.numbers(from:))
    }

    func color(_ key: String) -> Color? {
        guard let parts = tuple(key), parts.count == 3 else {
            return nil
        }
        let channels = parts.map { UInt8(min(max($0, 0), 255)) }
        return Color(r: channels[0], g: channels[1], b: channels[2], a: 255)
    }

    func unused() -> [String] {
        attributes.keys.filter { !used.contains($0) }.sorted()
    }
}

private struct UISBuilder {
    private static let controlTypes: [String: (type: UIScript.ControlType, element: String)] = [
        "addtext": (.text, "AddText"),
        "addformatedtext": (.formattedText, "AddFormatedText"),
        "addbutton": (.button, "AddButton"),
        "addtextedit": (.textField, "AddTextEdit"),
        "addlistbox": (.list, "AddListBox"),
        "addslider": (.slider, "AddSlider"),
        "addprogressbar": (.progressBar, "AddProgressBar")
    ]
    private static let supportedStateCounts: Set<Int> = [1, 4, 6]
    private static let centeredAlignment = 3
    private static let orientations: [Int: UIScript.Orientation] = [0: .horizontal, 1: .vertical]

    private let tags: [UISTag]
    private var notes: [UIScript.ConversionNote] = []
    private var ignored: [UIScript.IgnoredAttribute] = []
    private var styles: [String: UIScript.Style] = [:]
    private var usedNames: Set<String> = []

    init(tags: [UISTag]) {
        self.tags = tags
    }

    private mutating func note(_ tag: UISTag, _ message: String) {
        notes.append(UIScript.ConversionNote(element: tag.name, name: tag.label, line: tag.line, message: message))
    }

    private mutating func report(_ reader: UISAttributes, _ tag: UISTag) {
        for attribute in reader.unused() {
            ignored.append(UIScript.IgnoredAttribute(element: tag.name, attribute: attribute, line: tag.line))
        }
    }

    mutating func build() throws -> UIScript {
        let resolved = try resolveScopes()

        // Reference names ignore case, so index them by their lowercased form.
        var stringNames: [String: String] = [:]
        var strings: [String: UIScript.StringResource] = [:]
        var imageNames: [String: String] = [:]
        var imageAttributes: [String: (path: String?, assetID: String?)] = [:]
        for (tag, attributes) in resolved {
            let reader = UISAttributes(attributes)
            switch tag.key {
            case "definestring":
                _ = reader.string("stringdir")
                _ = reader.string("stringtable")
                guard let name = tag.label, let index = reader.integer("stringindex") else {
                    note(tag, "This string has no name or index, so it was skipped.")
                    continue
                }
                let table = [attributes["stringdir"], attributes["stringtable"]]
                    .compactMap { $0 }
                    .joined(separator: ":")
                stringNames[name.lowercased()] = name
                strings[name] = UIScript.StringResource(table: table, index: index)
            case "defineimage":
                guard let name = tag.label else {
                    note(tag, "This image has no name, so it was skipped.")
                    continue
                }
                let path = reader.string("path")
                let assetID = reader.string("assetid")
                guard path != nil || assetID != nil else {
                    note(tag, "This image has no path or assetID, so it was skipped.")
                    continue
                }
                imageNames[name.lowercased()] = name
                imageAttributes[name] = (path, assetID)
            default:
                continue
            }
        }

        var window: UIScript.Window?
        var stateCounts: [String: Int] = [:]
        var visuals: [UIScript.Visual] = []
        var controls: [UIScript.Control] = []
        var settings: [String: UIScript.Setting] = [:]
        for (tag, attributes) in resolved {
            let reader = UISAttributes(attributes)
            // Shared string settings reach every tag in their scope, but only strings use them.
            _ = reader.string("stringdir")
            _ = reader.string("stringtable")
            switch tag.key {
            case "definestring", "defineimage":
                continue
            case "setcontrolproperties":
                // Game code reads these by name, and nothing draws until the host asks. Every
                // attribute stays in the setting, so none count as ignored.
                addSetting(tag, attributes, imageNames, to: &settings)
                if tag.label?.lowercased() == "dialogsize" {
                    window = makeWindow(reader, tag)
                } else if let visual = makeVisual(reader, tag, imageNames) {
                    visuals.append(visual)
                } else if let region = makeRegion(reader, tag) {
                    controls.append(region)
                }
                continue
            default:
                guard let kind = Self.controlTypes[tag.key] else {
                    note(tag, "Hudini has no equivalent for this tag, so it was skipped.")
                    continue
                }
                guard let control = makeControl(
                    kind.type,
                    reader,
                    tag,
                    stringNames: stringNames,
                    imageNames: imageNames,
                    stateCounts: &stateCounts
                ) else {
                    continue
                }
                controls.append(control)
            }
            report(reader, tag)
        }

        let images = imageAttributes.reduce(into: [String: UIScript.ImageResource]()) { result, entry in
            result[entry.key] = UIScript.ImageResource(
                path: entry.value.path,
                assetID: entry.value.assetID,
                stateCount: stateCounts[entry.key] ?? 1
            )
        }
        return UIScript(
            version: 1,
            requiredFeatures: [],
            window: window ?? Self.windowFitting(visuals: visuals, controls: controls),
            resources: UIScript.Resources(images: images, strings: strings),
            styles: styles,
            visuals: visuals,
            controls: controls,
            settings: settings,
            ignoredAttributes: ignored,
            conversionNotes: notes
        )
    }

    /// Applies `<Begin>`, `<End>`, and `<SetSharedProperties>`, leaving each other tag with its
    /// full set of attributes. A tag's own attributes win over shared ones.
    private func resolveScopes() throws -> [(UISTag, [String: String])] {
        var scopes: [[String: String]] = [[:]]
        var resolved: [(UISTag, [String: String])] = []
        for tag in tags {
            switch tag.key {
            case "begin":
                scopes.append(scopes[scopes.count - 1])
            case "end":
                guard scopes.count > 1 else {
                    throw UIScriptError.malformedUIS(line: tag.line, reason: "This <End> has no matching <Begin>.")
                }
                scopes.removeLast()
            case "setsharedproperties":
                scopes[scopes.count - 1].merge(tag.attributes) { _, new in new }
            default:
                resolved.append((tag, scopes[scopes.count - 1].merging(tag.attributes) { _, own in own }))
            }
        }
        guard scopes.count == 1 else {
            throw UIScriptError.malformedUIS(line: tags.last?.line ?? 1, reason: "A <Begin> has no matching <End>.")
        }
        return resolved
    }

    private mutating func addSetting(
        _ tag: UISTag,
        _ attributes: [String: String],
        _ imageNames: [String: String],
        to settings: inout [String: UIScript.Setting]
    ) {
        guard let name = tag.label else {
            note(tag, "This setting has no name, so nothing can look it up.")
            return
        }
        guard settings[name.lowercased()] == nil else {
            note(tag, "This setting's name is already taken, so this one was skipped.")
            return
        }
        settings[name.lowercased()] = UIScript.Setting(
            name: name,
            line: tag.line,
            image: attributes["image"].flatMap { imageNames[$0.lowercased()] },
            values: attributes.filter { $0.key != "stringdir" && $0.key != "stringtable" }
        )
    }

    private mutating func makeWindow(_ reader: UISAttributes, _ tag: UISTag) -> UIScript.Window? {
        guard let size = reader.tuple("size"), size.count == 2, size[0] > 0, size[1] > 0 else {
            note(tag, "This dialog size is unusable, so the window was sized to fit its contents.")
            return nil
        }
        let minimum = reader.tuple("minsize")
        guard let minimum, minimum.count == 2, minimum[0] > 0, minimum[1] > 0,
              minimum[0] <= size[0], minimum[1] <= size[1] else {
            if minimum != nil {
                note(tag, "This minimum size is unusable, so it was dropped.")
            }
            return UIScript.Window(size: UIScript.Size(width: size[0], height: size[1]), minSize: nil)
        }
        return UIScript.Window(
            size: UIScript.Size(width: size[0], height: size[1]),
            minSize: UIScript.Size(width: minimum[0], height: minimum[1])
        )
    }

    private static func windowFitting(visuals: [UIScript.Visual], controls: [UIScript.Control]) -> UIScript.Window {
        var width: Float = 1
        var height: Float = 1
        for frame in visuals.map(\.frame) + controls.map(\.frame) {
            width = max(width, frame.x + (frame.width ?? 0))
            height = max(height, frame.y + (frame.height ?? 0))
        }
        return UIScript.Window(size: UIScript.Size(width: width, height: height), minSize: nil)
    }

    private mutating func uniqueName(for tag: UISTag) -> String? {
        let name = tag.label ?? "line\(tag.line)"
        guard usedNames.insert(name).inserted else {
            note(tag, "This name is already taken, so this one was skipped.")
            return nil
        }
        return name
    }

    private mutating func makeVisual(
        _ reader: UISAttributes,
        _ tag: UISTag,
        _ imageNames: [String: String]
    ) -> UIScript.Visual? {
        guard let reference = reader.string("image") else {
            return nil
        }
        guard let image = imageNames[reference.lowercased()] else {
            note(tag, "Image '\(reference)' is not defined here, so this visual was skipped.")
            return nil
        }
        guard reader.tuple("position") != nil, let name = uniqueName(for: tag) else {
            return nil
        }
        return UIScript.Visual(name: name, image: image, frame: makeFrame(reader, tag), isInitiallyHidden: true)
    }

    private mutating func makeRegion(_ reader: UISAttributes, _ tag: UISTag) -> UIScript.Control? {
        guard let position = reader.tuple("position"), position.count == 2,
              let size = reader.tuple("size"), size.count == 2,
              size[0] >= 0, size[1] >= 0,
              let name = uniqueName(for: tag) else {
            return nil
        }
        return UIScript.Control(
            name: name,
            type: .region,
            legacyID: nil,
            frame: makeFrame(reader, tag),
            style: nil,
            text: nil,
            placeholder: nil,
            image: nil,
            tooltip: nil,
            maximumLength: nil,
            scrolls: nil,
            isReadOnly: false,
            isSecure: false,
            isSelectable: false,
            alignment: .left,
            valueRange: nil,
            orientation: nil,
            follows: false,
            isInitiallyHidden: true
        )
    }

    private mutating func makeFrame(_ reader: UISAttributes, _ tag: UISTag) -> UIScript.Frame {
        var x: Float = 0
        var y: Float = 0
        if let position = reader.tuple("position"), position.count == 2 {
            (x, y) = (position[0], position[1])
        } else {
            note(tag, "This has no position, so it was placed at the corner. Game code likely positions it.")
        }
        var width: Float?
        var height: Float?
        if let size = reader.tuple("size"), size.count == 2 {
            if size[0] >= 0, size[1] >= 0 {
                (width, height) = (size[0], size[1])
            } else {
                note(tag, "This has a negative size, so it was left out.")
            }
        }
        func offset(_ names: String...) -> Float? {
            names.lazy.compactMap { reader.number($0) }.first
        }
        let left = offset("edgeoffsetl", "offsetl")
        let right = offset("edgeoffsetr", "offsetr")
        let top = offset("edgeoffsett", "offsett")
        let bottom = offset("edgeoffsetb", "offsetb")
        let hasOffsets = left != nil || right != nil || top != nil || bottom != nil
        return UIScript.Frame(
            x: x,
            y: y,
            width: width,
            height: height,
            edgeOffsets: hasOffsets ? UIScript.EdgeOffsets(left: left, right: right, top: top, bottom: bottom) : nil
        )
    }

    private mutating func makeControl(
        _ type: UIScript.ControlType,
        _ reader: UISAttributes,
        _ tag: UISTag,
        stringNames: [String: String],
        imageNames: [String: String],
        stateCounts: inout [String: Int]
    ) -> UIScript.Control? {
        guard let name = uniqueName(for: tag) else {
            return nil
        }

        var image: String?
        if type == .button, let reference = reader.string("image") {
            image = imageNames[reference.lowercased()]
            if image == nil {
                note(tag, "Image '\(reference)' is not defined here, so this button has none.")
            }
        }
        if let image {
            // Maxis button images hold four states unless a button says otherwise.
            let count = reader.integer("imagestates") ?? 4
            if Self.supportedStateCounts.contains(count) {
                stateCounts[image] = max(stateCounts[image] ?? 1, count)
            } else {
                note(tag, "Hudini cannot slice an image into \(count) states, so it shows the whole image.")
            }
        }

        var frame = makeFrame(reader, tag)
        if image == nil, frame.width == nil || frame.height == nil {
            note(tag, "This has no size or image to take one from, so it has no size. Game code likely sets it.")
            frame = UIScript.Frame(
                x: frame.x,
                y: frame.y,
                width: frame.width ?? 0,
                height: frame.height ?? 0,
                edgeOffsets: frame.edgeOffsets
            )
        }

        var tooltip: String?
        // Files spell this both `tooltip` and `toolTip`, which the scanner has already folded.
        if let reference = reader.string("tooltip") {
            tooltip = stringNames[reference.lowercased()]
            if tooltip == nil {
                note(tag, "Tooltip '\(reference)' is not defined here, so it was dropped.")
            }
        }

        var text: UIScript.Text?
        if let value = reader.string("text") {
            text = stringNames[value.lowercased()].map(UIScript.Text.string) ?? .literal(value)
        }

        var alignment = UIScript.TextAlignment.left
        if let value = reader.integer("alignment") {
            if value == Self.centeredAlignment {
                alignment = .center
            } else {
                note(tag, "The meaning of alignment \(value) is unknown, so this text stays left-aligned.")
            }
        }

        var maximumLength: Int?
        if type == .textField, let capacity = reader.integer("capacity") {
            if capacity > 0 {
                maximumLength = capacity
            } else {
                note(tag, "This capacity is unusable, so the default length applies.")
            }
        }

        return UIScript.Control(
            name: name,
            type: type,
            legacyID: reader.integer("id"),
            frame: frame,
            style: makeStyle(reader, for: name),
            text: text,
            placeholder: nil,
            image: image,
            tooltip: tooltip,
            maximumLength: maximumLength,
            scrolls: nil,
            isReadOnly: reader.string("mode") == "kReadOnly" && type == .textField,
            isSecure: false,
            isSelectable: false,
            alignment: alignment,
            valueRange: makeValueRange(type, reader, tag),
            orientation: makeOrientation(type, reader, tag),
            follows: false,
            isInitiallyHidden: false
        )
    }

    private mutating func makeValueRange(
        _ type: UIScript.ControlType,
        _ reader: UISAttributes,
        _ tag: UISTag
    ) -> ClosedRange<Float>? {
        guard type == .slider || type == .progressBar else {
            return nil
        }
        let minimum = reader.number("minvalue")
        let maximum = reader.number("maxvalue")
        guard minimum != nil || maximum != nil else {
            return nil
        }
        let (lower, upper) = (minimum ?? 0, maximum ?? 1)
        guard lower < upper else {
            note(tag, "This value range is empty, so the default of 0 to 1 applies.")
            return nil
        }
        return lower...upper
    }

    private mutating func makeOrientation(
        _ type: UIScript.ControlType,
        _ reader: UISAttributes,
        _ tag: UISTag
    ) -> UIScript.Orientation? {
        guard type == .slider, let value = reader.integer("orientation") else {
            return nil
        }
        guard let orientation = Self.orientations[value] else {
            note(tag, "The meaning of orientation \(value) is unknown, so this slider follows its shape.")
            return nil
        }
        return orientation
    }

    /// Turns a control's own colors and font into a style named after it, because `.uis` has no
    /// named styles to refer to.
    private mutating func makeStyle(_ reader: UISAttributes, for name: String) -> String? {
        let textColor = reader.color("color") ?? reader.color("textcolor")
        let selected = reader.color("textcolorselected") ?? reader.color("colorselected")
        let highlighted = reader.color("textcolorhighlighted") ?? reader.color("colorhighlighted")
        let disabled = reader.color("textcolordisabled") ?? reader.color("colordisabled")
        let background = reader.color("backcolor") ?? reader.color("backgroundcolor")
        let border = reader.color("framecolor")
        let font = reader.integer("font").flatMap { $0 > 0 ? $0 : nil }
        let colors = [textColor, selected, highlighted, disabled, background, border]
        guard font != nil || colors.contains(where: { $0 != nil }) else {
            return nil
        }
        let styleName = "\(name)Style"
        styles[styleName] = UIScript.Style(
            colors: UIScript.StyleColors(
                textColor: textColor.map { .fixed($0) },
                selectedTextColor: selected.map { .fixed($0) },
                highlightedTextColor: highlighted.map { .fixed($0) },
                disabledTextColor: disabled.map { .fixed($0) },
                backgroundColor: background.map { .fixed($0) },
                borderColor: border.map { .fixed($0) }
            ),
            size: font.map { .fixed($0) },
            font: nil
        )
        return styleName
    }
}
