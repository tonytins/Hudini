import Raylib

/// Lays out and draws a bottom-left row of icon buttons.
public enum IconToolbar {
    private static let buttonSize: Float = 42
    private static let buttonGap: Float = 4
    private static let padding: Float = 6
    private static let barHeight = buttonSize + (padding * 2)

    /// Returns the toolbar's bounds inside an area for the given item count.
    public static func bounds(
        itemCount: Int,
        in area: Rectangle,
        inset: Float = 12
    ) -> Rectangle {
        precondition(itemCount >= 0, "itemCount must not be negative")
        precondition(inset >= 0, "inset must not be negative")
        guard itemCount > 0 else {
            return Rectangle()
        }

        let width = (Float(itemCount) * buttonSize)
            + (Float(itemCount - 1) * buttonGap)
            + (padding * 2)
        return Rectangle(
            x: area.x + inset,
            y: area.y + area.height - inset - barHeight,
            width: width,
            height: barHeight
        )
    }

    /// Returns a button's bounds, or `nil` when `index` is outside the toolbar.
    public static func buttonBounds(
        at index: Int,
        itemCount: Int,
        in area: Rectangle,
        inset: Float = 12
    ) -> Rectangle? {
        let toolbar = bounds(itemCount: itemCount, in: area, inset: inset)
        return bounds(ofButtonAt: index, itemCount: itemCount, in: toolbar)
    }

    private static func bounds(
        ofButtonAt index: Int,
        itemCount: Int,
        in toolbar: Rectangle
    ) -> Rectangle? {
        guard index >= 0, index < itemCount else {
            return nil
        }
        return Rectangle(
            x: toolbar.x + padding + (Float(index) * (buttonSize + buttonGap)),
            y: toolbar.y + padding,
            width: buttonSize,
            height: buttonSize
        )
    }

    /// Returns the index of the button containing `point`, or `nil` when none does.
    public static func buttonIndex(
        at point: Vector2,
        itemCount: Int,
        in area: Rectangle,
        inset: Float = 12
    ) -> Int? {
        let toolbar = bounds(itemCount: itemCount, in: area, inset: inset)
        for index in 0..<itemCount {
            guard let button = bounds(
                ofButtonAt: index,
                itemCount: itemCount,
                in: toolbar
            ) else {
                continue
            }
            if CheckCollisionPointRec(point, button) {
                return index
            }
        }
        return nil
    }

    /// Draws the toolbar and each icon. The host game provides icons and owns selection state.
    ///
    /// Set `showsBackground` to `false` when placing the buttons on a shared HUD surface.
    public static func draw(
        itemCount: Int,
        selectedIndex: Int?,
        mousePosition: Vector2,
        in area: Rectangle,
        inset: Float = 12,
        theme: InterfaceTheme = .standard,
        showsBackground: Bool = true,
        drawIcon: (Int, Rectangle, Color) -> Void
    ) {
        let toolbar = bounds(itemCount: itemCount, in: area, inset: inset)
        guard itemCount > 0 else {
            return
        }
        if showsBackground {
            DrawRectangleRec(toolbar, theme.panel)
            DrawRectangleLinesEx(toolbar, 1, theme.border)
        }

        for index in 0..<itemCount {
            guard let button = bounds(
                ofButtonAt: index,
                itemCount: itemCount,
                in: toolbar
            ) else {
                continue
            }
            let isSelected = selectedIndex == index
            let isHovered = CheckCollisionPointRec(mousePosition, button)
            if isSelected || isHovered {
                DrawRectangleRec(button, isSelected ? theme.selectedItem : theme.border)
            }
            let iconColor = isSelected || isHovered ? theme.accent : theme.text
            drawIcon(index, button, iconColor)
        }
    }
}
