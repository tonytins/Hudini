# UIScript Format

A UIScript document is an XML file describing one interface: its window size,
resources, styles, decorative images, and controls. `UIScript` reads it and
`UIScriptView` builds, updates, and draws it.

UIScript describes presentation. The host game owns live data, actions, images,
and localized text. The format is inspired by The Sims Online's `.uis` files.
Those are not valid XML, so Hudini has a [separate reader](#reading-uis-files) for
them that produces the same model.

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
| `stateCount` | No | `1` (the default), `4`, or `6`. |

A four-state image holds four equal-width slices, left to right: normal, pressed,
hovered, and disabled. An image with one state shows it whatever the button's
state. Some Maxis images hold six slices, and Hudini uses the first four.

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
| `selectedTextColor`, `highlightedTextColor`, `disabledTextColor` | Button label colors while pressed, hovered, and disabled. |
| `fillColor` | The filled part of a progress bar and the thumb of a slider. |
| `fontSize` | A positive size in pixels. |

## Position and size

Visuals and controls share these attributes:

| Attribute | Required | Value |
| --- | --- | --- |
| `x`, `y` | Yes | The position within the window, which may be negative. |
| `width`, `height` | See below | The size, which must not be negative. |
| `edgeOffsetLeft`, `edgeOffsetRight`, `edgeOffsetTop`, `edgeOffsetBottom` | No | Distances to the window edges. |

An edge offset replaces the position on its axis. `edgeOffsetRight` alone anchors
a control to the right edge, and `edgeOffsetLeft` with `edgeOffsetRight` stretches
it between both. Top and bottom work the same way. Offsets measure from the
document's window size until the host calls `setWindowSize(_:)`.

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
| `tooltip` | The name of a `<String>`, shown when the pointer rests on the control. |

| Element | What it is | Extra attributes |
| --- | --- | --- |
| `<Text>` | Text at its position | `text` or `string`, `alignment` |
| `<FormattedText>` | Text on a background, with an inset | `text` or `string`, `alignment` |
| `<Button>` | A clickable button | `text` or `string`, `image`, `scrolls`, `direction` |
| `<TextField>` | A one-line text entry | `text` or `string`, `placeholder` or `placeholderString`, `maximumLength`, `readOnly` |
| `<List>` | A scrollable list the host fills | `text` or `string`, shown as its first item |
| `<Slider>` | A draggable thumb on a track | `scrolls`, `minValue`, `maxValue`, `orientation` |
| `<ProgressBar>` | A bar filled in proportion to a value | `minValue`, `maxValue` |
| `<Region>` | A rectangle the host draws into | None |

- **`text` and `string`:** `text` is literal, and `string` names a `<String>`. A
  control takes one or the other, and `placeholder` and `placeholderString` work
  the same way.
- **`alignment`:** `left`, `center`, or `right`, which defaults to `left`.
- **`maximumLength`:** the most characters a text field accepts, which defaults
  to 256.
- **`readOnly`:** `true` or `false`, which defaults to `false`. A read-only text
  field never takes focus or typing, and the host can still set its text.
- **`scrolls`:** names the `<List>` a slider or button scrolls. A slider with
  `scrolls` always runs top to bottom and has no value of its own.
- **`minValue` and `maxValue`:** the values a slider or progress bar covers, which
  default to `0` and `1`. It starts at the lowest.
- **`orientation`:** `horizontal` or `vertical`. Without it, a slider runs along
  its longer side.
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
    resolveString: catalog.text(for:), // Or any closure. See "Reading CST text".
    loadImage: { loadTexture(for: $0) }
)
guard let history = view.list(named: "history") else { /* report it */ }
history.items = messages

// Each frame:
for event in view.update(at: origin) { /* handle .pressed, .submitted, and .changed */ }
view.draw(at: origin) { name, bounds in /* draw into regions */ }
view.drawTooltip(at: origin) // After every view, so nothing covers it.
```

- Create the view after `InitWindow` when passing `loadImage`, and keep it.
- Own the textures, and unload them before `CloseWindow`.
- Check `view.missingImages` and `view.missingStrings` to find what could not be
  supplied. A missing string shows its table and index instead.
- Show and hide controls with `setHidden(_:named:)`, disable buttons with
  `setDisabled(_:named:)`, and mark toggles or choices with `setSelected(_:named:)`.
- Call `setWindowSize(_:)` when the space around anchored controls changes.
- Slide or move a whole view by changing the `origin` passed to `update(at:)` and
  `draw(at:)`.
- Change text at runtime with `setText(_:named:)`, and the value of a slider or
  progress bar with `setValue(_:named:)`. Both are cheap enough to call every frame.
- Place something the document leaves to the game with `setBounds(_:named:)`.
- Use `containsPoint(_:origin:)` to keep a click on the interface from also
  reaching the game behind it. It covers visible controls and visuals, so a
  background the host draws itself needs its own check. When views overlap, the
  host decides which one gets the pointer.
- Draw any window frame or background behind the view.

### Panels inside panels

A view has no opinion about where it goes, so hosts compose them without a
container type. To swap a control panel between modes, keep one view per mode and
update and draw only the active one, calling `clearFocus()` on the one going away.
To put one interface inside another, hide the parent's controls it replaces and
draw the child at a position inside the parent. To give the same interface its own
window, draw it in a `WindowFrame`'s content instead. The host decides which view
gets the pointer when they overlap, and `drawTooltip(at:)` shows nothing for a view
that was not updated that frame.

## Platform requirements

On Linux, `XMLParser` comes from `FoundationXML`, which links the system's
`libxml2.so.2` at runtime. Games shipping on Linux need that library installed or
bundled.

## Reading `.uis` files

`UIScript(uisData:)` and `UIScript(uisContentsOf:)` read Maxis' `.uis` format into
the same model, so `UIScriptView` draws the result like any other document. See
[`debugbar.uis`](../Sources/hudini-demo/Resources/debugbar.uis) for an original
example.

| `.uis` | Becomes |
| --- | --- |
| `DefineImage` | `<Image>`. Images used by `AddButton` have four states unless `ImageStates` says otherwise. |
| `DefineString` | `<String>`, whose table is `stringDir:stringTable`. |
| `AddText`, `AddFormatedText`, `AddButton` | `<Text>`, `<FormattedText>`, `<Button>` |
| `AddTextEdit`, `AddListBox`, `AddSlider` | `<TextField>`, `<List>`, `<Slider>` |
| `AddProgressBar` | `<ProgressBar>` |
| `SetControlProperties "DialogSize"` | `<Window>`. Without one, the window fits the sizes the file states, which leaves out any size that comes from an image. |
| `SetControlProperties` | A setting, available from `setting(named:)`. |
| `SetControlProperties` with an `image` and `position` | Also a hidden `<Visual>`. |
| `SetControlProperties` with a `position` and `size` | Also a hidden `<Region>`. |
| `Begin`, `End`, `SetSharedProperties` | Copied onto each control in the scope. |

A control's colors and font become a `<Style>` named after it. Names ignore case,
as they do in real files, and `id` becomes `legacyID`.

### Settings

Game code gives `SetControlProperties` entries their meaning. They hold alternate
art, animation frames, and positions that code applies when it needs them, so
nothing from one draws until the host asks. Show a visual or region with
`setHidden(false, named:)`, and read anything else from the setting:

```swift
let setting = script.setting(named: "PanelPosition") // Names ignore case.
let position = setting?.position
let columns = setting?.number("pageSize")
let colors = setting?.numbers("normal") // A tuple such as (255,249,157).
```

### What gets reported

A `.uis` file relies on game code for much of its meaning, so the reader is more
forgiving than the XML parser. Only broken syntax throws, such as an unclosed tag
or an unmatched `<End>`. Everything else is reported, and hosts should check both
lists:

- `conversionNotes` lists tags and values with no faithful equivalent, such as a
  reference to an undefined image or a control with no size.
- `ignoredAttributes` lists attributes the model has no place for, such as
  `tracking` or `opaque`.

Scroll bindings do not exist in `.uis`, so a slider or scroll button read from one
is not connected to a list. Only `alignment=3`, which centers, is understood. See
the [roadmap's open questions](ROADMAP.md#open-questions) for what remains unknown.

## Reading CST text

The Sims Online keeps its interface text in `.cst` tables, which `.uis` files refer
to by table and index. `CSTCatalog` loads a directory of them once, so lookups never
touch the disk:

```swift
let catalog = try CSTCatalog(gameData: installURL.appendingPathComponent("gamedata"))
let view = UIScriptView(script: script, resolveString: catalog.text(for:))
let greeting = catalog.text(table: 174, key: "1", arguments: ["Maya"])
```

`CSTCatalog(gameData:language:)` finds either install layout. New & Improved uses
`uitext/<language>.dir`, and earlier versions have one language in `uitext.dir`. For
any other location, `CSTCatalog(directory:)` reads files named `_<id>_<name>.cst`. It
uses only the number at the end of a resource's table, so `UIText:174` and `174`
mean the same table.

### The format

```text
// A comment, as is a line starting with # or a /* */ block.
1 ^A value after its key^
    2 ^An indented key^
3
^A key above its value^
4 ^A value that runs
across lines^
ok button ^A key with spaces^
These words are a note, because no caret follows them on this line.
^A value with no key^
```

- **Values with no key** are known by their position among all the table's entries,
  counting from 0. More than 1,000 entries in each TSO version work this way. The
  value above is at position 6, and `text(table:key:)` finds it with the key `"6"`.
- **Notes:** text between entries is for translators. A number alone on the line
  above a value is its key, and anything else there does not count.
- **Encoding:** UTF-8 with or without a byte order mark, then Windows-1252.
- **Problems:** reading a table does not fail. A value with no closing caret is
  skipped, and a repeated key keeps its first value. `CSTFile.problems` lists both.
  An unclosed value still takes up a position.
- **References:** some New & Improved entries start with a control character and
  point to an entry in another table, such as
  `<cst><cst_id>276</cst_id><string_id>1</string_id></cst>`. `text(table:key:arguments:)`
  returns the target's text and follows only one reference.
- **Placeholders:** `CSTCatalog.format(_:with:)` fills `%s`, `%d`, `%i`, `%u`, and
  `%ld` in order. `%3d` pads with spaces, `%03d` and `%.3d` pad with zeros, and `%%`
  is one percent sign. A placeholder with no argument left stays as written, and
  any other `%` is left alone. References pass their arguments in order, ignoring
  the `arg` numbers they carry.

## Not yet supported

- Drawing slider images, which `.uis` sliders name and the view replaces with a
  plain track and thumb
- Enforcing `minWidth` and `minHeight`, which the host currently owns
