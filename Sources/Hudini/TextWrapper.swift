import Foundation
import Raylib

/// Wraps text into lines that fit a measured pixel width.
public enum TextWrapper {
    /// Returns lines measured with raylib's default font at the given size.
    public static func lines(for text: String, fontSize: Int, maximumWidth: Int) -> [String] {
        var lines: [String] = []
        var line = ""
        for word in text.split(whereSeparator: \.isWhitespace).map(String.init) {
            let longer = line.isEmpty ? word : "\(line) \(word)"
            if !line.isEmpty, MeasureText(longer, fontSize) > maximumWidth {
                lines.append(line)
                line = word
            } else {
                line = longer
            }
        }
        if !line.isEmpty {
            lines.append(line)
        }
        return lines
    }
}
