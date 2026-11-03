import Foundation
import Raylib

/// Draws and hit-tests a row of buttons aligned to a bottom-right corner.
public enum ButtonRow {
    private static let fontSize: Int = 20

    private static let height: Int = 30

    private static let labelPadding: Int = 14

    private static let gap: Int = 10

    /// How tall the row is.
    public static let rowHeight: Int = height

    /// Returns the index of the enabled button containing `point`, or `nil` if there is none.
    /// Missing enabled flags leave buttons enabled.
    public static func buttonIndex(
        at point: Vector2,
        endingAt corner: Vector2,
        labels: [String],
        enabled: [Bool]? = nil
    ) -> Int? {
        for index in labels.indices where isEnabled(index, enabled) {
            if CheckCollisionPointRec(point, bounds(endingAt: corner, labels: labels, index: index)) {
                return index
            }
        }
        return nil
    }

    /// Draws the row. Disabled buttons are dimmed; missing enabled flags leave buttons enabled.
    public static func draw(
        labels: [String],
        endingAt corner: Vector2,
        mousePosition: Vector2,
        enabled: [Bool]? = nil,
        theme: InterfaceTheme = .standard
    ) {
        for index in labels.indices {
            let buttonBounds = bounds(endingAt: corner, labels: labels, index: index)
            DrawRectangleRec(buttonBounds, theme.border)
            let color = !isEnabled(index, enabled)
                ? theme.secondaryText
                : CheckCollisionPointRec(mousePosition, buttonBounds) ? theme.accent : theme.text
            DrawText(labels[index], Int(clamping: buttonBounds.x) + labelPadding, Int(clamping: buttonBounds.y) + 5, fontSize, color)
        }
    }

    private static func isEnabled(_ index: Int, _ enabled: [Bool]?) -> Bool {
        guard let enabled, enabled.indices.contains(index) else {
            return true
        }
        return enabled[index]
    }

    private static func bounds(endingAt corner: Vector2, labels: [String], index: Int) -> Rectangle {
        var right = corner.x
        for i in stride(from: labels.count - 1, through: 0, by: -1) {
            let width = MeasureText(labels[i], fontSize) + (labelPadding * 2)
            if i == index {
                return Rectangle(x: right - Float(width), y: corner.y - Float(height), width: Float(width), height: Float(height))
            }
            right -= Float(width + gap)
        }
        return Rectangle()
    }
}
