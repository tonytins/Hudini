import Foundation
import Raylib

/// A 2D view that converts between world and screen coordinates.
public final class ViewportCamera {
    /// The smallest supported zoom level.
    public static let minZoom: Float = 0.25

    /// The largest supported zoom level.
    public static let maxZoom: Float = 4.0

    private static let zoomStep: Float = 0.15

    private var centerPosition: Vector2 = .zero

    /// Creates a camera at the given zoom level.
    public init(zoom: Float = 1.0) {
        self.zoom = min(max(zoom, Self.minZoom), Self.maxZoom)
    }

    /// The current zoom level.
    public private(set) var zoom: Float = 0

    /// The viewport's size in pixels.
    public private(set) var screenSize = Vector2(x: 1280, y: 720)

    /// The world point at the center of the viewport.
    public var centerPoint: Vector2 {
        centerPosition
    }

    /// Updates the viewport size in pixels.
    public func resize(to size: Vector2) {
        screenSize = size
    }

    /// Centers the view on a world point.
    public func center(on point: Vector2) {
        centerPosition = point
    }

    /// Sets the zoom level, limited to the supported range.
    public func zoom(to level: Float) {
        zoom = min(max(level, Self.minZoom), Self.maxZoom)
    }

    /// Moves the view by a distance in world units.
    public func pan(by offset: Vector2) {
        centerPosition += offset
    }

    /// Zooms around a screen point so the world point beneath it stays fixed.
    public func zoom(at screenPoint: Vector2, by wheelDelta: Float) {
        if wheelDelta == 0.0 {
            return
        }
        let before = worldPoint(forScreenPoint: screenPoint)
        let factor = 1.0 + (wheelDelta * Self.zoomStep)
        zoom = min(max(zoom * factor, Self.minZoom), Self.maxZoom)
        let after = worldPoint(forScreenPoint: screenPoint)
        centerPosition += before - after
    }

    /// Keeps the view within the world, centering it on any dimension smaller than the viewport.
    public func constrain(to worldSize: Vector2) {
        let halfWidth = screenSize.x / (2.0 * zoom)
        let halfHeight = screenSize.y / (2.0 * zoom)
        centerPosition.x = worldSize.x <= halfWidth * 2.0
            ? worldSize.x / 2.0
            : min(max(centerPosition.x, halfWidth), worldSize.x - halfWidth)
        centerPosition.y = worldSize.y <= halfHeight * 2.0
            ? worldSize.y / 2.0
            : min(max(centerPosition.y, halfHeight), worldSize.y - halfHeight)
    }

    /// Converts a world point to a screen point.
    public func screenPoint(forWorldPoint point: Vector2) -> Vector2 {
        ((point - centerPosition) * zoom) + (screenSize / 2.0)
    }

    /// Converts a screen point to a world point.
    public func worldPoint(forScreenPoint point: Vector2) -> Vector2 {
        ((point - (screenSize / 2.0)) / zoom) + centerPosition
    }

    /// The raylib camera used to draw this view with `BeginMode2D`.
    public var raylibCamera: Camera2D {
        Camera2D(offset: screenSize / 2.0, target: centerPosition, rotation: 0.0, zoom: zoom)
    }
}
