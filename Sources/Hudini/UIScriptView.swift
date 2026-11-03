import Raylib

/// Builds, updates, and draws the controls a `UIScript` document describes.
///
/// The view owns the controls and their interaction state. The host owns game
/// data and actions: it fills lists through `list(named:)`, shows and hides
/// controls by name, and handles the events `update(at:)` returns.
///
/// Create it once and keep it. Images, visuals, and tooltips are not drawn yet,
/// and the host draws any window frame behind the controls.
public final class UIScriptView {
    private static let defaultFontSize = 14
    private static let defaultMaximumLength = 256
    private static let textInset = 6
    private static let textLineGap = 4

    private let script: UIScript
    private let theme: InterfaceTheme
    private let labels: [String: String]
    private let lists: [String: TextList]
    private let textFields: [String: TextField]
    private var hiddenControls: Set<String> = []

    /// Something a control reports for the host to act on.
    public enum Event: Equatable, Sendable {
        /// A button without a scroll binding was pressed.
        case pressed(control: String)
        /// A text field submitted its text.
        case submitted(control: String, text: String)
    }

    /// Creates the controls for `script`.
    ///
    /// `resolveString` supplies the text for localized-string references once,
    /// during creation. By default a reference shows its table and index, so an
    /// unresolved string is easy to notice.
    public init(
        script: UIScript,
        theme: InterfaceTheme = .standard,
        resolveString: (UIScript.StringResource) -> String = { "\($0.table)#\($0.index)" }
    ) {
        self.script = script
        self.theme = theme

        func resolved(_ text: UIScript.Text?) -> String? {
            switch text {
            case nil:
                nil
            case let .literal(value):
                value
            case let .string(name):
                script.resources.strings[name].map(resolveString)
            }
        }

        var labels: [String: String] = [:]
        var lists: [String: TextList] = [:]
        var textFields: [String: TextField] = [:]
        for control in script.controls {
            let style = script.style(for: control)
            let text = resolved(control.text)
            switch control.type {
            case .text, .formattedText, .button:
                labels[control.name] = text
            case .list:
                lists[control.name] = TextList(
                    items: text.map { [$0] } ?? [],
                    fontSize: style?.fontSize ?? Self.defaultFontSize,
                    theme: theme,
                    textColor: style?.textColor,
                    backgroundColor: style?.backgroundColor,
                    borderColor: style?.borderColor
                )
            case .textField:
                textFields[control.name] = TextField(
                    text: text ?? "",
                    maximumLength: control.maximumLength ?? Self.defaultMaximumLength,
                    fontSize: style?.fontSize ?? Self.defaultFontSize,
                    theme: theme,
                    placeholder: resolved(control.placeholder),
                    textColor: style?.textColor,
                    backgroundColor: style?.backgroundColor,
                    borderColor: style?.borderColor
                )
            case .slider:
                break
            }
        }
        self.labels = labels
        self.lists = lists
        self.textFields = textFields
    }

    /// Returns the list with this name, or `nil` when no list has it.
    ///
    /// Documents load at runtime, so look up the controls a host depends on at
    /// startup and report any that are missing.
    public func list(named name: String) -> TextList? {
        lists[name]
    }

    /// Returns the text field with this name, or `nil` when no text field has it.
    public func textField(named name: String) -> TextField? {
        textFields[name]
    }

    /// Shows or hides a control. A hidden control takes no input and draws nothing.
    public func setHidden(_ isHidden: Bool, forControlNamed name: String) {
        if isHidden {
            hiddenControls.insert(name)
            textFields[name]?.clearFocus()
        } else {
            hiddenControls.remove(name)
        }
    }

    /// Returns whether a control is hidden.
    public func isHidden(controlNamed name: String) -> Bool {
        hiddenControls.contains(name)
    }

    /// Handles this frame's input for a window whose corner is at `origin`.
    public func update(at origin: Vector2) -> [Event] {
        var events: [Event] = []
        if IsMouseButtonPressed(MouseButton.left),
           let event = pressButton(at: GetMousePosition(), origin: origin) {
            events.append(event)
        }
        for control in script.controls where !hiddenControls.contains(control.name) {
            let bounds = control.frame.rectangle(at: origin)
            lists[control.name]?.update(in: bounds)
            if case let .submitted(text)? = textFields[control.name]?.update(in: bounds) {
                events.append(.submitted(control: control.name, text: text))
            }
        }
        return events
    }

    /// Applies a press to the topmost visible button under `point`.
    ///
    /// A button bound to a list scrolls it one line and reports nothing. Any
    /// other button reports `.pressed`.
    public func pressButton(at point: Vector2, origin: Vector2) -> Event? {
        for control in script.controls.reversed()
        where control.type == .button && !hiddenControls.contains(control.name) {
            guard CheckCollisionPointRec(point, control.frame.rectangle(at: origin)) else {
                continue
            }
            guard let binding = control.scrolls else {
                return .pressed(control: control.name)
            }
            lists[binding.list]?.scroll(byLines: binding.direction == .up ? 1 : -1)
            return nil
        }
        return nil
    }

    /// Draws the visible controls in document order, later controls on top.
    public func draw(at origin: Vector2) {
        for control in script.controls where !hiddenControls.contains(control.name) {
            let bounds = control.frame.rectangle(at: origin)
            switch control.type {
            case .text:
                drawText(of: control, in: bounds)
            case .formattedText:
                DrawRectangleRec(bounds, script.style(for: control)?.backgroundColor ?? theme.panel)
                drawText(of: control, in: bounds)
            case .button:
                drawButton(control, in: bounds)
            case .textField:
                if let field = textFields[control.name] {
                    field.draw(in: bounds, isFocused: field.isFocused)
                }
            case .list:
                lists[control.name]?.draw(in: bounds)
            case .slider:
                drawSlider(control, in: bounds, origin: origin)
            }
        }
    }

    private func drawText(of control: UIScript.Control, in bounds: Rectangle) {
        guard let label = labels[control.name] else {
            return
        }
        let style = script.style(for: control)
        let fontSize = style?.fontSize ?? Self.defaultFontSize
        let x = Int(clamping: bounds.x) + Self.textInset
        var y = Int(clamping: bounds.y) + Self.textInset
        for line in label.split(separator: "\n", omittingEmptySubsequences: false) {
            DrawText(String(line), x, y, fontSize, style?.textColor ?? theme.text)
            y += fontSize + Self.textLineGap
        }
    }

    private func drawButton(_ control: UIScript.Control, in bounds: Rectangle) {
        let style = script.style(for: control)
        DrawRectangleRec(bounds, style?.backgroundColor ?? theme.panel)
        DrawRectangleLinesEx(bounds, 1, style?.borderColor ?? theme.border)
        guard let label = labels[control.name] else {
            return
        }
        let fontSize = style?.fontSize ?? Self.defaultFontSize
        DrawText(
            label,
            Int(clamping: bounds.x + ((bounds.width - Float(MeasureText(label, fontSize))) / 2)),
            Int(clamping: bounds.y + ((bounds.height - Float(fontSize)) / 2)),
            fontSize,
            style?.textColor ?? theme.text
        )
    }

    private func drawSlider(_ control: UIScript.Control, in bounds: Rectangle, origin: Vector2) {
        let style = script.style(for: control)
        DrawRectangleRec(bounds, style?.backgroundColor ?? theme.panel)
        DrawRectangleLinesEx(bounds, 1, style?.borderColor ?? theme.border)
        guard let binding = control.scrolls,
              let list = lists[binding.list],
              let target = script.control(named: binding.list) else {
            return
        }
        // The slider may draw before its list, after the host changed the items.
        list.prepareLines(for: target.frame.rectangle(at: origin))
        DrawRectangleRec(list.scrollThumbBounds(in: bounds), theme.accent)
    }
}
