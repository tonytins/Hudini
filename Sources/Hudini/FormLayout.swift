import Raylib

/// A control that can be positioned by a `FormLayout`.
public protocol FormLayoutControl: AnyObject {
    /// The control's default height in a form.
    var formHeight: Float { get }

    /// The control's most recently assigned bounds.
    var bounds: Rectangle { get }

    /// Assigns the bounds calculated by a form.
    func place(in bounds: Rectangle)
}

/// Calculates label and control positions for a vertically stacked form.
public final class FormLayout {
    private static let labelFontSize: Int = 16
    private static let labelHeight: Float = 18

    private let descriptions: [Field]
    private let horizontalInset: Float
    private let topInset: Float
    private let labelSpacing: Float
    private let fieldSpacing: Float
    private let footerHeight: Float
    private let bottomInset: Float
    private var lastBounds: Rectangle?

    /// A labeled control's height in the form.
    public struct Field {
        public let label: String
        public let control: any FormLayoutControl
        public let height: Float

        /// Creates a field using the control's default form height.
        public init(label: String, control: any FormLayoutControl) {
            let height = control.formHeight
            precondition(height > 0, "control formHeight must be positive")
            self.label = label
            self.control = control
            self.height = height
        }

        /// Creates a field with a custom control height.
        public init(label: String, control: any FormLayoutControl, height: Float) {
            precondition(height > 0, "height must be positive")
            self.label = label
            self.control = control
            self.height = height
        }
    }

    /// The calculated positions for one label and its control.
    public struct FieldFrames {
        public let label: String
        public let labelPosition: Vector2
        public let controlBounds: Rectangle
    }

    /// The fields in the same order as their descriptions.
    public private(set) var fields: [FieldFrames] = []

    /// The lower-right corner where a `ButtonRow` can be drawn.
    public private(set) var buttonRowCorner = Vector2.zero

    /// Creates a form layout with fixed spacing.
    ///
    /// `footerHeight` reserves room below the fields for buttons or other actions.
    public init(
        fields descriptions: [Field],
        horizontalInset: Float = 10,
        topInset: Float = 12,
        labelSpacing: Float = 4,
        fieldSpacing: Float = 8,
        footerHeight: Float = 0,
        bottomInset: Float = 10
    ) {
        precondition(horizontalInset >= 0, "horizontalInset must not be negative")
        precondition(topInset >= 0, "topInset must not be negative")
        precondition(labelSpacing >= 0, "labelSpacing must not be negative")
        precondition(fieldSpacing >= 0, "fieldSpacing must not be negative")
        precondition(footerHeight >= 0, "footerHeight must not be negative")
        precondition(bottomInset >= 0, "bottomInset must not be negative")

        self.descriptions = descriptions
        self.horizontalInset = horizontalInset
        self.topInset = topInset
        self.labelSpacing = labelSpacing
        self.fieldSpacing = fieldSpacing
        self.footerHeight = footerHeight
        self.bottomInset = bottomInset
        fields.reserveCapacity(descriptions.count)
    }

    /// Calculates field positions before `fields` or `drawLabels` are used.
    ///
    /// Repeated calls with unchanged bounds do not recalculate the layout. Bounds too small for
    /// the form, such as a window the player shrank, leave controls narrow or overlapping the
    /// footer rather than failing.
    public func layout(in bounds: Rectangle) {
        if lastBounds == bounds {
            for (description, field) in zip(descriptions, fields) {
                description.control.place(in: field.controlBounds)
            }
            return
        }
        var top = bounds.y + topInset
        fields.removeAll(keepingCapacity: true)

        for description in descriptions {
            let labelPosition = Vector2(x: bounds.x + horizontalInset, y: top)
            let controlY = top + Self.labelHeight + labelSpacing
            let controlBounds = Rectangle(
                x: bounds.x + horizontalInset,
                y: controlY,
                width: max(0, bounds.width - (horizontalInset * 2)),
                height: description.height
            )
            description.control.place(in: controlBounds)
            fields.append(FieldFrames(
                label: description.label,
                labelPosition: labelPosition,
                controlBounds: controlBounds
            ))
            top = controlY + description.height + fieldSpacing
        }

        buttonRowCorner = Vector2(
            x: bounds.x + bounds.width - horizontalInset,
            y: bounds.y + bounds.height - bottomInset
        )
        lastBounds = bounds
    }

    /// Draws the form's labels using the theme's secondary text color.
    public func drawLabels(theme: InterfaceTheme = .standard) {
        for field in fields {
            theme.drawText(
                field.label,
                x: Int(clamping: field.labelPosition.x),
                y: Int(clamping: field.labelPosition.y),
                size: Self.labelFontSize,
                color: theme.secondaryText
            )
        }
    }
}
