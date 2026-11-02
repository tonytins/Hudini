import Foundation
import Raylib

/// A window that can be moved by dragging its title bar.
public protocol MovableWindow {
    /// Where the window is on the screen.
    var bounds: Rectangle { get }

    /// Whether the user is dragging the window.
    var isDragging: Bool { get }

    /// Starts dragging when a press lands on the title bar.
    func beginDragging(at point: Vector2) -> Bool

    /// Moves the window with the pointer while the button is held, and lets it go when it isn't.
    func drag(to point: Vector2, isHeld: Bool)
}
