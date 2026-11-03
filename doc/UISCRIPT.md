# UIScript Format

A UIScript document is an XML file describing one interface: its window size,
resources, styles, decorative images, and controls. `UIScript` reads it and
`UIScriptView` builds, updates, and draws it.

UIScript describes presentation. The host game owns live data, actions, images,
and localized text. The format is inspired by The Sims Online's `.uis` files,
but it is not compatible with them, and `.uis` files are not valid XML.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!-- Comments are welcome anywhere. -->
<UIScript version="1">
  <Window width="400" height="255"/>

  <Image name="send" path="ui/send.bmp" stateCount="4"/>
  <Style name="entry" textColor="#FFF99D" backgroundColor="#000000" fontSize="14"/>

  <List name="history" x="40" y="45" width="310" height="150"/>
  <TextField name="message" x="40" y="216" width="299" height="22"
             style="entry" placeholder="Type a message..." maximumLength="120"/>
  <Button name="sendButton" x="345" y="212" image="send"/>
</UIScript>
```

See [`chatdialog.xml`](../Sources/hudini-demo/Resources/chatdialog.xml) and
[`livepanel1024.xml`](../Sources/hudini-demo/Resources/livepanel1024.xml) for
complete examples.

## Document rules

- Documents must be UTF-8 and well-formed XML.
- `DOCTYPE` declarations are not allowed, which also rules out custom entities.
  The five standard entities, such as `&lt;`, work as usual.
- Every element is a direct child of `<UIScript>`, in any order. Elements do not
  nest and hold no text. Text goes in attributes.
- Controls draw in document order, with later controls on top. Visuals draw
  before all controls.
- Names are unique among controls and visuals together, and within each kind of
  resource. A control and an image may share a name.

## Root

`<UIScript>` takes two optional attributes:

| Attribute | Value |
| --- | --- |
| `version` | The format version, which defaults to `1`. |
| `requires` | Space-separated features a reader must understand. |

## Window

Exactly one `<Window>` is required. It gives the interface's size in pixels.

| Attribute | Required | Value |
| --- | --- | --- |
| `width`, `height` | Yes | The size. Both must be positive. |
| `minWidth`, `minHeight` | No | The smallest resizable size. Give both or neither. Not yet used by `UIScriptView`. |

## Resources

`<Image>` refers to an image the host loads. It needs a `path`, an `assetID`, or
both. The host's `loadImage` closure receives the resource and decides which to
use. An asset ID stays exactly as written.

| Attribute | Required | Value |
| --- | --- | --- |
| `name` | Yes | The name other elements use. |
| `path` | One of these | A host-defined path. |
| `assetID` | One of these | A host-defined identifier. |
| `stateCount` | No | `1` (the default) or `4`. |

A four-state image holds four equal-width slices, left to right: normal, pressed,
hovered, and disabled. An image with one state shows it whatever the button's
state.

`<String>` refers to localized text the host supplies through `resolveString`.

| Attribute | Required | Value |
| --- | --- | --- |
| `name` | Yes | The name other elements use. |
| `table` | Yes | A host-defined string table. |
| `index` | Yes | The string's index in that table. |

## Styles

`<Style>` is a named set of visual properties that controls refer to. Colors are
`#RRGGBB` or `#RRGGBBAA`.

| Attribute | Value |
| --- | --- |
| `name` | Required. The name controls use. |
| `textColor`, `backgroundColor`, `borderColor` | Colors used when drawing. |
| `selectedTextColor`, `highlightedTextColor`, `disabledTextColor` | Colors that are read but not yet drawn. |
| `fontSize` | A positive size in pixels. |

## Position and size

Visuals and controls share these attributes:

| Attribute | Required | Value |
| --- | --- | --- |
| `x`, `y` | Yes | The position within the window, which may be negative. |
| `width`, `height` | See below | The size, which must not be negative. |
| `edgeOffsetLeft`, `edgeOffsetRight`, `edgeOffsetTop`, `edgeOffsetBottom` | No | Distances to the window edges for resizing. Not yet used by `UIScriptView`. |

A button or visual with an image may leave out `width`, `height`, or both to take
them from one slice of the image. Any other control needs both. If the host cannot
supply the image, the view uses a 24-pixel fallback and draws a red outline.

## Visuals

`<Visual>` is a decorative image. It takes `name` and `image`, which names an
`<Image>`, plus the position and size attributes.

## Controls

Every control takes `name` and the position and size attributes. All of these are
optional:

| Attribute | Value |
| --- | --- |
| `style` | The name of a `<Style>`. |
| `legacyID` | An integer identifier for host use or for `.uis` conversion. |
| `tooltip` | The name of a `<String>`. Read but not yet drawn. |

| Element | What it is | Extra attributes |
| --- | --- | --- |
| `<Text>` | Text at its position | `text` or `string` |
| `<FormattedText>` | Text on a background, with an inset | `text` or `string` |
| `<Button>` | A clickable button | `text` or `string`, `image`, `scrolls`, `direction` |
| `<TextField>` | A one-line text entry | `text` or `string`, `placeholder` or `placeholderString`, `maximumLength` |
| `<List>` | A scrollable list the host fills | `text` or `string`, shown as its first item |
| `<Slider>` | A scrollbar track and thumb | `scrolls` |
| `<Region>` | A rectangle the host draws into | None |

- **`text` and `string`:** `text` is literal, and `string` names a `<String>`. A
  control takes one or the other, and `placeholder` and `placeholderString` work
  the same way.
- **`maximumLength`:** the most characters a text field accepts, which defaults
  to 256.
- **`scrolls`:** names the `<List>` a slider or button scrolls.
- **`direction`:** `up` or `down`. A button with `scrolls` needs it, and a slider
  must not have it.

## Compatibility

A reader treats newer documents like this:

| What the reader finds | What it does |
| --- | --- |
| A `version` newer than it supports | Refuses the document with `unsupportedVersion`. |
| A `requires` feature it does not know | Refuses the document with `unsupportedFeature`. |
| An attribute it does not know | Ignores it and lists it in `ignoredAttributes`. |
| An element it does not know | Refuses the document with `unknownElement`. |

These rules set how the format can grow:

- A new attribute that is safe to ignore needs no version change.
- A new attribute or element that older readers must understand gets a name in
  `requires`. New elements always stop older readers, because skipping one could
  leave an interface silently incomplete.
- `version` only increases when existing documents or meanings change.

A misspelled attribute also lands in `ignoredAttributes` rather than failing, so
hosts should log that list during development:

```swift
let script = try UIScript(contentsOf: url)
for ignored in script.ignoredAttributes {
    print("Line \(ignored.line): \(ignored.element) ignores '\(ignored.attribute)'.")
}
```

The current reader supports version 1 and has no `requires` features yet.

## Errors

`UIScript(data:)` and `UIScript(contentsOf:)` throw `UIScriptError`, whose
`localizedDescription` explains the problem and includes the line number when it
relates to one element. Loading either returns a complete, valid document or
throws. There is no partial result.

## Host responsibilities

```swift
let view = UIScriptView(
    script: script,
    resolveString: { strings[$0.index] ?? "" },
    loadImage: { loadTexture(for: $0) }
)
guard let history = view.list(named: "history") else { /* report it */ }
history.items = messages

// Each frame:
for event in view.update(at: origin) { /* handle .pressed and .submitted */ }
view.draw(at: origin) { name, bounds in /* draw into regions */ }
```

- Create the view after `InitWindow` when passing `loadImage`, and keep it.
- Own the textures, and unload them before `CloseWindow`.
- Check `view.missingImages` to find images that could not be supplied.
- Show and hide controls with `setHidden(_:named:)`, and disable buttons with
  `setDisabled(_:named:)`.
- Draw any window frame or background behind the view.

## Platform requirements

On Linux, `XMLParser` comes from `FoundationXML`, which links the system's
`libxml2.so.2` at runtime. Games shipping on Linux need that library installed or
bundled.

## Not yet supported

- Reading `.uis` files, which is planned after the current roadmap
- Drawing tooltips and slider images
- Dragging a slider's thumb
- Text alignment
- Resizing through edge offsets
