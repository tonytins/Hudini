import Raylib

/// Builds, updates, and draws the controls and visuals a `UIScript` document describes.
///
/// The view owns the controls and their interaction state. The host owns game
/// data, actions, and images: it fills lists through `list(named:)`, draws into
/// regions, shows and hides things by name, and handles the events `update(at:)`
/// returns.
///
/// Create it once and keep it. Tooltips are not drawn yet, and the host draws
/// any window frame or background behind the view.
public final class UIScriptView {
    private static let defaultFontSize = 14
    private static let defaultMaximumLength = 256
    private static let textInset = 6
    private static let textLineGap = 4
    private static let missingImageSize: Float = 24

    private let script: UIScript
    private let theme: InterfaceTheme
    private let labels: [String: String]
    private let lists: [String: TextList]
    private let textFields: [String: TextField]
    private let textures: [String: Texture2D]
    private let sizes: [String: Vector2]
    private var hiddenNames: Set<String> = []
    private var disabledNames: Set<String> = []

    /// The names of image resources the host could not supply, in sorted order.
    ///
    /// Controls and visuals using these images draw a red outline instead. When
    /// they also leave out their size, they use a small fallback size.
    public let missingImages: [String]

    /// Something a control reports for the host to act on.
    public enum Event: Equatable, Sendable {
        /// An enabled button without a scroll binding was pressed.
        case pressed(control: String)
        /// A text field submitted its text.
        case submitted(control: String, text: String)
    }

    /// Creates the controls for `script`.
    ///
    /// `resolveString` supplies the text for localized-string references once,
    /// during creation. By default a reference shows its table and index, so an
    /// unresolved string is easy to notice.
    ///
    /// `loadImage` supplies each image resource once, during creation, so a host
    /// passing it must create the view after `InitWindow`. The host owns the
    /// textures and unloads them before `CloseWindow`. A control or visual that
    /// leaves out its size takes it from one slice of its image.
    public init(
        script: UIScript,
        theme: InterfaceTheme = .standard,
        resolveString: (UIScript.StringResource) -> String = { "\($0.table)#\($0.index)" },
        loadImage: (UIScript.ImageResource) -> Texture2D? = { _ in nil }
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
            case .slider, .region:
                break
            }
        }

        var textures: [String: Texture2D] = [:]
        var missingImages: [String] = []
        for (name, resource) in script.resources.images {
            if let texture = loadImage(resource) {
                textures[name] = texture
            } else {
                missingImages.append(name)
            }
        }

        func size(of frame: UIScript.Frame, image: String?) -> Vector2 {
            var imageWidth = Self.missingImageSize
            var imageHeight = Self.missingImageSize
            if let image, let texture = textures[image], let resource = script.resources.images[image] {
                imageWidth = Float(texture.width) / Float(resource.stateCount)
                imageHeight = Float(texture.height)
            }
            return Vector2(x: frame.width ?? imageWidth, y: frame.height ?? imageHeight)
        }

        var sizes: [String: Vector2] = [:]
        for visual in script.visuals {
            sizes[visual.name] = size(of: visual.frame, image: visual.image)
        }
        for control in script.controls {
            sizes[control.name] = size(of: control.frame, image: control.image)
        }

        self.labels = labels
        self.lists = lists
        self.textFields = textFields
        self.textures = textures
        self.sizes = sizes
        self.missingImages = missingImages.sorted()
    }

    /// Returns the screen bounds of a control or visual in a view whose corner is
    /// at `origin`, or `nil` when nothing has this name.
    ///
    /// These include any size taken from an image. A host can use them to handle
    /// input in a region.
    public func bounds(named name: String, at origin: Vector2) -> Rectangle? {
        guard let frame = script.control(named: name)?.frame ?? script.visual(named: name)?.frame else {
            return nil
        }
        return screenRectangle(for: frame, named: name, at: origin)
    }

    private func screenRectangle(
        for frame: UIScript.Frame,
        named name: String,
        at origin: Vector2
    ) -> Rectangle {
        let size = sizes[name] ?? .zero
        return Rectangle(x: origin.x + frame.x, y: origin.y + frame.y, width: size.x, height: size.y)
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

    /// Shows or hides a control or visual. A hidden one takes no input and draws nothing.
    public func setHidden(_ isHidden: Bool, named name: String) {
        if isHidden {
            hiddenNames.insert(name)
            textFields[name]?.clearFocus()
        } else {
            hiddenNames.remove(name)
        }
    }

    /// Returns whether a control or visual is hidden.
    public func isHidden(named name: String) -> Bool {
        hiddenNames.contains(name)
    }

    /// Enables or disables a button. A disabled button shows its disabled image
    /// and absorbs presses without reporting them.
    public func setDisabled(_ isDisabled: Bool, named name: String) {
        if isDisabled {
            disabledNames.insert(name)
        } else {
            disabledNames.remove(name)
        }
    }

    /// Returns whether a button is disabled.
    public func isDisabled(named name: String) -> Bool {
        disabledNames.contains(name)
    }

    /// Handles this frame's input for a view whose corner is at `origin`.
    public func update(at origin: Vector2) -> [Event] {
        var events: [Event] = []
        if IsMouseButtonPressed(MouseButton.left),
           let event = pressButton(at: GetMousePosition(), origin: origin) {
            events.append(event)
        }
        for control in script.controls where !hiddenNames.contains(control.name) {
            let bounds = screenRectangle(for: control.frame, named: control.name, at: origin)
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
    /// other enabled button reports `.pressed`.
    public func pressButton(at point: Vector2, origin: Vector2) -> Event? {
        for control in script.controls.reversed()
        where control.type == .button && !hiddenNames.contains(control.name) {
            guard CheckCollisionPointRec(point, screenRectangle(for: control.frame, named: control.name, at: origin)) else {
                continue
            }
            guard !disabledNames.contains(control.name) else {
                return nil
            }
            guard let binding = control.scrolls else {
                return .pressed(control: control.name)
            }
            lists[binding.list]?.scroll(byLines: binding.direction == .up ? 1 : -1)
            return nil
        }
        return nil
    }

    /// Draws the visible visuals, then the visible controls in document order, later ones on top.
    ///
    /// `drawRegion` receives the name and screen bounds of each visible region,
    /// in its place in that order.
    public func draw(
        at origin: Vector2,
        drawRegion: (_ name: String, _ bounds: Rectangle) -> Void = { _, _ in }
    ) {
        for visual in script.visuals where !hiddenNames.contains(visual.name) {
            drawImage(
                named: visual.image,
                state: .normal,
                in: screenRectangle(for: visual.frame, named: visual.name, at: origin)
            )
        }
        for control in script.controls where !hiddenNames.contains(control.name) {
            let bounds = screenRectangle(for: control.frame, named: control.name, at: origin)
            switch control.type {
            case .text:
                drawText(of: control, in: bounds, inset: 0)
            case .formattedText:
                DrawRectangleRec(bounds, script.style(for: control)?.backgroundColor ?? theme.panel)
                drawText(of: control, in: bounds, inset: Self.textInset)
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
            case .region:
                drawRegion(control.name, bounds)
            }
        }
    }

    private func drawImage(named name: String, state: UIScript.ButtonState, in bounds: Rectangle) {
        guard let texture = textures[name], let resource = script.resources.images[name] else {
            DrawRectangleLinesEx(bounds, 1, theme.error)
            return
        }
        DrawTexturePro(
            texture,
            resource.sourceRectangle(for: state, textureWidth: Float(texture.width), textureHeight: Float(texture.height)),
            bounds,
            .zero,
            0,
            .white
        )
    }

    private func drawText(of control: UIScript.Control, in bounds: Rectangle, inset: Int) {
        guard let label = labels[control.name] else {
            return
        }
        let style = script.style(for: control)
        let fontSize = style?.fontSize ?? Self.defaultFontSize
        let x = Int(clamping: bounds.x) + inset
        var y = Int(clamping: bounds.y) + inset
        for line in label.split(separator: "\n", omittingEmptySubsequences: false) {
            DrawText(String(line), x, y, fontSize, style?.textColor ?? theme.text)
            y += fontSize + Self.textLineGap
        }
    }

    private func buttonState(of control: UIScript.Control, in bounds: Rectangle) -> UIScript.ButtonState {
        if disabledNames.contains(control.name) {
            return .disabled
        }
        guard CheckCollisionPointRec(GetMousePosition(), bounds) else {
            return .normal
        }
        return IsMouseButtonDown(MouseButton.left) ? .pressed : .hovered
    }

    private func drawButton(_ control: UIScript.Control, in bounds: Rectangle) {
        let style = script.style(for: control)
        if let image = control.image {
            drawImage(named: image, state: buttonState(of: control, in: bounds), in: bounds)
        } else {
            DrawRectangleRec(bounds, style?.backgroundColor ?? theme.panel)
            DrawRectangleLinesEx(bounds, 1, style?.borderColor ?? theme.border)
        }
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
        list.prepareLines(for: screenRectangle(for: target.frame, named: target.name, at: origin))
        DrawRectangleRec(list.scrollThumbBounds(in: bounds), theme.accent)
    }
}
