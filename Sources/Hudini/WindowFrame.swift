import Foundation
import Raylib

/// A draggable window frame with a title bar, and an optional close button, minimize button,
/// toolbar, and title editing.
///
/// A frame works in one of two ways:
///
/// - **Around a `UIScriptView`**, made with `init(view:title:maximumTitleLength:)`. The frame
///   drives the view: `updateWindow(in:)` handles the bar and the view and returns one list of
///   events, and `draw(in:)` draws both. The document describes the bar's toolbar items and
///   editable title, which the host reaches by name as it does the view's controls.
/// - **Around the host's own content**, made with `init(title:maximumTitleLength:theme:)`. The host
///   sets `toolbarItems` and `allowsTitleEditing`, handles `update(in:)`'s actions, and draws its
///   content over `content(in:)`.
///
/// Either way, close and minimize are requests: the frame never hides itself, and the host
/// decides what happens.
public final class WindowFrame {
    /// How tall the title bar is.
    public static let titleHeight: Int = 30

    private static let toolbarPadding: Int = 10

    private static let toolbarGap: Int = 4

    private static let margin: Int = 8

    private static let buttonRadius: Int = 6

    private static let buttonHit: Int = 20

    private static let editWidth: Int = 260

    private static let ellipsis: String = "..."

    private let placement = WindowPlacement(titleBarHeight: WindowFrame.titleHeight)

    private let titleField: TextField

    /// The view the frame wraps, or `nil` for a frame around the host's own content.
    public let view: UIScriptView?

    /// The look the frame draws with, including its title field. Setting it takes effect from the
    /// next draw, and keeps the window's position, title, and toolbar selection. A frame around a
    /// view passes the theme on to the view, so the window keeps one look.
    public var theme: InterfaceTheme {
        didSet {
            titleField.theme = theme
            view?.theme = theme
            shownFor = nil
        }
    }

    private var _title: String

    // The title as drawn, cut to fit the bar, worked out again only when the title or room changes.
    private var shownTitle: String = ""

    private var shownFor: String? = nil

    private var shownRoom: Float = -1.0

    // The document title field's text when its edit began, which a cancelled edit puts back.
    private var savedTitle: String = ""

    /// Creates a frame around the host's own content, with a title and maximum editable title
    /// length.
    public convenience init(
        title: String,
        maximumTitleLength: Int = 80,
        theme: InterfaceTheme = .standard
    ) {
        self.init(title: title, maximumTitleLength: maximumTitleLength, theme: theme, view: nil)
    }

    /// Creates a frame around `view`, in the view's theme.
    ///
    /// The document's `<ToolbarItem>`s go on the bar, and its `<TitleField>`, if any, makes the
    /// title editable, with `maximumTitleLength` characters at most. Without a title field, the bar
    /// shows `title`, which only the host changes. `allowsTitleEditing` and `toolbarItems` don't
    /// apply to a frame around a view.
    public convenience init(view: UIScriptView, title: String = "", maximumTitleLength: Int = 256) {
        self.init(title: title, maximumTitleLength: maximumTitleLength, theme: view.theme, view: view)
    }

    private init(title: String, maximumTitleLength: Int, theme: InterfaceTheme, view: UIScriptView?) {
        precondition(maximumTitleLength > 0, "maximumTitleLength must be positive")
        _title = title
        self.theme = theme
        self.view = view
        titleField = TextField(
            text: title,
            maximumLength: maximumTitleLength,
            fontSize: nil,
            themeSize: \.title,
            theme: theme
        )
    }

    /// Something the input of a frame around the host's own content asks the host to act on.
    public enum Action: Equatable, Sendable {
        /// The close button was clicked.
        case close
        /// The toolbar item at this index was clicked.
        case toolbarItemSelected(Int)
        /// A new title was entered.
        case renamed
    }

    /// Something a frame around a view reports.
    public enum Event: Equatable, Sendable {
        /// The view, its toolbar items, or its title field reported this. A toolbar item reports
        /// `.pressed` with its name, and a submitted title `.submitted` with the title field's name.
        case view(UIScriptView.Event)
        /// The close button was clicked. The host decides what closing means.
        case closeRequested
        /// The minimize button was clicked. The host decides where a minimized window goes.
        case minimizeRequested
    }

    /// The window's title. A frame around a view with a `<TitleField>` shows the field's text
    /// instead, which the host reaches through the view by name.
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

    /// Whether the frame has a close button. Without one, the frame reports no `.close` or
    /// `.closeRequested`, and the title and the drag area take the button's room.
    public var showsCloseButton: Bool = true

    /// Whether the frame has a minimize button, beside the close button. It's off by default,
    /// since a game needs somewhere for minimized windows to go. Only a frame around a view reports
    /// it, as `.minimizeRequested`.
    public var showsMinimizeButton: Bool = false

    /// Whether the user can edit the title in place, for a frame around the host's own content.
    public var allowsTitleEditing: Bool = false

    /// Returns a validation message for an invalid edited title, or `nil` when it is valid.
    public var validateTitle: ((String) -> String?)?

    /// Whether the user is editing the title. While editing, the keyboard is reserved for it.
    public private(set) var isEditingTitle: Bool = false

    /// The validation message shown after the user submits an invalid title.
    public private(set) var titleValidationMessage: String?

    /// The toolbar's items, ordered from left to right, for a frame around the host's own content.
    public var toolbarItems: [String] = []

    /// The selected toolbar item, or `nil` when no item is selected, for a frame around the host's
    /// own content. A frame around a view shows the items its view has selected.
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

    /// Returns bounds that fit the view and the title bar, at the saved position or `start`,
    /// constrained to the screen. A frame around the host's own content has no size of its own, so
    /// use `place(size:at:)` for one.
    public func place(at start: Vector2) -> Rectangle {
        let size = view?.windowSize ?? .zero
        return place(size: Vector2(x: size.x, y: size.y + Float(Self.titleHeight)), at: start)
    }

    // MARK: Toolbar items and title

    // The items' titles, from the document for a frame around a view.
    private var itemTitles: [String] {
        view.map { $0.script.toolbarItems.map(\.title) } ?? toolbarItems
    }

    private func isItemSelected(_ index: Int) -> Bool {
        guard let view else {
            return selectedToolbarIndex == index
        }
        return view.isSelected(named: view.script.toolbarItems[index].name)
    }

    private func isItemDisabled(_ index: Int) -> Bool {
        guard let view else {
            return false
        }
        return view.isDisabled(named: view.script.toolbarItems[index].name)
    }

    // The document's title field, when it can be edited now.
    private var editableField: UIScript.TitleField? {
        guard let view, let field = view.script.titleField, !view.isDisabled(named: field.name) else {
            return nil
        }
        return field
    }

    private var isTitleEditable: Bool {
        view == nil ? allowsTitleEditing : editableField != nil
    }

    // What the bar shows as the title, and whether that's the field's placeholder.
    private var displayedTitle: (text: String, isPlaceholder: Bool) {
        guard let view, let field = view.script.titleField else {
            return (_title, false)
        }
        let text = view.text(named: field.name) ?? ""
        if text.isEmpty, let placeholder = field.placeholder {
            return (placeholder, true)
        }
        return (text, false)
    }

    // MARK: Input

    /// Starts a drag on the title bar or selected toolbar item, but not on the close or minimize
    /// button, an unselected toolbar item, or an editable title. A frame around a view drags from
    /// none of its toolbar items, since each one reports a click.
    public func beginDragging(at point: Vector2, within bounds: Rectangle) -> Bool {
        let toolbarIndex = toolAt(point, bounds)
        if isCloseButton(at: point, in: bounds)
            || isMinimizeButton(at: point, in: bounds)
            || (toolbarIndex >= 0 && (view != nil || selectedToolbarIndex != toolbarIndex))
            || (isTitleEditable && CheckCollisionPointRec(point, titleBounds(bounds))) {
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
        showsCloseButton && CheckCollisionPointRec(point, buttonBounds(bounds, slot: 0))
    }

    /// Returns whether `point` is on the minimize button. This is always false when the frame has
    /// none.
    public func isMinimizeButton(at point: Vector2, in bounds: Rectangle) -> Bool {
        showsMinimizeButton && CheckCollisionPointRec(point, buttonBounds(bounds, slot: showsCloseButton ? 1 : 0))
    }

    /// Drops an edit of the title, as closing the window does. A frame around a view puts its title
    /// field's text back as it was.
    public func cancelEdit() {
        if isEditingTitle, let view, let field = view.script.titleField {
            view.setText(savedTitle, named: field.name)
        }
        isEditingTitle = false
        titleField.setFocused(false)
        titleValidationMessage = nil
        titleField.text = _title
    }

    /// Takes this frame's clicks on the bar, and the typing while the title is edited, and returns
    /// anything the host should act on. This is for a frame around the host's own content; a frame
    /// around a view uses `updateWindow(in:)`.
    ///
    /// Call it before the window's own input: while `isEditingTitle` was true at the start of the
    /// frame, the keyboard was the title's, and the window should leave Enter and Escape alone.
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

    /// Handles this frame's input for the whole window, for a frame made with a view: dragging,
    /// the bar's buttons, toolbar items, and title field, then the view in the content area.
    ///
    /// While the title is being edited, the keyboard is the title's. A click on one of the window's
    /// toolbar items keeps the edit, so an item such as Go can act on what was typed, which the
    /// view's `text(named:)` returns. Escape or a click anywhere else puts the old text back. raylib
    /// also closes the window on Escape by default, so call `SetExitKey(.null)` after `InitWindow`.
    public func updateWindow(in bounds: Rectangle) -> [Event] {
        guard let view else {
            preconditionFailure("updateWindow(in:) needs a frame made with init(view:)")
        }
        _ = followPointer(in: bounds)
        var events: [Event] = []
        if IsMouseButtonPressed(MouseButton.left) {
            events += press(at: GetMousePosition(), in: bounds)
        }
        if isEditingTitle {
            events += takeTitleTyping()
        }
        let content = Self.content(in: bounds)
        events += view.update(at: Vector2(x: content.x, y: content.y)).map(Event.view)
        return events
    }

    /// Applies a press at `point` to the bar of a frame around a view.
    func press(at point: Vector2, in bounds: Rectangle) -> [Event] {
        if isMinimizeButton(at: point, in: bounds) {
            cancelEdit()
            return [.minimizeRequested]
        }
        if isCloseButton(at: point, in: bounds) {
            cancelEdit()
            return [.closeRequested]
        }
        let tool = toolAt(point, bounds)
        if tool >= 0, let view {
            // The edit stays, so the item can act on what was typed.
            return isItemDisabled(tool) ? [] : [.view(.pressed(control: view.script.toolbarItems[tool].name))]
        }
        if let field = editableField, CheckCollisionPointRec(point, titleBounds(bounds)) {
            if !isEditingTitle {
                beginTitleEdit(field)
            }
            return []
        }
        cancelEdit()
        return []
    }

    private func beginTitleEdit(_ field: UIScript.TitleField) {
        guard let view else {
            return
        }
        view.clearFocus()
        savedTitle = view.text(named: field.name) ?? ""
        titleField.text = savedTitle
        titleField.setFocused(true)
        titleValidationMessage = nil
        isEditingTitle = true
    }

    private func takeTitleTyping() -> [Event] {
        if IsKeyPressed(KeyboardKey.escape) {
            cancelEdit()
            return []
        }
        if titleField.takeTyping() {
            titleValidationMessage = nil
            if let view, let field = view.script.titleField {
                view.setText(titleField.text, named: field.name)
            }
        }
        guard IsKeyPressed(KeyboardKey.enter) || IsKeyPressed(KeyboardKey.kpEnter) else {
            return []
        }
        return submitTitleEdit()
    }

    /// Ends a title field's edit with what was typed, unless `validateTitle` refuses it, and
    /// reports it as the view's `.submitted` under the field's name.
    func submitTitleEdit() -> [Event] {
        guard isEditingTitle, let view, let field = view.script.titleField else {
            return []
        }
        let edited = titleField.text.trimmingCharacters(in: .whitespacesAndNewlines)
        titleValidationMessage = validateTitle?(edited)
        if titleValidationMessage != nil {
            return []
        }
        isEditingTitle = false
        titleField.setFocused(false)
        view.setText(edited, named: field.name)
        return [.view(.submitted(control: field.name, text: edited))]
    }

    /// Replaces what a title edit holds, as typing does, for tests that have no keyboard.
    func typeTitle(_ text: String) {
        titleField.text = text
        if let view, let field = view.script.titleField {
            view.setText(text, named: field.name)
        }
    }

    // MARK: Drawing

    /// Draws the window's background, border, and title bar, and for a frame around a view, the
    /// view in the content area. A frame around the host's own content leaves the host to draw
    /// over the area `content(in:)` returns.
    public func draw(in bounds: Rectangle) {
        drawBar(in: bounds)
        if let view {
            let content = Self.content(in: bounds)
            view.draw(at: Vector2(x: content.x, y: content.y))
        }
    }

    /// Draws the tooltip of the view's control the pointer rests on, for a frame around a view.
    /// Call this after drawing every window, so nothing covers it.
    public func drawTooltip(in bounds: Rectangle) {
        let content = Self.content(in: bounds)
        view?.drawTooltip(at: Vector2(x: content.x, y: content.y))
    }

    private func drawBar(in bounds: Rectangle) {
        let mouse = GetMousePosition()
        theme.fillRectangle(bounds, theme.panel)
        var bar = bounds
        bar.height = Float(WindowFrame.titleHeight)
        theme.fillTitleBar(bar)
        DrawLine(Int(clamping: bounds.x), Int(clamping: bounds.y + Float(WindowFrame.titleHeight)), Int(clamping: bounds.x + bounds.width), Int(clamping: bounds.y + Float(WindowFrame.titleHeight)), theme.border)
        theme.outlineRectangle(bounds, theme.border)
        if showsCloseButton {
            drawButton(in: buttonBounds(bounds, slot: 0), fill: theme.closeButton, mark: theme.closeMark, mouse: mouse, isClose: true)
        }
        if showsMinimizeButton {
            drawButton(in: buttonBounds(bounds, slot: showsCloseButton ? 1 : 0), fill: theme.minimizeButton, mark: theme.minimizeMark, mouse: mouse, isClose: false)
        }
        let titles = itemTitles
        for i in 0..<titles.count {
            let item = toolBounds(bounds, i)
            let isSelected = isItemSelected(i)
            if isSelected {
                theme.fillRectangle(item, theme.selectedItem)
            }
            let color = if isItemDisabled(i) {
                Fade(theme.secondaryText, 0.5)
            } else if isSelected {
                theme.accent
            } else if CheckCollisionPointRec(mouse, item) {
                theme.text
            } else {
                theme.secondaryText
            }
            theme.drawText(titles[i], x: Int(clamping: item.x) + WindowFrame.toolbarPadding, y: Int(clamping: item.y + ((item.height - Float(theme.textSizes.body)) / 2)), size: theme.textSizes.body, color: color)
        }
        let title = titleBounds(bounds)
        if isEditingTitle {
            titleField.draw(in: title)
            if let titleValidationMessage {
                theme.drawText(titleValidationMessage, x: Int(clamping: title.x), y: Int(clamping: bounds.y + Float(WindowFrame.titleHeight) + 2), size: theme.textSizes.problem, color: theme.error)
            }
            return
        }
        let displayed = displayedTitle
        let shown = shown(displayed.text, in: title.width)
        let width = theme.textWidth(of: shown, size: theme.textSizes.title)
        let titleColor = if displayed.isPlaceholder {
            theme.secondaryText
        } else if isTitleEditable, CheckCollisionPointRec(mouse, title) {
            theme.accent
        } else {
            theme.text
        }
        theme.drawText(shown, x: Int(clamping: title.x + ((title.width - Float(width)) / 2)), y: Int(clamping: bounds.y + Float((WindowFrame.titleHeight - theme.textSizes.title) / 2)), size: theme.textSizes.title, color: titleColor)
    }

    // A colored dot, as macOS has it: marked with an x for close, or a dash for minimize, while the
    // pointer is over it.
    private func drawButton(in button: Rectangle, fill: Color, mark: Color, mouse: Vector2, isClose: Bool) {
        let (centerX, centerY) = (Int(clamping: button.x + Float(WindowFrame.buttonHit / 2)), Int(clamping: button.y + Float(WindowFrame.buttonHit / 2)))
        DrawCircle(centerX, centerY, Float(WindowFrame.buttonRadius), fill)
        guard CheckCollisionPointRec(mouse, button) else {
            return
        }
        if isClose {
            DrawLine(centerX - 3, centerY - 3, centerX + 3, centerY + 3, mark)
            DrawLine(centerX - 3, centerY + 3, centerX + 3, centerY - 3, mark)
        } else {
            DrawLine(centerX - 3, centerY, centerX + 4, centerY, mark)
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
    private func shown(_ text: String, in room: Float) -> String {
        if shownFor == text, shownRoom == room {
            return shownTitle
        }
        (shownFor, shownRoom) = (text, room)
        shownTitle = text
        if Float(theme.textWidth(of: text, size: theme.textSizes.title)) > room {
            var length = text.count
            while length > 0 && Float(theme.textWidth(of: String(text.prefix(length)) + WindowFrame.ellipsis, size: theme.textSizes.title)) > room {
                length -= 1
            }
            shownTitle = String(text.prefix(length)) + WindowFrame.ellipsis
        }
        return shownTitle
    }

    // The close button sits in the first slot at the bar's left, and the minimize button after it,
    // or in the first slot when there's no close button.
    private func buttonBounds(_ bounds: Rectangle, slot: Int) -> Rectangle {
        Rectangle(
            x: bounds.x + Float(Self.margin) - 2 + Float(slot * Self.buttonHit),
            y: bounds.y + Float((Self.titleHeight - Self.buttonHit) / 2),
            width: Float(Self.buttonHit),
            height: Float(Self.buttonHit)
        )
    }

    // The title sits between the buttons, if any, and the toolbar: centred in the window when it
    // fits there, as macOS has it, and otherwise in all the room between them.
    func titleBounds(_ bounds: Rectangle) -> Rectangle {
        let buttonCount = (showsCloseButton ? 1 : 0) + (showsMinimizeButton ? 1 : 0)
        let buttonRoom = buttonCount > 0 ? Float(buttonCount * WindowFrame.buttonHit) + Float(WindowFrame.margin) : 0.0
        let left = bounds.x + Float(WindowFrame.margin) + buttonRoom
        let right = itemTitles.count > 0 ? toolBounds(bounds, 0).x - Float(WindowFrame.margin) : bounds.x + bounds.width - Float(WindowFrame.margin)
        let between = max(0.0, right - left)
        let side = max(left - bounds.x, bounds.x + bounds.width - right)
        let centred = max(0.0, bounds.width - (side * 2))
        let wanted = isEditingTitle ? WindowFrame.editWidth : theme.textWidth(of: displayedTitle.text, size: theme.textSizes.title)
        let (x, room) = centred >= Float(wanted) ? (bounds.x + ((bounds.width - centred) / 2), centred) : (left, between)
        return Rectangle(x: x, y: bounds.y + 3, width: room, height: Float(WindowFrame.titleHeight - 6))
    }

    private func toolAt(_ point: Vector2, _ bounds: Rectangle) -> Int {
        for i in 0..<itemTitles.count {
            if CheckCollisionPointRec(point, toolBounds(bounds, i)) {
                return i
            }
        }
        return -1
    }

    // The items run leftward from the bar's right end, the last first, as the button row does.
    func toolBounds(_ bounds: Rectangle, _ index: Int) -> Rectangle {
        let titles = itemTitles
        var right = bounds.x + bounds.width - Float(WindowFrame.margin)
        for i in stride(from: titles.count - 1, through: 0, by: -1) {
            let width = theme.textWidth(of: titles[i], size: theme.textSizes.body) + (WindowFrame.toolbarPadding * 2)
            if i == index {
                return Rectangle(x: right - Float(width), y: bounds.y + 4, width: Float(width), height: Float(WindowFrame.titleHeight - 8))
            }
            right -= Float(width + WindowFrame.toolbarGap)
        }
        return Rectangle()
    }
}
