import Raylib

/// The classic scroll bar a `TextList` or `TextArea` draws down its right edge once its lines don't
/// all fit, so a game never has to place a control beside one to scroll it.
///
/// It follows VentureOS's classic bar: 15 pixels wide, taken from the content while it shows, with
/// an up arrow at its top, a down arrow at its bottom, and a thumb in the theme's accent between
/// them. An arrow scrolls a line and the track a page, both repeating while held, and the thumb
/// drags. A press on the bar belongs to the bar alone, so it never selects a row or moves focus.
struct ScrollBar {
    /// How wide the bar is, and how tall its arrows: Aqua's 15 pixels.
    static let width: Float = 15

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
    static func geometry(in bounds: Rectangle, position: Position) -> Geometry? {
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
            max(min(minimumThumbLength, track.height), (track.height * shown / (Float(position.last) + shown)).rounded(.down))
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
        guard isDown, let geometry = Self.geometry(in: bounds, position: position) else {
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

    /// Draws the bar: a shaded track, an arrow at each end, and a glossy thumb in the accent.
    static func draw(_ geometry: Geometry, theme: InterfaceTheme) {
        let bar = geometry.bar
        DrawRectangleGradientV(
            Int(clamping: bar.x),
            Int(clamping: bar.y),
            Int(clamping: bar.width),
            Int(clamping: bar.height),
            blend(theme.inputBackground, theme.border, 0.35),
            blend(theme.inputBackground, theme.border, 0.15)
        )
        DrawRectangleRec(Rectangle(x: bar.x, y: bar.y, width: 1, height: bar.height), theme.border)
        drawArrow(in: geometry.up, pointsUp: true, theme: theme)
        drawArrow(in: geometry.down, pointsUp: false, theme: theme)

        let thumb = Rectangle(
            x: geometry.thumb.x + 3,
            y: geometry.thumb.y + 1,
            width: geometry.thumb.width - 5,
            height: max(0, geometry.thumb.height - 2)
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
