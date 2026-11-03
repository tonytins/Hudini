import Foundation
import Raylib

/// Wraps text into lines that fit a measured pixel width.
public enum TextWrapper {
    /// Returns lines measured with raylib's default font at the given size.
    public static func lines(for text: String, fontSize: Int, maximumWidth: Int) -> [String] {
        lines(for: text, maximumWidth: maximumWidth) { MeasureText($0, fontSize) }
    }

    /// Returns lines that fit `maximumWidth` according to `width`.
    ///
    /// Lines break between words. A word too wide for a whole line breaks between
    /// its characters. A single character always takes a line, even if it does
    /// not fit.
    public static func lines(
        for text: String,
        maximumWidth: Int,
        measuredBy width: (String) -> Int
    ) -> [String] {
        var lines: [String] = []
        var line = ""
        for word in text.split(whereSeparator: \.isWhitespace).map(String.init) {
            let longer = line.isEmpty ? word : "\(line) \(word)"
            if width(longer) <= maximumWidth {
                line = longer
                continue
            }
            if !line.isEmpty {
                lines.append(line)
            }
            var remaining = Substring(word)
            while remaining.count > 1, width(String(remaining)) > maximumWidth {
                let fitting = fittingPrefixLength(of: remaining, maximumWidth: maximumWidth, width)
                lines.append(String(remaining.prefix(fitting)))
                remaining = remaining.dropFirst(fitting)
            }
            line = String(remaining)
        }
        if !line.isEmpty {
            lines.append(line)
        }
        return lines
    }

    private static func fittingPrefixLength(
        of text: Substring,
        maximumWidth: Int,
        _ width: (String) -> Int
    ) -> Int {
        var length = text.count - 1
        while length > 1, width(String(text.prefix(length))) > maximumWidth {
            length -= 1
        }
        return length
    }
}
