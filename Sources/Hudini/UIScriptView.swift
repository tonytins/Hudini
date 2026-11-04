import Raylib

/// Builds, updates, and draws the controls and visuals a `UIScript` document describes.
///
/// The view owns the controls and their interaction state. The host owns game
/// data, actions, and images: it fills lists through `list(named:)`, draws into
/// regions, shows and hides things by name, and handles the events `update(at:)`
/// returns.
///
/// Create it once and keep it. The host draws any window frame or background
/// behind the view, and it can place one view inside another by drawing it at a
/// region's corner, or in a `WindowFrame`, without the document changing.
public final class UIScriptView {
    private static let defaultFontSize = 14
    private static let defaultMaximumLength = 256
    private static let textInset = 6
    private static let textLineGap = 4
    private static let missingImageSize: Float = 24
    private static let sliderThumbLength: Float = 10
    private static let tooltipDelay: Float = 0.5
    private static let tooltipFontSize = 12
    private static let tooltipPadding: Float = 4
    private static let tooltipGap: Float = 4

    private let script: UIScript
    private let theme: InterfaceTheme
    private var labels: [String: String]
    private let lists: [String: TextList]
    private let textFields: [String: TextField]
    private let textures: [String: Texture2D]
    private let sizes: [String: Vector2]
    private let tooltips: [String: String]
    private var values: [String: Float]
    private var boundsOverrides: [String: Rectangle] = [:]
    private var draggedSlider: (name: String, grab: Float)?
    private var hoveredControl: String?
    private var hoveredSeconds: Float = 0
    private(set) var pendingTooltip: String?
    private var hiddenNames: Set<String> = []
    private var disabledNames: Set<String> = []
    private var selectedNames: Set<String> = []
    private var windowSize: Vector2

    /// The names of image resources the host could not supply, in sorted order.
    ///
    /// Controls and visuals using these images draw a red outline instead. When
    /// they also leave out their size, they use a small fallback size.
    public let missingImages: [String]

    /// The names of string resources the host could not supply, in sorted order.
    ///
    /// Controls using these show their table and index instead, so the gap is easy to notice.
    /// A tooltip using one does not show.
    public let missingStrings: [String]

    /// Something a control reports for the host to act on.
    public enum Event: Equatable, Sendable {
        /// An enabled button without a scroll binding was pressed.
        case pressed(control: String)
        /// A text field submitted its text.
        case submitted(control: String, text: String)
        /// Dragging moved a slider that does not scroll a list to a new value.
        case changed(control: String, value: Float)
    }

    /// Creates the controls for `script`.
    ///
    /// `resolveString` supplies the text for localized-string references once,
    /// during creation. `CSTCatalog.text(for:)` fits here. When it returns `nil`,
    /// the reference shows its table and index and appears in `missingStrings`,
    /// which is what happens to every reference by default.
    ///
    /// `loadImage` supplies each image resource once, during creation, so a host
    /// passing it must create the view after `InitWindow`. The host owns the
    /// textures and unloads them before `CloseWindow`. A control or visual that
    /// leaves out its size takes it from one slice of its image.
    public init(
        script: UIScript,
        theme: InterfaceTheme = .standard,
        resolveString: (UIScript.StringResource) -> String? = { _ in nil },
        loadImage: (UIScript.ImageResource) -> Texture2D? = { _ in nil }
    ) {
        self.script = script
        self.theme = theme
        windowSize = Vector2(x: script.window.size.width, y: script.window.size.height)

        var strings: [String: String] = [:]
        var missingStrings: [String] = []
        for (name, resource) in script.resources.strings {
            if let text = resolveString(resource) {
                strings[name] = text
            } else {
                missingStrings.append(name)
            }
        }

        func resolved(_ text: UIScript.Text?) -> String? {
            switch text {
            case nil:
                nil
            case let .literal(value):
                value
            case let .string(name):
                strings[name] ?? script.resources.strings[name].map { "\($0.table)#\($0.index)" }
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
                    borderColor: style?.borderColor,
                    isReadOnly: control.isReadOnly,
                    isSecure: control.isSecure
                )
            case .slider, .progressBar, .region:
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
        tooltips = script.controls.reduce(into: [:]) { result, control in
            if let name = control.tooltip, let text = strings[name] {
                result[control.name] = text
            }
        }
        values = script.controls.reduce(into: [:]) { result, control in
            if control.type == .slider || control.type == .progressBar {
                result[control.name] = control.valueRange?.lowerBound ?? 0
            }
        }
        hiddenNames = Set(
            script.visuals.filter(\.isInitiallyHidden).map(\.name)
                + script.controls.filter(\.isInitiallyHidden).map(\.name)
        )
        self.missingImages = missingImages.sorted()
        self.missingStrings = missingStrings.sorted()
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
        if let override = boundsOverrides[name] {
            return Rectangle(
                x: origin.x + override.x,
                y: origin.y + override.y,
                width: override.width,
                height: override.height
            )
        }
        let size = sizes[name] ?? .zero
        let (x, width) = Self.placement(
            position: frame.x,
            size: size.x,
            leading: frame.edgeOffsets?.left,
            trailing: frame.edgeOffsets?.right,
            available: windowSize.x
        )
        let (y, height) = Self.placement(
            position: frame.y,
            size: size.y,
            leading: frame.edgeOffsets?.top,
            trailing: frame.edgeOffsets?.bottom,
            available: windowSize.y
        )
        return Rectangle(x: origin.x + x, y: origin.y + y, width: width, height: height)
    }

    private static func placement(
        position: Float,
        size: Float,
        leading: Float?,
        trailing: Float?,
        available: Float
    ) -> (position: Float, size: Float) {
        switch (leading, trailing) {
        case let (leading?, trailing?):
            (leading, max(0, available - leading - trailing))
        case let (nil, trailing?):
            (available - trailing - size, size)
        case let (leading?, nil):
            (leading, size)
        case (nil, nil):
            (position, size)
        }
    }

    /// Sets the size edge offsets measure from, such as a resized screen. It starts as the
    /// document's window size.
    public func setWindowSize(_ size: Vector2) {
        windowSize = size
    }

    /// Places a control or visual within the view, replacing its document position, size, and
    /// edge offsets.
    ///
    /// Some `.uis` controls leave these for game code to set, and `UIScript.setting(named:)`
    /// may hold the values to use.
    public func setBounds(_ bounds: Rectangle, named name: String) {
        boundsOverrides[name] = bounds
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

    /// Returns the text of a text, formatted text, button, or text field control, or `nil` when
    /// it has none.
    public func text(named name: String) -> String? {
        textFields[name]?.text ?? labels[name]
    }

    /// Replaces the text of a text, formatted text, button, or text field control.
    ///
    /// This is cheap enough to call every frame, for example for a clock or a
    /// balance. Other controls and unknown names are left alone.
    public func setText(_ text: String, named name: String) {
        if let field = textFields[name] {
            field.text = text
            return
        }
        switch script.control(named: name)?.type {
        case .text, .formattedText, .button:
            labels[name] = text
        default:
            break
        }
    }

    /// Returns the value of a slider or progress bar, or `nil` when no such control has this name.
    public func value(named name: String) -> Float? {
        values[name]
    }

    /// Sets the value of a slider or progress bar, kept within its range. This is cheap enough
    /// to call every frame. It reports no event, and other controls are left alone.
    public func setValue(_ value: Float, named name: String) {
        guard values[name] != nil, value.isFinite, let control = script.control(named: name) else {
            return
        }
        let range = Self.range(of: control)
        values[name] = min(max(value, range.lowerBound), range.upperBound)
    }

    private static func range(of control: UIScript.Control) -> ClosedRange<Float> {
        control.valueRange ?? 0...1
    }

    private func fraction(of control: UIScript.Control) -> Float {
        let range = Self.range(of: control)
        return ((values[control.name] ?? range.lowerBound) - range.lowerBound)
            / (range.upperBound - range.lowerBound)
    }

    /// Removes keyboard focus from the view's text fields. Call this when a view stops being
    /// shown, so it does not hold focus while it is away.
    public func clearFocus() {
        for field in textFields.values {
            field.setFocused(false)
        }
    }

    /// Returns whether `point` is over a visible control or visual in a view whose corner is at
    /// `origin`.
    ///
    /// Use this to keep a click on the interface from also reaching the game
    /// behind it. A background the host draws itself is not part of the view.
    public func containsPoint(_ point: Vector2, origin: Vector2) -> Bool {
        let names = script.controls.map(\.name) + script.visuals.map(\.name)
        return names.contains { name in
            guard !hiddenNames.contains(name), let bounds = bounds(named: name, at: origin) else {
                return false
            }
            return CheckCollisionPointRec(point, bounds)
        }
    }

    /// Shows or hides a control or visual. A hidden one takes no input and draws nothing.
    public func setHidden(_ isHidden: Bool, named name: String) {
        if isHidden {
            hiddenNames.insert(name)
            textFields[name]?.setFocused(false)
        } else {
            hiddenNames.remove(name)
        }
    }

    /// Returns whether a control or visual is hidden.
    public func isHidden(named name: String) -> Bool {
        hiddenNames.contains(name)
    }

    /// Enables or disables a button or slider. A disabled button shows its disabled image and
    /// absorbs presses without reporting them. A disabled slider cannot be dragged.
    public func setDisabled(_ isDisabled: Bool, named name: String) {
        if isDisabled {
            disabledNames.insert(name)
        } else {
            disabledNames.remove(name)
        }
    }

    /// Returns whether a button or slider is disabled.
    public func isDisabled(named name: String) -> Bool {
        disabledNames.contains(name)
    }

    /// Selects or deselects a button, for a toggle or a choice among buttons. A selected button
    /// shows its pressed image and selected text color, and still reports presses.
    public func setSelected(_ isSelected: Bool, named name: String) {
        if isSelected {
            selectedNames.insert(name)
        } else {
            selectedNames.remove(name)
        }
    }

    /// Returns whether a button is selected.
    public func isSelected(named name: String) -> Bool {
        selectedNames.contains(name)
    }

    /// Handles this frame's input for a view whose corner is at `origin`.
    public func update(at origin: Vector2) -> [Event] {
        var events: [Event] = []
        let pointer = GetMousePosition()
        if IsMouseButtonPressed(MouseButton.left) {
            if let event = pressButton(at: pointer, origin: origin) {
                events.append(event)
            }
            _ = beginSliderDrag(at: pointer, origin: origin)
        }
        if IsMouseButtonDown(MouseButton.left) {
            if let event = dragSlider(to: pointer, origin: origin) {
                events.append(event)
            }
        } else {
            draggedSlider = nil
        }
        for control in script.controls where !hiddenNames.contains(control.name) {
            let bounds = screenRectangle(for: control.frame, named: control.name, at: origin)
            lists[control.name]?.update(in: bounds)
            if case let .submitted(text)? = textFields[control.name]?.update(in: bounds) {
                events.append(.submitted(control: control.name, text: text))
            }
        }
        updateTooltip(
            pointer: pointer,
            origin: origin,
            elapsed: IsMouseButtonDown(MouseButton.left) ? -.infinity : GetFrameTime()
        )
        return events
    }

    /// Tracks how long the pointer has rested on the topmost control under it. A negative
    /// `elapsed` starts the wait again, which is how a held button dismisses a tooltip.
    func updateTooltip(pointer: Vector2, origin: Vector2, elapsed: Float) {
        let topmost = script.controls.last { control in
            !hiddenNames.contains(control.name)
                && CheckCollisionPointRec(pointer, screenRectangle(for: control.frame, named: control.name, at: origin))
        }
        let name = topmost.flatMap { tooltips[$0.name]?.isEmpty == false ? $0.name : nil }
        if name != hoveredControl {
            hoveredControl = name
            hoveredSeconds = 0
        }
        hoveredSeconds = max(0, hoveredSeconds + elapsed)
        pendingTooltip = hoveredSeconds >= Self.tooltipDelay ? name : nil
    }

    /// Starts dragging the topmost visible, enabled slider under `point`. Pressing the track
    /// away from the thumb moves the thumb's center to the pointer.
    func beginSliderDrag(at point: Vector2, origin: Vector2) -> Bool {
        for control in script.controls.reversed()
        where control.type == .slider && !hiddenNames.contains(control.name) {
            let track = screenRectangle(for: control.frame, named: control.name, at: origin)
            guard CheckCollisionPointRec(point, track) else {
                continue
            }
            guard !disabledNames.contains(control.name) else {
                return false
            }
            let thumb = sliderThumb(of: control, in: track, origin: origin)
            let isVertical = sliderOrientation(of: control, in: track) == .vertical
            let grab = CheckCollisionPointRec(point, thumb)
                ? (isVertical ? point.y - thumb.y : point.x - thumb.x)
                : (isVertical ? thumb.height : thumb.width) / 2
            draggedSlider = (control.name, grab)
            return true
        }
        return false
    }

    /// Moves the dragged slider toward `point`, reporting a change to a slider's value.
    func dragSlider(to point: Vector2, origin: Vector2) -> Event? {
        guard let dragged = draggedSlider, let control = script.control(named: dragged.name),
              !hiddenNames.contains(dragged.name), !disabledNames.contains(dragged.name) else {
            draggedSlider = nil
            return nil
        }
        let track = screenRectangle(for: control.frame, named: control.name, at: origin)
        let thumb = sliderThumb(of: control, in: track, origin: origin)
        let isVertical = sliderOrientation(of: control, in: track) == .vertical
        let fraction = Self.sliderFraction(
            pointer: isVertical ? point.y : point.x,
            trackStart: isVertical ? track.y : track.x,
            trackLength: isVertical ? track.height : track.width,
            thumbLength: isVertical ? thumb.height : thumb.width,
            grab: dragged.grab
        )
        if let binding = control.scrolls {
            lists[binding.list]?.scroll(toFraction: fraction)
            return nil
        }
        let range = Self.range(of: control)
        let value = range.lowerBound + (fraction * (range.upperBound - range.lowerBound))
        guard value != values[control.name] else {
            return nil
        }
        values[control.name] = value
        return .changed(control: control.name, value: value)
    }

    /// Converts a pointer position to a slider position from 0 to 1. The thumb travels inside
    /// the track's one-pixel border.
    static func sliderFraction(
        pointer: Float,
        trackStart: Float,
        trackLength: Float,
        thumbLength: Float,
        grab: Float
    ) -> Float {
        let room = trackLength - 2 - thumbLength
        guard room > 0 else {
            return 0
        }
        return min(max((pointer - grab - trackStart - 1) / room, 0), 1)
    }

    private func sliderOrientation(of control: UIScript.Control, in track: Rectangle) -> UIScript.Orientation {
        if control.scrolls != nil {
            return .vertical
        }
        return control.orientation ?? (track.height > track.width ? .vertical : .horizontal)
    }

    private func sliderThumb(of control: UIScript.Control, in track: Rectangle, origin: Vector2) -> Rectangle {
        if let binding = control.scrolls, let list = lists[binding.list],
           let target = script.control(named: binding.list) {
            // The slider may act before its list, after the host changed the items.
            list.prepareLines(for: screenRectangle(for: target.frame, named: target.name, at: origin))
            return list.scrollThumbBounds(in: track)
        }
        let fraction = fraction(of: control)
        let length = Self.sliderThumbLength
        let width = max(0, track.width - 2)
        let height = max(0, track.height - 2)
        switch sliderOrientation(of: control, in: track) {
        case .horizontal:
            let thumb = min(length, width)
            return Rectangle(x: track.x + 1 + ((width - thumb) * fraction), y: track.y + 1, width: thumb, height: height)
        case .vertical:
            let thumb = min(length, height)
            return Rectangle(x: track.x + 1, y: track.y + 1 + ((height - thumb) * fraction), width: width, height: thumb)
        }
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
                textFields[control.name]?.draw(in: bounds)
            case .list:
                lists[control.name]?.draw(in: bounds)
            case .slider:
                drawSlider(control, in: bounds, origin: origin)
            case .progressBar:
                drawProgressBar(control, in: bounds)
            case .region:
                drawRegion(control.name, bounds)
            }
        }
    }

    /// Draws the tooltip of the control the pointer has rested on, if any.
    ///
    /// Call this after drawing every view, so nothing covers the tooltip. It shows after a
    /// `update(at:)` in the same frame, so a view the host stops updating shows none.
    public func drawTooltip(at origin: Vector2) {
        defer { pendingTooltip = nil }
        guard let name = pendingTooltip, let text = tooltips[name], let control = script.control(named: name) else {
            return
        }
        let bounds = Self.tooltipBounds(
            textWidth: Float(MeasureText(text, Self.tooltipFontSize)),
            below: screenRectangle(for: control.frame, named: name, at: origin),
            screen: Vector2(x: Float(GetScreenWidth()), y: Float(GetScreenHeight()))
        )
        DrawRectangleRec(bounds, theme.panel)
        DrawRectangleLinesEx(bounds, 1, theme.border)
        DrawText(
            text,
            Int(clamping: bounds.x + Self.tooltipPadding),
            Int(clamping: bounds.y + Self.tooltipPadding),
            Self.tooltipFontSize,
            theme.text
        )
    }

    /// Places a tooltip under its control, above it when there is no room below, and on screen.
    static func tooltipBounds(textWidth: Float, below control: Rectangle, screen: Vector2) -> Rectangle {
        let width = textWidth + (tooltipPadding * 2)
        let height = Float(tooltipFontSize) + (tooltipPadding * 2)
        let below = control.y + control.height + tooltipGap
        let y = below + height <= screen.y ? below : control.y - tooltipGap - height
        return Rectangle(
            x: max(0, min(control.x, screen.x - width)),
            y: max(0, y),
            width: width,
            height: height
        )
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
        let left = Int(clamping: bounds.x) + inset
        let room = Int(clamping: bounds.width) - (inset * 2)
        var y = Int(clamping: bounds.y) + inset
        for line in label.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            let x = switch control.alignment {
            case .left: left
            case .center: left + ((room - MeasureText(line, fontSize)) / 2)
            case .right: left + room - MeasureText(line, fontSize)
            }
            DrawText(line, x, y, fontSize, style?.textColor ?? theme.text)
            y += fontSize + Self.textLineGap
        }
    }

    private func buttonState(of control: UIScript.Control, in bounds: Rectangle) -> UIScript.ButtonState {
        if disabledNames.contains(control.name) {
            return .disabled
        }
        if selectedNames.contains(control.name) {
            return .pressed
        }
        guard CheckCollisionPointRec(GetMousePosition(), bounds) else {
            return .normal
        }
        return IsMouseButtonDown(MouseButton.left) ? .pressed : .hovered
    }

    private func drawButton(_ control: UIScript.Control, in bounds: Rectangle) {
        let style = script.style(for: control)
        let state = buttonState(of: control, in: bounds)
        if let image = control.image {
            drawImage(named: image, state: state, in: bounds)
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
            style?.textColor(for: state) ?? (state == .disabled ? theme.secondaryText : theme.text)
        )
    }

    private func drawSlider(_ control: UIScript.Control, in bounds: Rectangle, origin: Vector2) {
        let style = script.style(for: control)
        DrawRectangleRec(bounds, style?.backgroundColor ?? theme.panel)
        DrawRectangleLinesEx(bounds, 1, style?.borderColor ?? theme.border)
        if control.scrolls != nil, control.scrolls.flatMap({ lists[$0.list] }) == nil {
            return
        }
        let color = disabledNames.contains(control.name) ? theme.secondaryText : (style?.fillColor ?? theme.accent)
        DrawRectangleRec(sliderThumb(of: control, in: bounds, origin: origin), color)
    }

    private func drawProgressBar(_ control: UIScript.Control, in bounds: Rectangle) {
        let style = script.style(for: control)
        DrawRectangleRec(bounds, style?.backgroundColor ?? theme.panel)
        var filled = bounds
        filled.width *= fraction(of: control)
        DrawRectangleRec(filled, style?.fillColor ?? theme.accent)
        DrawRectangleLinesEx(bounds, 1, style?.borderColor ?? theme.border)
    }
}
