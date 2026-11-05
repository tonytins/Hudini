import Foundation
import Raylib

/// A draggable window frame with a title bar, and an optional close button, toolbar, and title editing.
public final class WindowFrame {
    /// How tall the title bar is.
    public static let titleHeight: Int = 30

    private static let titleSize: Int = 16

    private static let toolbarSize: Int = 14

    private static let problemSize: Int = 10

    private static let toolbarPadding: Int = 10

    private static let toolbarGap: Int = 4

    private static let margin: Int = 8

    private static let closeRadius: Int = 6

    private static let closeHit: Int = 20

    private static let editWidth: Int = 260

    private static let ellipsis: String = "..."

    private let placement = WindowPlacement(titleBarHeight: WindowFrame.titleHeight)

    private let titleField: TextField

    private let theme: InterfaceTheme

    private var _title: String

    // The title as drawn, cut to fit the bar, worked out again only when the title or room changes.
    private var shownTitle: String = ""

    private var shownFor: String? = nil

    private var shownRoom: Float = -1.0

    /// Creates a frame with a title and maximum editable title length.
    public init(
        title: String,
        maximumTitleLength: Int = 80,
        theme: InterfaceTheme = .standard
    ) {
        precondition(maximumTitleLength > 0, "maximumTitleLength must be positive")
        _title = title
        self.theme = theme
        titleField = TextField(
            text: title,
            maximumLength: maximumTitleLength,
            fontSize: WindowFrame.titleSize,
            theme: theme
        )
    }

    /// Something the frame's input asks the host to act on.
    public enum Action: Equatable, Sendable {
        /// The close button was clicked.
        case close
        /// The toolbar item at this index was clicked.
        case toolbarItemSelected(Int)
        /// A new title was entered.
        case renamed
    }

    /// The window's title.
    public var title: String {
        get {
            _title
        }
        set {
            _title = newValue
            if !isEditingTitle {
                titleField.text = _title
            }
        }
    }

    /// Whether the frame has a close button. Without one, the frame reports no `.close`, and the
    /// title and the drag area take the button's room.
    public var showsCloseButton: Bool = true

    /// Whether the user can edit the title in place.
    public var allowsTitleEditing: Bool = false

    /// Returns a validation message for an invalid edited title, or `nil` when it is valid.
    public var validateTitle: ((String) -> String?)?

    /// Whether the user is editing the title. While editing, the keyboard is reserved for it.
    public private(set) var isEditingTitle: Bool = false

    /// The validation message shown after the user submits an invalid title.
    public private(set) var titleValidationMessage: String?

    /// The toolbar's items, ordered from left to right.
    public var toolbarItems: [String] = []

    /// The selected toolbar item, or `nil` when no item is selected.
    public var selectedToolbarIndex: Int?

    /// Whether the user is dragging the window.
    public var isDragging: Bool {
        placement.isDragging
    }

    /// The area under the title bar, where the window draws its own content.
    public static func content(in bounds: Rectangle) -> Rectangle {
        var contentBounds = bounds
        contentBounds.y += Float(titleHeight)
        contentBounds.height = max(0.0, bounds.height - Float(titleHeight))
        return contentBounds
    }

    /// Returns bounds at the saved position or `start`, constrained to the screen.
    public func place(size: Vector2, at start: Vector2) -> Rectangle {
        placement.bounds(size: size, initialOrigin: start)
    }

    /// Starts a drag on the title bar or selected toolbar item, but not on the close button,
    /// an unselected toolbar item, or an editable title.
    public func beginDragging(at point: Vector2, within bounds: Rectangle) -> Bool {
        let toolbarIndex = toolAt(point, bounds)
        if isCloseButton(at: point, in: bounds)
            || (toolbarIndex >= 0 && selectedToolbarIndex != toolbarIndex)
            || (allowsTitleEditing && CheckCollisionPointRec(point, titleBounds(bounds))) {
            return false
        }
        return placement.beginDragging(at: point, within: bounds)
    }

    /// Moves the window with the pointer while the button is held, and lets it go when it isn't.
    public func drag(to point: Vector2, isHeld: Bool, windowSize: Vector2) {
        placement.drag(to: point, isHeld: isHeld, windowSize: windowSize)
    }

    /// For a window nothing else drags: starts a drag on a press on the bar, and moves the window
    /// while the button is held. Returns whether the window is being dragged.
    public func followPointer(in bounds: Rectangle) -> Bool {
        let mouse = GetMousePosition()
        if !isDragging, IsMouseButtonPressed(MouseButton.left) {
            _ = beginDragging(at: mouse, within: bounds)
        }
        if isDragging {
            drag(
                to: mouse,
                isHeld: IsMouseButtonDown(MouseButton.left),
                windowSize: Vector2(x: bounds.width, y: bounds.height)
            )
        }
        return isDragging
    }

    /// Returns whether `point` is on the close button. This is always false when the frame has none.
    public func isCloseButton(at point: Vector2, in bounds: Rectangle) -> Bool {
        showsCloseButton && CheckCollisionPointRec(point, Self.closeBounds(bounds))
    }

    /// Drops an edit of the title, as closing the window does.
    public func cancelEdit() {
        isEditingTitle = false
        titleField.setFocused(false)
        titleValidationMessage = nil
        titleField.text = _title
    }

    /// Takes this frame's clicks on the bar, and the typing while the title is edited, and returns
    /// anything the host should act on. Call it before the window's own input: while
    /// `isEditingTitle` was true at the start of the frame, the keyboard was the title's, and the
    /// window should leave Enter and Escape alone.
    ///
    /// Escape cancels a title edit. raylib also closes the window on Escape by default, so call
    /// `SetExitKey(.null)` after `InitWindow` when titles are editable.
    public func update(in bounds: Rectangle) -> WindowFrame.Action? {
        let mouse = GetMousePosition()
        let pressed = IsMouseButtonPressed(MouseButton.left)
        if isEditingTitle {
            return updateEdit(bounds, mouse, pressed)
        }
        if !pressed {
            return nil
        }
        if isCloseButton(at: mouse, in: bounds) {
            return .close
        }
        let tool = toolAt(mouse, bounds)
        if tool >= 0 {
            return selectedToolbarIndex == tool ? nil : .toolbarItemSelected(tool)
        }
        if allowsTitleEditing, CheckCollisionPointRec(mouse, titleBounds(bounds)) {
            titleField.text = _title
            titleField.setFocused(true)
            titleValidationMessage = nil
            isEditingTitle = true
        }
        return nil
    }

    /// Draws the window's background, border, and title bar. The host draws the window's content
    /// over the area `content(in:)` returns.
    public func draw(in bounds: Rectangle) {
        let mouse = GetMousePosition()
        DrawRectangleRec(bounds, theme.panel)
        var bar = bounds
        bar.height = Float(WindowFrame.titleHeight)
        DrawRectangleRec(bar, theme.titleBar)
        DrawLine(Int(clamping: bounds.x), Int(clamping: bounds.y + Float(WindowFrame.titleHeight)), Int(clamping: bounds.x + bounds.width), Int(clamping: bounds.y + Float(WindowFrame.titleHeight)), theme.border)
        DrawRectangleLinesEx(bounds, 1.0, theme.border)
        if showsCloseButton {
            drawCloseButton(in: bounds, mouse: mouse)
        }
        for i in 0..<toolbarItems.count {
            let item = toolBounds(bounds, i)
            if selectedToolbarIndex == i {
                DrawRectangleRec(item, theme.selectedItem)
            }
            let color = selectedToolbarIndex == i ? theme.accent : CheckCollisionPointRec(mouse, item) ? theme.text : theme.secondaryText
            theme.drawText(toolbarItems[i], x: Int(clamping: item.x) + WindowFrame.toolbarPadding, y: Int(clamping: item.y + ((item.height - Float(WindowFrame.toolbarSize)) / 2)), size: WindowFrame.toolbarSize, color: color)
        }
        let title = titleBounds(bounds)
        if isEditingTitle {
            titleField.draw(in: title)
            if let titleValidationMessage {
                theme.drawText(titleValidationMessage, x: Int(clamping: title.x), y: Int(clamping: bounds.y + Float(WindowFrame.titleHeight) + 2), size: WindowFrame.problemSize, color: theme.error)
            }
            return
        }
        let shown = shown(title.width)
        let width = theme.textWidth(of: shown, size: WindowFrame.titleSize)
        let titleColor = allowsTitleEditing && CheckCollisionPointRec(mouse, title) ? theme.accent : theme.text
        theme.drawText(shown, x: Int(clamping: title.x + ((title.width - Float(width)) / 2)), y: Int(clamping: bounds.y + Float((WindowFrame.titleHeight - WindowFrame.titleSize) / 2)), size: WindowFrame.titleSize, color: titleColor)
    }

    // A red dot, marked with an x while the pointer is over it, as macOS has it.
    private func drawCloseButton(in bounds: Rectangle, mouse: Vector2) {
        let close = WindowFrame.closeBounds(bounds)
        let (centerX, centerY) = (Int(clamping: close.x + Float(WindowFrame.closeHit / 2)), Int(clamping: close.y + Float(WindowFrame.closeHit / 2)))
        DrawCircle(centerX, centerY, Float(WindowFrame.closeRadius), theme.closeButton)
        if CheckCollisionPointRec(mouse, close) {
            DrawLine(centerX - 3, centerY - 3, centerX + 3, centerY + 3, theme.closeMark)
            DrawLine(centerX - 3, centerY + 3, centerX + 3, centerY - 3, theme.closeMark)
        }
    }

    private func updateEdit(_ bounds: Rectangle, _ mouse: Vector2, _ pressed: Bool) -> WindowFrame.Action? {
        if IsKeyPressed(KeyboardKey.escape) || (pressed && !CheckCollisionPointRec(mouse, titleBounds(bounds))) {
            cancelEdit()
            return nil
        }
        if titleField.takeTyping() {
            titleValidationMessage = nil
        }
        if !IsKeyPressed(KeyboardKey.enter), !IsKeyPressed(KeyboardKey.kpEnter) {
            return nil
        }
        let edited = titleField.text.trimmingCharacters(in: .whitespacesAndNewlines)
        titleValidationMessage = validateTitle?(edited)
        if titleValidationMessage != nil {
            return nil
        }
        _title = edited
        isEditingTitle = false
        titleField.setFocused(false)
        return .renamed
    }

    // The title as it fits the room, cut with an ellipsis when it doesn't; kept until either changes.
    private func shown(_ room: Float) -> String {
        if shownFor == _title, shownRoom == room {
            return shownTitle
        }
        (shownFor, shownRoom) = (_title, room)
        shownTitle = _title
        if Float(theme.textWidth(of: _title, size: WindowFrame.titleSize)) > room {
            var length = _title.count
            while length > 0 && Float(theme.textWidth(of: String(_title.prefix(length)) + WindowFrame.ellipsis, size: WindowFrame.titleSize)) > room {
                length -= 1
            }
            shownTitle = String(_title.prefix(length)) + WindowFrame.ellipsis
        }
        return shownTitle
    }

    private static func closeBounds(_ bounds: Rectangle) -> Rectangle {
        Rectangle(x: bounds.x + Float(margin) - 2, y: bounds.y + Float((titleHeight - closeHit) / 2), width: Float(closeHit), height: Float(closeHit))
    }

    // The title sits between the close button, if any, and the toolbar: centred in the window when
    // it fits there, as macOS has it, and otherwise in all the room between them.
    func titleBounds(_ bounds: Rectangle) -> Rectangle {
        let closeRoom = showsCloseButton ? Float(WindowFrame.closeHit) + Float(WindowFrame.margin) : 0.0
        let left = bounds.x + Float(WindowFrame.margin) + closeRoom
        let right = toolbarItems.count > 0 ? toolBounds(bounds, 0).x - Float(WindowFrame.margin) : bounds.x + bounds.width - Float(WindowFrame.margin)
        let between = max(0.0, right - left)
        let side = max(left - bounds.x, bounds.x + bounds.width - right)
        let centred = max(0.0, bounds.width - (side * 2))
        let wanted = isEditingTitle ? WindowFrame.editWidth : theme.textWidth(of: _title, size: WindowFrame.titleSize)
        let (x, room) = centred >= Float(wanted) ? (bounds.x + ((bounds.width - centred) / 2), centred) : (left, between)
        return Rectangle(x: x, y: bounds.y + 3, width: room, height: Float(WindowFrame.titleHeight - 6))
    }

    private func toolAt(_ point: Vector2, _ bounds: Rectangle) -> Int {
        for i in 0..<toolbarItems.count {
            if CheckCollisionPointRec(point, toolBounds(bounds, i)) {
                return i
            }
        }
        return -1
    }

    // The items run leftward from the bar's right end, the last first, as the button row does.
    private func toolBounds(_ bounds: Rectangle, _ index: Int) -> Rectangle {
        var right = bounds.x + bounds.width - Float(WindowFrame.margin)
        for i in stride(from: toolbarItems.count - 1, through: 0, by: -1) {
            let width = theme.textWidth(of: toolbarItems[i], size: WindowFrame.toolbarSize) + (WindowFrame.toolbarPadding * 2)
            if i == index {
                return Rectangle(x: right - Float(width), y: bounds.y + 4, width: Float(width), height: Float(WindowFrame.titleHeight - 8))
            }
            right -= Float(width + WindowFrame.toolbarGap)
        }
        return Rectangle()
    }
}
