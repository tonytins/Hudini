import Foundation

/// One `.cst` string table: keys and the text they hold, written as `key ^text^` or just
/// `^text^`, which is known by its position from 0.
///
/// Reading never fails, because a table with one bad entry is still useful. Anything skipped
/// lands in `problems`.
public struct CSTFile: Sendable {
    /// Something in a table that could not be read as an entry.
    public struct Problem: Sendable, Equatable {
        /// The line in the file.
        public let line: Int

        /// What happened.
        public let message: String
    }

    /// The text of each entry by its key.
    ///
    /// An entry with no key is known by its position as a number, and also by the line above it
    /// when there is one, so a value can appear under two keys.
    public let entries: [String: String]

    /// What could not be read.
    public let problems: [Problem]

    /// Reads a table. Real files are UTF-8, with or without a byte order mark, or Windows-1252.
    public init(data: Data) {
        var parser = CSTParser(lines: Self.lines(of: Self.decoded(data)))
        parser.parse()
        entries = parser.entries
        problems = parser.problems
    }

    private static func decoded(_ data: Data) -> String {
        let byteOrderMark = Data([0xEF, 0xBB, 0xBF])
        let body = data.starts(with: byteOrderMark) ? data.dropFirst(byteOrderMark.count) : data
        return String(data: body, encoding: .utf8)
            ?? String(data: body, encoding: .windowsCP1252)
            ?? String(data: body, encoding: .isoLatin1)
            ?? ""
    }

    private static func lines(of text: String) -> [String] {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{2028}", with: "\n")
            .components(separatedBy: "\n")
    }
}

/// Reads entries from whole lines, because comments only count at the start of a line, while
/// values run across lines.
///
/// An entry's key is the text before its opening caret on the same line. Without one, a number
/// alone on the line above is its key. Otherwise the entry is known by its position among all the
/// table's entries, counting from 0, and also by the line above it if there is one. That line may
/// be a name game code looks up or a note for translators, and nothing in the file tells them
/// apart, so a real key always wins over it.
private struct CSTParser {
    private static let caret: Character = "^"

    private let lines: [String]
    private var position = 0
    private var lineAbove: String?
    private var namesFromLinesAbove: Set<String> = []
    private(set) var entries: [String: String] = [:]
    private(set) var problems: [CSTFile.Problem] = []

    init(lines: [String]) {
        self.lines = lines
    }

    private mutating func report(_ message: String, line: Int) {
        problems.append(CSTFile.Problem(line: line + 1, message: message))
    }

    /// Returns the lines that are not comments, with their indexes in the file.
    private func contentLines() -> [(index: Int, text: String)] {
        var result: [(Int, String)] = []
        var isInBlockComment = false
        for (index, line) in lines.enumerated() {
            let content = line.drop(while: \.isWhitespace)
            if isInBlockComment {
                isInBlockComment = !line.contains("*/")
            } else if content.hasPrefix("/*") {
                isInBlockComment = !line.contains("*/")
            } else if !content.hasPrefix("//"), !content.hasPrefix("#") {
                result.append((index, line))
            }
        }
        return result
    }

    mutating func parse() {
        var openValue: (key: String, name: String?, text: String, line: Int)?
        for (index, line) in contentLines() {
            var rest = Substring(line)
            if let open = openValue {
                guard let caret = rest.firstIndex(of: Self.caret) else {
                    openValue = (open.key, open.name, open.text + "\n" + rest, open.line)
                    continue
                }
                if !Self.isCompleteEntry(rest) {
                    add(open.text + "\n" + rest[..<caret], key: open.key, name: open.name, line: open.line)
                    openValue = nil
                    rest = rest[rest.index(after: caret)...]
                } else {
                    // The next entry began before this one closed, so losing one beats misreading
                    // every entry after it.
                    report("The value of key '\(open.key)' has no closing caret, so it was skipped.", line: open.line)
                    position += 1
                    openValue = nil
                }
            }
            var hadValue = false
            while let caret = rest.firstIndex(of: Self.caret) {
                hadValue = true
                let (key, name) = keys(before: rest[..<caret])
                let value = rest[rest.index(after: caret)...]
                guard let end = value.firstIndex(of: Self.caret) else {
                    openValue = (key, name, String(value), index)
                    rest = ""
                    break
                }
                add(String(value[..<end]), key: key, name: name, line: index)
                rest = value[value.index(after: end)...]
            }
            // Text after a value on its line describes that value, not the next one.
            let note = rest.trimmingCharacters(in: .whitespaces)
            if !hadValue, openValue == nil, !note.isEmpty {
                lineAbove = note
            }
        }
        if let open = openValue {
            report("The value of key '\(open.key)' has no closing caret, so it was skipped.", line: open.line)
        }
    }

    /// Returns whether a line holds an optional key and a whole value, and nothing else.
    private static func isCompleteEntry(_ line: Substring) -> Bool {
        let carets = line.filter { $0 == caret }.count
        guard carets == 2, let last = line.lastIndex(of: caret) else {
            return false
        }
        return line[line.index(after: last)...].allSatisfy(\.isWhitespace)
    }

    private mutating func keys(before text: Substring) -> (key: String, name: String?) {
        defer { lineAbove = nil }
        let key = text.trimmingCharacters(in: .whitespaces)
        guard key.isEmpty else {
            return (key, nil)
        }
        guard let lineAbove else {
            return (String(position), nil)
        }
        return lineAbove.allSatisfy({ $0.isASCII && $0.isNumber })
            ? (lineAbove, nil)
            : (String(position), lineAbove)
    }

    private mutating func add(_ value: String, key: String, name: String?, line: Int) {
        position += 1
        if entries[key] != nil, !namesFromLinesAbove.contains(key) {
            report("Key '\(key)' appears again, so the first one was kept.", line: line)
        } else {
            namesFromLinesAbove.remove(key)
            entries[key] = value
        }
        if let name, entries[name] == nil {
            entries[name] = value
            namesFromLinesAbove.insert(name)
        }
    }
}

/// Text from a directory of `.cst` tables named `_<id>_<name>.cst`, which is how The Sims Online
/// stores its interface text.
///
/// Every table loads once, during creation, so lookups never touch the disk. Pass `text(for:)`
/// to `UIScriptView`'s `resolveString`, and missing text appears in its `missingStrings`.
public struct CSTCatalog: Sendable {
    private static let referencePrefix = "\u{2}<cst>"

    private let tables: [Int: CSTFile]

    /// The table IDs loaded, in order.
    public var tableIDs: [Int] {
        tables.keys.sorted()
    }

    /// Loads every table in a directory, ignoring files that do not follow the naming pattern.
    ///
    /// - Throws: `CSTError` when the directory or one of its tables cannot be read.
    public init(directory: URL) throws {
        let files: [URL]
        do {
            files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        } catch {
            throw CSTError.unreadable(path: directory.path)
        }
        var tables: [Int: CSTFile] = [:]
        for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard let id = Self.tableID(ofFileNamed: file.lastPathComponent), tables[id] == nil else {
                continue
            }
            guard let data = try? Data(contentsOf: file) else {
                throw CSTError.unreadable(path: file.path)
            }
            tables[id] = CSTFile(data: data)
        }
        self.tables = tables
    }

    /// Loads the text from an install's `gamedata` directory.
    ///
    /// New & Improved keeps its text in `uitext/<language>.dir`. Earlier versions have one
    /// language and keep it in `uitext.dir`, so `language` does not apply to them.
    ///
    /// - Throws: `CSTError` when neither directory exists or a table cannot be read.
    public init(gameData: URL, language: String = "english") throws {
        let candidates = [
            gameData.appendingPathComponent("uitext").appendingPathComponent("\(language).dir"),
            gameData.appendingPathComponent("uitext.dir")
        ]
        guard let directory = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            throw CSTError.noTextDirectory(gameData: gameData.path, language: language)
        }
        try self.init(directory: directory)
    }

    private static func tableID(ofFileNamed name: String) -> Int? {
        let parts = name.split(separator: "_", maxSplits: 1)
        guard name.first == "_", name.lowercased().hasSuffix(".cst"), let first = parts.first else {
            return nil
        }
        return Int(first)
    }

    /// Returns a table, or `nil` when none has this ID.
    public func table(_ id: Int) -> CSTFile? {
        tables[id]
    }

    /// Returns an entry's text, or `nil` when the table or key is missing.
    ///
    /// Some New & Improved entries refer to an entry in another table, and this returns the text
    /// they refer to. `arguments` fill the text's placeholders. See `format(_:with:)`.
    public func text(table: Int, key: String, arguments: [String] = []) -> String? {
        guard let value = tables[table]?.entries[key] else {
            return nil
        }
        guard let target = Self.referenceTarget(in: value) else {
            return Self.format(value, with: arguments)
        }
        return tables[target.table]?.entries[target.key]
            .flatMap { Self.referenceTarget(in: $0) == nil ? Self.format($0, with: arguments) : nil }
    }

    /// Returns the text a document's string resource refers to, or `nil` when it is missing.
    ///
    /// The table ID comes from the end of the resource's table, such as `UIText:174`.
    public func text(for resource: UIScript.StringResource) -> String? {
        guard let id = resource.table.split(separator: ":").last.flatMap({ Int($0) }) else {
            return nil
        }
        return text(table: id, key: String(resource.index))
    }

    /// Reads a reference such as `<cst><cst_id>276</cst_id><string_id>1</string_id></cst>`,
    /// which starts with a control character.
    private static func referenceTarget(in value: String) -> (table: Int, key: String)? {
        guard value.hasPrefix(referencePrefix),
              let table = enclosedText(in: value, tag: "cst_id").flatMap({ Int($0) }),
              let key = enclosedText(in: value, tag: "string_id") else {
            return nil
        }
        return (table, key)
    }

    private static func enclosedText(in value: String, tag: String) -> String? {
        guard let open = value.range(of: "<\(tag)>"),
              let close = value.range(of: "</\(tag)>", range: open.upperBound..<value.endIndex) else {
            return nil
        }
        return String(value[open.upperBound..<close.lowerBound])
    }

    /// Fills a text's `%s`, `%d`, `%i`, and `%u` placeholders with `arguments`, in order.
    ///
    /// Number placeholders follow C's padding rules: `%3d` pads with spaces, and `%03d` and `%.3d`
    /// pad with zeros. `%ld` is the same as `%d`. `%%` becomes one percent sign. A placeholder with no argument left stays as
    /// written, so a mistake is visible, and any other use of `%` is left alone.
    public static func format(_ text: String, with arguments: [String]) -> String {
        var result = ""
        var remaining = arguments[...]
        var rest = Substring(text)
        while let percent = rest.firstIndex(of: "%") {
            result += rest[..<percent]
            rest = rest[percent...]
            guard let placeholder = Placeholder(at: rest) else {
                result.append("%")
                rest = rest.dropFirst()
                continue
            }
            if placeholder.isEscapedPercent {
                result.append("%")
            } else if let argument = remaining.popFirst() {
                result += placeholder.filled(with: argument)
            } else {
                result += rest.prefix(placeholder.length)
            }
            rest = rest.dropFirst(placeholder.length)
        }
        return result + rest
    }

    private struct Placeholder {
        let length: Int
        let isEscapedPercent: Bool
        private var conversion: Character = "%"
        private var width = 0
        private var zeroWidth = 0

        init?(at text: Substring) {
            var scan = text.dropFirst()
            if scan.first == "%" {
                length = 2
                isEscapedPercent = true
                return
            }
            let hasPrecision = scan.first == "."
            if hasPrecision {
                scan = scan.dropFirst()
            }
            let digits = scan.prefix(while: { $0.isASCII && $0.isNumber })
            scan = scan.dropFirst(digits.count)
            let hasLongModifier = scan.first == "l"
            if hasLongModifier {
                scan = scan.dropFirst()
            }
            guard let conversion = scan.first, (hasLongModifier ? "diu" : "sdiu").contains(conversion),
                  !(hasPrecision && digits.isEmpty) else {
                return nil
            }
            self.conversion = conversion
            let number = Int(digits) ?? 0
            if hasPrecision || digits.hasPrefix("0") {
                zeroWidth = number
            } else {
                width = number
            }
            length = 2 + digits.count + (hasPrecision ? 1 : 0) + (hasLongModifier ? 1 : 0)
            isEscapedPercent = false
        }

        func filled(with argument: String) -> String {
            guard conversion != "s" else {
                return argument
            }
            let zeros = String(repeating: "0", count: max(0, zeroWidth - argument.count))
            let spaces = String(repeating: " ", count: max(0, width - argument.count))
            return spaces + zeros + argument
        }
    }
}

/// Errors raised while loading CST tables.
public enum CSTError: Error, LocalizedError, Sendable, Equatable {
    /// A directory or table could not be read.
    case unreadable(path: String)

    /// A `gamedata` directory holds no text this reader knows how to find.
    case noTextDirectory(gameData: String, language: String)

    public var errorDescription: String? {
        switch self {
        case let .unreadable(path):
            "Unable to read CST text at '\(path)'."
        case let .noTextDirectory(gameData, language):
            "'\(gameData)' has neither 'uitext/\(language).dir' nor 'uitext.dir'."
        }
    }
}
