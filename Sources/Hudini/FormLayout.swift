import Raylib

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
        public let controlHeight: Float

        /// Creates a field description.
        public init(label: String, controlHeight: Float) {
            precondition(controlHeight > 0, "controlHeight must be positive")
            self.label = label
            self.controlHeight = controlHeight
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
    /// Repeated calls with unchanged bounds do not recalculate the layout.
    public func layout(in bounds: Rectangle) {
        guard lastBounds != bounds else {
            return
        }
        precondition(
            bounds.width > horizontalInset * 2,
            "bounds must be wider than its horizontal insets"
        )

        var top = bounds.y + topInset
        fields.removeAll(keepingCapacity: true)

        for description in descriptions {
            let labelPosition = Vector2(x: bounds.x + horizontalInset, y: top)
            let controlY = top + Self.labelHeight + labelSpacing
            let controlBounds = Rectangle(
                x: bounds.x + horizontalInset,
                y: controlY,
                width: bounds.width - (horizontalInset * 2),
                height: description.controlHeight
            )
            fields.append(FieldFrames(
                label: description.label,
                labelPosition: labelPosition,
                controlBounds: controlBounds
            ))
            top = controlY + description.controlHeight + fieldSpacing
        }

        let fieldsBottom = fields.last.map { $0.controlBounds.y + $0.controlBounds.height }
            ?? (bounds.y + topInset)
        let footerTop = bounds.y + bounds.height - bottomInset - footerHeight
        precondition(fieldsBottom <= footerTop, "form fields overlap the reserved footer")

        buttonRowCorner = Vector2(
            x: bounds.x + bounds.width - horizontalInset,
            y: bounds.y + bounds.height - bottomInset
        )
        lastBounds = bounds
    }

    /// Draws the form's labels using the theme's secondary text color.
    public func drawLabels(theme: InterfaceTheme = .standard) {
        for field in fields {
            DrawText(
                field.label,
                Int(clamping: field.labelPosition.x),
                Int(clamping: field.labelPosition.y),
                Self.labelFontSize,
                theme.secondaryText
            )
        }
    }
}
