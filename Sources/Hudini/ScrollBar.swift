import Raylib

/// The scroll bar a `TextList` or `TextArea` draws down its right edge once its lines don't all
/// fit, so a game never has to place a control beside one to scroll it.
///
/// Without art it's VentureOS's classic bar, drawn from the theme: 15 pixels wide, taken from the
/// content while it shows, with an up arrow at its top, a down arrow at its bottom, and a thumb in
/// the theme's accent between them. An appearance's `<ScrollBar>` can give it a width and images
/// for any of its parts; a part without one is drawn from the theme. An arrow scrolls a line and
/// the track a page, both repeating while held, and the thumb drags. A press on the bar belongs to
/// the bar alone, so it never selects a row or moves focus.
struct ScrollBar {
    /// The classic bar's width, and how tall its arrows are: Aqua's 15 pixels.
    static let defaultWidth: Float = Appearance.defaultScrollBarWidth

    static let minimumThumbLength: Float = 18

    /// Seconds an arrow or the track is held before it repeats, and between repeats.
    static let repeatDelay: Double = 0.35
    static let repeatInterval: Double = 0.05

    /// Where the content is scrolled to, in lines: the first line shown, the most `first` can be,
    /// and how many lines show at once.
    struct Position: Equatable {
        var first: Int
        var last: Int
        var shown: Int
    }

    enum Part: Equatable {
        case up, down, pageUp, pageDown, thumb
    }

    /// The bar's parts on the screen.
    struct Geometry: Equatable {
        var bar: Rectangle
        var up: Rectangle
        var down: Rectangle
        var track: Rectangle
        var thumb: Rectangle
    }

    /// The images a bar draws with, from an appearance. A part left out is drawn from the theme.
    struct Art {
        /// A loaded image and how it's sliced.
        struct Image {
            var texture: Texture2D
            var resource: UIScript.ImageResource
        }

        var up: Image?
        var down: Image?
        var thumb: Image?
        var track: Image?

        /// Pixels at the thumb image's top and bottom that keep their size while its middle
        /// stretches.
        var thumbCap: Float = 0
    }

    /// How wide the bar is, and how tall its arrows are.
    var width: Float = defaultWidth

    /// The images the bar draws with, or `nil` for the theme's classic bar.
    var art: Art?

    // An arrow or the track held down, and when it next repeats.
    private var hold: (part: Part, next: Double)?
    // Where the thumb was grabbed, from its top, while it's dragged.
    private var grab: Float?

    /// Whether a press on the bar is still held, so the pointer is the bar's until it's let go.
    var isHeld: Bool {
        hold != nil || grab != nil
    }

    /// Places the bar inside a control's one-pixel outline, or returns `nil` when everything fits
    /// and there is no bar.
    func geometry(in bounds: Rectangle, position: Position) -> Geometry? {
        guard position.last > 0 else {
            return nil
        }
        let bar = Rectangle(
            x: bounds.x + bounds.width - 1 - width,
            y: bounds.y + 1,
            width: width,
            height: max(0, bounds.height - 2)
        )
        let arrow = min(width, (bar.height / 3).rounded(.down))
        let up = Rectangle(x: bar.x, y: bar.y, width: bar.width, height: arrow)
        let down = Rectangle(x: bar.x, y: bar.y + bar.height - arrow, width: bar.width, height: arrow)
        let track = Rectangle(x: bar.x, y: bar.y + arrow, width: bar.width, height: max(0, bar.height - (2 * arrow)))

        let shown = Float(max(1, position.shown))
        let length = min(
            track.height,
            max(min(Self.minimumThumbLength, track.height), (track.height * shown / (Float(position.last) + shown)).rounded(.down))
        )
        let fraction = Float(min(max(position.first, 0), position.last)) / Float(position.last)
        let thumb = Rectangle(
            x: track.x,
            y: (track.y + ((track.height - length) * fraction)).rounded(.down),
            width: track.width,
            height: length
        )
        return Geometry(bar: bar, up: up, down: down, track: track, thumb: thumb)
    }

    /// The part of the bar at `point`, or `nil` when the point is off the bar.
    static func part(at point: Vector2, in geometry: Geometry) -> Part? {
        guard CheckCollisionPointRec(point, geometry.bar) else {
            return nil
        }
        if CheckCollisionPointRec(point, geometry.up) {
            return .up
        }
        if CheckCollisionPointRec(point, geometry.down) {
            return .down
        }
        if CheckCollisionPointRec(point, geometry.thumb) {
            return .thumb
        }
        return point.y < geometry.thumb.y ? .pageUp : .pageDown
    }

    /// Handles one frame of the pointer for a control placed at `bounds`.
    ///
    /// Returns whether the pointer is the bar's this frame, so the control leaves it alone, and the
    /// first line the content should now show, or `nil` to leave it where it is.
    mutating func update(
        pointer: Vector2,
        isPressed: Bool,
        isDown: Bool,
        time: Double,
        in bounds: Rectangle,
        position: Position
    ) -> (tookPointer: Bool, first: Int?) {
        guard isDown, let geometry = geometry(in: bounds, position: position) else {
            hold = nil
            grab = nil
            return (false, nil)
        }
        if isPressed {
            hold = nil
            grab = nil
            guard let part = Self.part(at: pointer, in: geometry) else {
                return (false, nil)
            }
            if part == .thumb {
                grab = pointer.y - geometry.thumb.y
                return (true, nil)
            }
            hold = (part, time + Self.repeatDelay)
            return (true, Self.step(part, from: position))
        }
        if let grab {
            let travel = max(1, geometry.track.height - geometry.thumb.height)
            let fraction = min(max((pointer.y - grab - geometry.track.y) / travel, 0), 1)
            return (true, Int((fraction * Float(position.last)).rounded()))
        }
        if let hold {
            guard time >= hold.next else {
                return (true, nil)
            }
            self.hold = (hold.part, time + Self.repeatInterval)
            // The track pages toward the pointer and stops once the thumb reaches it, as Aqua's does.
            guard Self.part(at: pointer, in: geometry) == hold.part else {
                return (true, nil)
            }
            return (true, Self.step(hold.part, from: position))
        }
        return (false, nil)
    }

    /// The first line after an arrow or the track scrolls once: a line, or a page less one line.
    static func step(_ part: Part, from position: Position) -> Int {
        let page = max(1, position.shown - 1)
        let change = switch part {
        case .up: -1
        case .down: 1
        case .pageUp: -page
        case .pageDown: page
        case .thumb: 0
        }
        return min(max(position.first + change, 0), position.last)
    }

    /// The state an arrow's image shows: disabled at its end, pressed while held, hovered under
    /// the pointer, and otherwise normal.
    func arrowState(_ part: Part, in box: Rectangle, position: Position, pointer: Vector2, isDown: Bool) -> UIScript.ButtonState {
        let atEnd = part == .up ? position.first <= 0 : position.first >= position.last
        if atEnd {
            return .disabled
        }
        if isDown, hold?.part == part {
            return .pressed
        }
        return CheckCollisionPointRec(pointer, box) ? .hovered : .normal
    }

    /// Draws the bar, with art for the parts that have it and the classic bar's look for the rest.
    func draw(_ geometry: Geometry, position: Position, theme: InterfaceTheme) {
        let pointer = GetMousePosition()
        let isDown = IsMouseButtonDown(MouseButton.left)

        if let track = art?.track {
            Self.drawImage(track, in: geometry.track, source: Self.source(of: track, state: .normal))
        } else {
            let bar = geometry.bar
            DrawRectangleGradientV(
                Int(clamping: bar.x),
                Int(clamping: bar.y),
                Int(clamping: bar.width),
                Int(clamping: bar.height),
                Self.blend(theme.inputBackground, theme.border, 0.35),
                Self.blend(theme.inputBackground, theme.border, 0.15)
            )
            DrawRectangleRec(Rectangle(x: bar.x, y: bar.y, width: 1, height: bar.height), theme.border)
        }

        for (part, box, image) in [(Part.up, geometry.up, art?.up), (.down, geometry.down, art?.down)] {
            if let image {
                let state = arrowState(part, in: box, position: position, pointer: pointer, isDown: isDown)
                Self.drawImage(image, in: box, source: Self.source(of: image, state: state))
            } else {
                Self.drawArrow(in: box, pointsUp: part == .up, theme: theme)
            }
        }

        if let thumb = art?.thumb {
            Self.drawThumb(thumb, in: geometry.thumb, cap: art?.thumbCap ?? 0)
        } else {
            Self.drawClassicThumb(in: geometry.thumb, theme: theme)
        }
    }

    // The part of an image a state shows: one slice of a multi-state image, or all of it.
    private static func source(of image: Art.Image, state: UIScript.ButtonState) -> Rectangle {
        image.resource.sourceRectangle(
            for: state,
            textureWidth: Float(image.texture.width),
            textureHeight: Float(image.texture.height)
        )
    }

    private static func drawImage(_ image: Art.Image, in box: Rectangle, source: Rectangle) {
        guard box.width > 0, box.height > 0 else {
            return
        }
        DrawTexturePro(image.texture, source, box, Vector2(x: 0, y: 0), 0, Color(r: 255, g: 255, b: 255, a: 255))
    }

    /// Draws a thumb image in three slices: its top and bottom `cap` pixels keep their height and
    /// its middle stretches. A thumb too short for both caps shrinks them evenly.
    static func drawThumb(_ image: Art.Image, in box: Rectangle, cap: Float) {
        let source = source(of: image, state: .normal)
        for (from, to) in thumbSlices(source: source, box: box, cap: cap) {
            drawImage(image, in: to, source: from)
        }
    }

    /// The thumb's slices as pairs of where they come from in the image and where they're drawn.
    static func thumbSlices(source: Rectangle, box: Rectangle, cap: Float) -> [(from: Rectangle, to: Rectangle)] {
        let sourceCap = min(max(cap, 0), source.height / 2)
        guard sourceCap > 0 else {
            return [(source, box)]
        }
        let drawnCap = min(sourceCap, box.height / 2)
        let middleSource = source.height - (2 * sourceCap)
        let middleDrawn = box.height - (2 * drawnCap)
        var slices: [(Rectangle, Rectangle)] = [
            (
                Rectangle(x: source.x, y: source.y, width: source.width, height: sourceCap),
                Rectangle(x: box.x, y: box.y, width: box.width, height: drawnCap)
            ),
        ]
        if middleSource > 0, middleDrawn > 0 {
            slices.append((
                Rectangle(x: source.x, y: source.y + sourceCap, width: source.width, height: middleSource),
                Rectangle(x: box.x, y: box.y + drawnCap, width: box.width, height: middleDrawn)
            ))
        }
        slices.append((
            Rectangle(x: source.x, y: source.y + source.height - sourceCap, width: source.width, height: sourceCap),
            Rectangle(x: box.x, y: box.y + box.height - drawnCap, width: box.width, height: drawnCap)
        ))
        return slices
    }

    // The classic thumb: a glossy pill in the accent.
    private static func drawClassicThumb(in box: Rectangle, theme: InterfaceTheme) {
        let thumb = Rectangle(
            x: box.x + 3,
            y: box.y + 1,
            width: box.width - 5,
            height: max(0, box.height - 2)
        )
        guard thumb.width > 0, thumb.height > 0 else {
            return
        }
        let white = Color(r: 255, g: 255, b: 255, a: 255)
        DrawRectangleRounded(thumb, 1, 8, blend(theme.accent, white, 0.2))
        // The gloss: a bright stripe down the thumb's left, short of its rounded ends.
        if thumb.height > thumb.width + 2 {
            DrawRectangleRec(
                Rectangle(x: thumb.x + 2, y: thumb.y + (thumb.width / 2), width: 2, height: thumb.height - thumb.width),
                blend(theme.accent, white, 0.6)
            )
        }
    }

    // An arrow's box, a line between it and the track, and a small triangle in it.
    private static func drawArrow(in box: Rectangle, pointsUp: Bool, theme: InterfaceTheme) {
        guard box.height >= 4 else {
            return
        }
        let x = Int(clamping: box.x), y = Int(clamping: box.y)
        let width = Int(clamping: box.width), height = Int(clamping: box.height)
        DrawRectangle(x + 1, y, width - 1, height, blend(theme.inputBackground, theme.border, 0.1))
        DrawRectangle(x + 1, pointsUp ? y + height - 1 : y, width - 1, 1, theme.border)

        // Four rows, one to seven pixels wide, centered.
        let rows = 4
        let middle = x + 1 + ((width - 1) / 2)
        let top = y + ((height - rows) / 2)
        for row in 0..<rows {
            let half = pointsUp ? row : rows - 1 - row
            DrawRectangle(middle - half, top + row, (2 * half) + 1, 1, theme.text)
        }
    }

    static func blend(_ from: Color, _ to: Color, _ amount: Float) -> Color {
        func mixed(_ a: UInt8, _ b: UInt8) -> UInt8 {
            UInt8(clamping: Int((Float(a) + ((Float(b) - Float(a)) * amount)).rounded()))
        }
        return Color(r: mixed(from.r, to.r), g: mixed(from.g, to.g), b: mixed(from.b, to.b), a: mixed(from.a, to.a))
    }
}
