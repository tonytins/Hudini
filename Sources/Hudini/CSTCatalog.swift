import Foundation
import SwiftCST

// These types now wrap SwiftCST, which holds the CST reader and specification. They stay so games
// can move over gradually, and will be removed in a later release.

/// One `.cst` string table: keys and the text they hold, written as `key ^text^` or just
/// `^text^`, which is known by its position from 0.
///
/// Reading never fails, because a table with one bad entry is still useful. Anything skipped
/// lands in `problems`.
@available(*, deprecated, message: "Use SwiftCST's CSTTable, which this wraps.")
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
    /// when there is one, so a value can appear under two keys. A key written in the file wins
    /// over both.
    public let entries: [String: String]

    /// What could not be read.
    public let problems: [Problem]

    /// Reads a table. Real files are UTF-8, with or without a byte order mark, or Windows-1252.
    public init(data: Data) {
        self.init(table: CSTTable(Self.decoded(data)))
    }

    init(table: CSTTable) {
        var entries: [String: String] = [:]
        func add(_ key: String?, _ value: String?) {
            if let key, let value, entries[key] == nil {
                entries[key] = value
            }
        }
        // The order UIText looks values up in: written keys, then names, then positions.
        for entry in table.entries {
            add(entry.key, entry.value)
        }
        for entry in table.entries {
            add(entry.name, entry.value)
        }
        for (position, entry) in table.entries.enumerated() where entry.key == nil {
            add(String(position), entry.value)
        }
        self.entries = entries
        problems = table.problems.map { problem in
            switch problem {
            case let .unclosedValue(line):
                Problem(line: line, message: "This value has no closing caret, so it was skipped.")
            case let .repeatedKey(key, line):
                Problem(line: line, message: "Key '\(key)' appears again, so the first one was kept.")
            }
        }
    }

    private static func decoded(_ data: Data) -> String {
        String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .windowsCP1252)
            ?? String(decoding: data, as: UTF8.self)
    }
}

/// Text from a directory of `.cst` tables named `_<id>_<name>.cst`, which is how The Sims Online
/// stores its interface text.
///
/// Every table loads once, during creation, so lookups never touch the disk. Pass `text(for:)`
/// to `UIScriptView`'s `resolveString`, and missing text appears in its `missingStrings`.
///
/// To move to SwiftCST, create a `UIText` with `init(gameData:language:)` or `init(directory:)`,
/// and use `textIfPresent` where this used `text`. It returns `nil` for missing text in the same
/// way, and finds the same text.
@available(
    *, deprecated,
    message: "Use SwiftCST's UIText, with textIfPresent(for:key:) for lookups that report missing text as nil."
)
public struct CSTCatalog: Sendable {
    private let text: UIText

    private let tables: [Int: CSTFile]

    /// The table IDs loaded, in order.
    public let tableIDs: [Int]

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
        // UIText reads the first file in name order for each ID, as this did.
        var paths: [Int: String] = [:]
        for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            if let id = Self.tableID(ofFileNamed: file.lastPathComponent), paths[id] == nil {
                paths[id] = file.path
            }
        }
        let text = UIText(directory: directory)
        var tables: [Int: CSTFile] = [:]
        for (id, path) in paths {
            // Reading each table now also keeps it in UIText, so later lookups don't touch the disk.
            guard let table = try? text.table(for: id) else {
                throw CSTError.unreadable(path: path)
            }
            tables[id] = CSTFile(table: table)
        }
        self.text = text
        self.tables = tables
        tableIDs = tables.keys.sorted()
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

    // The same names UIText accepts: `_<id>_<name>.cst`, in any case.
    private static func tableID(ofFileNamed name: String) -> Int? {
        let url = URL(fileURLWithPath: name)
        let stem = url.deletingPathExtension().lastPathComponent
        guard url.pathExtension.lowercased() == "cst", stem.first == "_",
              let end = stem.dropFirst().firstIndex(of: "_") else {
            return nil
        }
        return Int(stem[stem.index(after: stem.startIndex)..<end])
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
        // A table that wasn't loaded is missing, and checking here keeps UIText off the disk.
        guard tables[table] != nil else {
            return nil
        }
        return try? text.textIfPresent(for: table, key: key, with: arguments)
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

    /// Fills a text's `%s`, `%d`, `%i`, and `%u` placeholders with `arguments`, in order.
    ///
    /// Number placeholders follow C's padding rules: `%3d` pads with spaces, and `%03d` and `%.3d`
    /// pad with zeros. `%ld` is the same as `%d`. `%%` becomes one percent sign. A placeholder with
    /// no argument left stays as written, so a mistake is visible, and any other use of `%` is left
    /// alone.
    public static func format(_ text: String, with arguments: [String]) -> String {
        CST.format(text, with: arguments)
    }
}

/// Errors raised while loading CST tables.
@available(*, deprecated, message: "Only CSTCatalog raises these. SwiftCST's UIText throws the file system's own errors.")
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
