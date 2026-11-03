import Foundation
import Raylib

/// Stores a window's position and keeps it within the screen while it is dragged.
final class WindowPlacement {
    private let titleHeight: Int

    private var position: Vector2? = nil

    private var grab: Vector2 = Vector2()

    /// Creates a placement for a window whose title bar is the given height.
    init(titleBarHeight: Int) {
        precondition(titleBarHeight > 0, "titleBarHeight must be positive")
        titleHeight = titleBarHeight
    }

    /// Whether the user is dragging the window.
    private(set) var isDragging: Bool = false

    /// Returns the window's current bounds, using `initialOrigin` until it is moved.
    func bounds(size: Vector2, initialOrigin: Vector2) -> Rectangle {
        let position = Self.keep(position ?? initialOrigin, size)
        return Rectangle(x: position.x, y: position.y, width: size.x, height: size.y)
    }

    /// Starts a drag when `point` lands on the title bar.
    func beginDragging(at point: Vector2, within bounds: Rectangle) -> Bool {
        var titleBounds = bounds
        titleBounds.height = min(Float(titleHeight), bounds.height)
        guard CheckCollisionPointRec(point, titleBounds) else {
            return false
        }
        position = Vector2(x: bounds.x, y: bounds.y)
        grab = point - Vector2(x: bounds.x, y: bounds.y)
        isDragging = true
        return true
    }

    /// Moves the window while the pointer button is held.
    func drag(to point: Vector2, isHeld: Bool, windowSize: Vector2) {
        guard isDragging else {
            return
        }
        position = Self.keep(point - grab, windowSize)
        isDragging = isHeld
    }

    private static func keep(_ position: Vector2, _ size: Vector2) -> Vector2 {
        let right = max(0.0, Float(Int(GetScreenWidth())) - size.x)
        let bottom = max(0.0, Float(Int(GetScreenHeight())) - size.y)
        return Vector2(
            x: min(max(position.x, 0.0), right),
            y: min(max(position.y, 0.0), bottom)
        )
    }
}
