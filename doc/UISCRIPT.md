# UIScript Format

A UIScript document is an XML file describing one interface: its window size,
resources, styles, decorative images, and controls. `UIScript` reads it and
`UIScriptView` builds, updates, and draws it.

UIScript describes presentation. The host game owns live data, actions, images,
and localized text. The format is inspired by The Sims Online's `.uis` files.
Those are not valid XML, so Hudini has a [separate reader](#reading-uis-files) for
them that produces the same model.

## Status

**Draft.** This spec changes on Hudini's `main` branch as games need it, rather
than in numbered releases. Additions land here once a host has built and tested
them, and the [change log](#change-log) dates each one so other readers can catch
up. Hudini's reader follows this document, and other readers, such as VentureOS's,
treat it as the reference.

While the format is a draft, `version` stays at `1`. Optional parts of the format
are [modules](#modules) that a document names in `requires`, so a host can leave
one out entirely and still refuse documents that need it.

## Files

UIScript documents use the `.uix` extension. The contents are XML, so `.uix` only
says which format it is, and keeps documents apart from Maxis' `.uis` files. A
reader must not depend on the extension: Hudini's reads any file it is given, and
documents named `.xml` still load.

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

See [`chatdialog.uix`](../Sources/hudini-demo/Resources/chatdialog.uix) and
[`livepanel1024.uix`](../Sources/hudini-demo/Resources/livepanel1024.uix) for
complete examples.

## Document rules

- Documents must be UTF-8 and well-formed XML.
- `DOCTYPE` declarations are not allowed, which also rules out custom entities.
  The five standard entities, such as `&lt;`, work as usual.
- Every element is a direct child of `<UIScript>`, in any order. Elements do not
  nest and hold no text. Text goes in attributes.
- Controls draw in document order, with later controls on top. Visuals draw
  before all controls.
- Names are unique among controls, visuals, title bar elements, and module
  elements such as menus, and within each kind of resource. A control and an
  image may share a name.

## Root

`<UIScript>` takes two optional attributes:

| Attribute | Value |
| --- | --- |
| `version` | The format version, which defaults to `1`. It stays `1` while the format is a draft. |
| `requires` | Space-separated [modules](#modules) the document uses. |

## Window

Exactly one `<Window>` is required. It gives the interface's size in pixels.

| Attribute | Required | Value |
| --- | --- | --- |
| `width`, `height` | Yes | The size. Both must be positive. |
| `minWidth`, `minHeight` | No | The smallest size the view lays out at. Give both or neither. |

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
| `fontSize` | A positive size in pixels. Without one, text uses the theme's `body` size. |
| `font` | `interface` (the default) or `monospace`, a fixed-width typeface for code and terminals. The host picks the actual fonts. Any other value refuses the document. |

A reader that ignores `font` draws the text in the interface font, which is
plainer but still correct.

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
document's window size until the host calls `setWindowSize(_:)`, and never from less
than `minWidth` and `minHeight`.

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
| `<TextField>` | A one-line text entry | `text` or `string`, `placeholder` or `placeholderString`, `maximumLength`, `readOnly`, `secure` |
| `<TextArea>` | A multi-line text entry | `text` or `string`, `placeholder` or `placeholderString`, `maximumLength`, `readOnly`, `follows` |
| `<List>` | A scrollable list the host fills | `text` or `string`, shown as its first item, `selectable` |
| `<Slider>` | A draggable thumb on a track | `scrolls`, `minValue`, `maxValue`, `orientation` |
| `<ProgressBar>` | A bar filled in proportion to a value | `minValue`, `maxValue` |
| `<Region>` | A rectangle the host draws into | None |

- **`text` and `string`:** `text` is literal, and `string` names a `<String>`. A
  control takes one or the other, and `placeholder` and `placeholderString` work
  the same way.
- **`alignment`:** `left`, `center`, or `right`, which defaults to `left`.
- **`maximumLength`:** the most characters a text field or text area accepts,
  which defaults to 256 for a field and 65,536 for an area.
- **`readOnly`:** `true` or `false`, which defaults to `false`. A read-only text
  field or text area never takes focus or typing, and the host can still set its
  text.
- **`secure`:** `true` or `false`, which defaults to `false`. A secure text field
  draws `*` in place of each character, as a password field does. The host still
  reads the real text from it.
- **`selectable`:** `true` or `false`, which defaults to `false`. A list without it
  is a log: it opens on its newest items and stays at the end as items arrive. A
  selectable list is a pick list: it opens on its first items, stays where it is
  when items change, highlights one item, and reports a click on a different item
  as `selected`. Double-clicking an item reports `submitted` with the item's
  text, after the first click has selected it, so a host reads the index from the
  list's selection. Two presses on the same item count as a double-click when
  they come close enough together; the host picks the time, and 500 ms matches
  common desktops. A reader that ignored this attribute would still show the
  items.
- **`follows`:** `true` or `false`, which defaults to `false`, and only on a
  `<TextArea>`. When its text changes while it's scrolled to its last line, it
  stays at the last line, as a log list does. Scrolled back, it stays put. A
  terminal uses it.
- **`scrolls`:** names the `<List>` or `<TextArea>` a slider or button scrolls. A
  slider with `scrolls` always runs top to bottom and has no value of its own.
- **`minValue` and `maxValue`:** the values a slider or progress bar covers, which
  default to `0` and `1`. It starts at the lowest.
- **`orientation`:** `horizontal` or `vertical`. Without it, a slider runs along
  its longer side.
- **`direction`:** `up` or `down`. A button with `scrolls` needs it, and a slider
  must not have it.

### Text areas

A `<TextArea>` takes typing across several lines. Enter adds a line break rather
than submitting, and the starting `text` may hold line breaks, written `&#10;`.
It wraps at spaces, scrolls with the wheel and with a bound slider or buttons, and
keeps the caret in view. `secure` and `selectable` refuse the document on it.

The host reads and sets an area's text by name. A reader may also report typing,
such as with `changed` and the text, but hosts shouldn't rely on it: Hudini
doesn't report it.

It's an element rather than a `multiline` attribute on `<TextField>` because an
older reader ignores unknown attributes. It would show a one-line field where
Enter submits, which silently changes behavior. An unknown element refuses the
document instead.

## Title bar

A document can describe what goes in its window's title bar. The host's window
frame draws the bar: its height, its close and minimize buttons, the title, and
dragging. Positions in the document are still the content's, below the bar, so
adding these moves nothing.

```xml
<UIScript version="1">
  <Window width="480" height="300"/>
  <ToolbarItem name="back" title="Back"/>
  <ToolbarItem name="go" title="Go"/>
  <TitleField name="address" placeholder="Path"/>
  ...
</UIScript>
```

`<ToolbarItem>` is a button on the bar. It takes `name` and `title`, both
required. Items run along the bar's right end in document order, the last at the
right edge. A click reports `pressed` with its name, as a button does. A host
decides whether that happens on the press or the release, as it does for its
buttons: Hudini reports both on the press, and VentureOS on the release. `setDisabled(_:named:)` dims an item, and
`setSelected(_:named:)` shows it held down, so items can work as tabs.

`<TitleField>` makes the title editable, as an address bar is. It takes `name`,
which is required, and `placeholder`. A document has at most one. While the title
field is empty, the bar shows the placeholder in place of a title.

The `title` and `placeholder` of these elements are literal text. They don't take
string references yet.

- A click starts an edit. Enter reports `submitted` with the text, and Esc or a
  click elsewhere puts the old text back.
- A click on one of the same window's toolbar items keeps the edit, so an item
  such as Go acts on what was typed.
- The host reads and sets it by name, as it does a text field. While an edit is
  under way, reading it gives what has been typed so far.
- `setDisabled(_:named:)` stops it being edited.

A host that shows a document without a title bar doesn't draw either element.
They aren't errors there.

In Hudini, a `WindowFrame` made with `WindowFrame(view:)` draws them. It wraps the
view: `updateWindow(in:)` handles dragging, the bar, and the view, and returns one
list of events, and `draw(in:)` draws the frame and the view. A toolbar item or the
title field reports as the view's own event, wrapped in `.view`, and the close and
minimize buttons report `.closeRequested` and `.minimizeRequested`, leaving the host
to decide what they mean. The minimize button is off until `showsMinimizeButton` is
set. A `UIScriptView` drawn on its own ignores both elements.

## Events

Controls report what the player does as events carrying the control's name.

| Event | Reported when |
| --- | --- |
| `pressed` | A button, toolbar item, or menu item is chosen. |
| `submitted` | Enter is pressed in a text field or title field, with its text, or an item in a selectable list is double-clicked, with the item's text. |
| `changed` | A slider without a scroll binding moves, with its value. |
| `selected` | A click on a selectable list or sidebar picks a different row, with its index. |

A handler checks the kind, so `submitted` from a list and from a field are told
apart by name.

## Compatibility

The format has two parts:

- **The core** is everything a reader implements. During the draft it grows on
  `main` without a version change or a `requires` name. Each game ships its
  documents with its own copy of Hudini, so a document doesn't normally reach a
  reader older than it.
- **Modules** are optional parts a host may never implement, such as a menu bar
  that only some hosts have. A document that uses one names it in `requires`.

To decide where an addition goes, ask whether a reasonable host could leave it
out entirely. If it could, the addition is a module. If every host should have
it, it's core, even when some documents never use it.

A reader treats documents it doesn't fully understand like this:

| What the reader finds | What it does |
| --- | --- |
| A `version` newer than it supports | Refuses the document with `unsupportedVersion`. |
| A `requires` module it does not implement | Refuses the document with `unsupportedFeature`. |
| An attribute it does not know | Ignores it and lists it in `ignoredAttributes`. |
| An element it does not know | Refuses the document with `unknownElement`. |

These rules set how the format grows:

- A new core attribute must be safe for an older reader to ignore, giving a
  plainer but still correct interface. If ignoring it would silently change
  behavior, add an element instead.
- New elements always stop older readers, because skipping one could leave an
  interface silently incomplete.
- A module's elements and attributes refuse the document unless it names the
  module in `requires`.
- `version` only increases when existing documents or meanings change, which
  the draft avoids.

A misspelled attribute also lands in `ignoredAttributes` rather than failing, so
hosts should log that list during development:

```swift
let script = try UIScript(contentsOf: url)
for ignored in script.ignoredAttributes {
    print("Line \(ignored.line): \(ignored.element) ignores '\(ignored.attribute)'.")
}
```

### Modules

| Module | What it adds |
| --- | --- |
| [`menus`](#menus) | Menus for a global menu bar |
| [`sidebar`](#sidebar) | A list of places down the window's left |

A host should list the modules it implements. Hudini's reader supports version 1
and implements no modules yet. VentureOS implements both.

### Menus

A document can describe the menus its interface puts in a global menu bar, as a
desktop shows the focused app's menus along the top of the screen.

```xml
<UIScript version="1" requires="menus">
  <Window width="400" height="300"/>

  <Menu name="notesMenu" title="Notes" hotkey="N"/>
  <MenuItem menu="notesMenu" name="newNote" title="New Note" hotkey="N" shortcut="Ctrl+N"/>
  <MenuSeparator menu="notesMenu"/>
  <MenuItem menu="notesMenu" name="clearAll" title="Clear All Notes" hotkey="C"/>

  <List name="notes" x="10" y="10" width="380" height="250" selectable="true"/>
</UIScript>
```

An item names the menu it belongs to, as a slider names the list it scrolls.
Items and separators appear in a menu in document order, and menus appear in the
bar in document order.

`<Menu>` is one drop-down menu.

| Attribute | Required | Value |
| --- | --- | --- |
| `name` | Yes | The name items use to join it. |
| `title` | Yes | The text in the menu bar. |
| `hotkey` | No | One letter or digit. With Alt held, it opens the menu. |
| `role` | No | `file`, `edit`, `view`, or `help`: the host's standard menu this one adds to. |

`<MenuItem>` is a choice in a menu.

| Attribute | Required | Value |
| --- | --- | --- |
| `menu` | Yes | The name of a `<Menu>`. |
| `name` | Yes | The name the host uses for it, as for a control. |
| `title` | Yes | The text in the menu. |
| `hotkey` | No | One letter or digit that picks it while its menu is open. |
| `shortcut` | No | A key combination that picks it from anywhere, such as `Ctrl+N` or `Ctrl+Shift+S`. |

`<MenuSeparator>` is a line between groups of items. It takes `menu` only.

Rules:

- A menu may be empty.
- Menus use different `hotkey`s from each other, as do the items in one menu,
  ignoring case.
- A `shortcut` is `Ctrl`, `Alt`, and `Shift` in any combination, each at most
  once and joined with `+`, then one letter or digit. It needs `Ctrl` or `Alt`,
  so typing into a text field never triggers it. No two items in a document use
  the same shortcut, ignoring case.
- An item that names an undeclared menu, or a menu element in a document without
  `requires="menus"`, refuses the document.
- A `role` the reader doesn't know is ignored and listed in `ignoredAttributes`,
  so the menu shows as the document's own.

A host that implements menus:

- Shows the focused interface's menus in the bar, after any menus of its own.
- Reports a chosen item as `pressed` with the item's name.
- Disables items with `setDisabled(_:named:)` and checks them with
  `setSelected(_:named:)`, as for controls.
- Draws `hotkey` and `shortcut` in the menu so people can learn them.
- May keep shortcuts for its own menus, such as Ctrl+Q to quit. Those win over a
  document's, so a host should list the ones it keeps.
- If it has standard menus, merges a document's menu into the one its `role`
  names, the document's items first. A menu without a `role` whose title is
  exactly `File`, `Edit`, `View`, or `Help` merges the same way. A standard item
  yields to a document's item with the same shortcut.

### Sidebar

A document can give its window a sidebar: a list of places down the left, such as
a file manager's bookmarks.

```xml
<UIScript version="1" requires="sidebar">
  <Window width="360" height="300"/>

  <Sidebar name="places" width="130"/>

  <List name="entries" x="10" y="10" width="340" height="280" selectable="true"/>
</UIScript>
```

`<Sidebar>` takes `name` and `width`, both required, and a document has at most
one. It has no position: it sits beside the content rather than in it, so
`<Window>`'s size and every control's position are the content's, and adding a
sidebar moves nothing. A `<Sidebar>` in a document without `requires="sidebar"`,
a second one, or a width that isn't positive refuses the document.

A host that implements sidebars:

- Draws it at the window's left, the window's full height, and makes the window
  wider by its width.
- Treats it as a selectable list of one-line rows under its name: it fills it,
  selects a row, and reports `selected`, as for `<List selectable="true">`.
- Sets it apart from the content, such as with its own shade, and marks the
  selected row.

## Errors

`UIScript(data:)` and `UIScript(contentsOf:)` throw `UIScriptError`, whose
`localizedDescription` explains the problem and includes the line number when it
relates to one element. Loading either returns a complete, valid document or
throws. There is no partial result.

## Host responsibilities

```swift
let view = UIScriptView(
    script: script,
    resolveString: { resource in text(for: resource) }, // See "Reading CST text".
    loadImage: { loadTexture(for: $0) }
)
guard let history = view.list(named: "history") else { /* report it */ }
history.items = messages

// Each frame:
for event in view.update(at: origin) { /* handle .pressed, .submitted, .changed, and .selected */ }
view.draw(at: origin) { name, bounds in /* draw into regions */ }
view.drawTooltip(at: origin) // After every view, so nothing covers it.
```

- Create the view after `InitWindow` when passing `loadImage`, and keep it.
- Own the textures, and unload them before `CloseWindow`.
- Check `view.missingImages` and `view.missingStrings` to find what could not be
  supplied. A missing string shows its table and index instead.
- Show and hide controls with `setHidden(_:named:)`, disable buttons with
  `setDisabled(_:named:)`, and mark toggles or choices with `setSelected(_:named:)`.
- Call `setWindowSize(_:)` when the space around anchored controls changes, then size
  the window around the view from `windowSize`. A size below the document's minimum
  uses the minimum on that axis.
- Slide or move a whole view by changing the `origin` passed to `update(at:)` and
  `draw(at:)`.
- Read or set a selectable list's choice through its `selectedIndex`. The host's
  own `items` are the source of what the index means, and setting it reports no
  event.
- Change text at runtime with `setText(_:named:)`, and the value of a slider or
  progress bar with `setValue(_:named:)`. Both are cheap enough to call every frame.
- Open a window ready for typing with `textField(named:)?.setFocused(true)`, or
  `textArea(named:)?.setFocused(true)`, after taking focus from any other view with
  `clearFocus()`.
- Read what was typed in a text area with `text(named:)`, since typing reports no
  event.
- Place something the document leaves to the game with `setBounds(_:named:)`.
- Use `containsPoint(_:origin:)` to keep a click on the interface from also
  reaching the game behind it. It covers visible controls and visuals, so a
  background the host draws itself needs its own check. When views overlap, the
  host decides which one gets the pointer.
- Draw any window frame or background behind the view.
- Choose the fonts, default text sizes, and corners through the `InterfaceTheme`
  passed to the view. A document sets sizes through `<Style>`, and asks for the
  theme's `monospaceFont` with `font="monospace"`, but can't name a font file.

### Panels inside panels

A view has no opinion about where it goes, so hosts compose them without a
container type. To swap a control panel between modes, keep one view per mode and
update and draw only the active one, calling `clearFocus()` on the one going away.
To put one interface inside another, hide the parent's controls it replaces and
draw the child at a position inside the parent. To give the same interface its own
window, wrap it in `WindowFrame(view:)` instead. The host decides which view
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
to by table and index. Hudini leaves text to the host, so read them with
[SwiftCST](https://github.com/tonytins/swift-cst), which reads every version of the
game, and pass its lookup to the view:

```swift
import SwiftCST

let text = UIText(gameData: installURL.appendingPathComponent("gamedata"))
let view = UIScriptView(script: script, resolveString: { resource in
    // The table ID is the number at the end, so `UIText:174` and `174` mean the same table.
    guard let id = resource.table.split(separator: ":").last.flatMap({ Int($0) }) else {
        return nil
    }
    return try? text.textIfPresent(for: id, key: resource.index)
})
```

`textIfPresent` returns `nil` for missing text, which the view lists in
`missingStrings`. Use `try` instead of `try?` to report a table that can't be read.
`UIText(gameData:language:)` finds either install layout, and `UIText(directory:)`
reads a game's own folder of files named `_<id>_<name>.cst`. See the
[CST specification](https://github.com/tonytins/swift-cst/blob/main/doc/CST.md) for the format and how sure each rule is.

Hudini's `CSTCatalog` did this before, and is deprecated. It still works, so games can
move to SwiftCST in their own time: create a `UIText` the same way, and call
`textIfPresent` where you called `text`. It finds the same text.

## Not yet supported

Hudini's reader reads everything in this draft's core. It implements no modules
yet.

A text area's caret stays at the end of its text. Clicking to place it, moving it
with the arrow keys, selection, and the clipboard aren't supported yet.

It also doesn't draw slider images, which `.uis` sliders name and the view
replaces with a plain track and thumb.

## Change log

Newest first. Changes before the draft are in the repository's history.

- **2026-11-12:** A toolbar item's click follows the host's buttons, on the press
  or the release, rather than always on the release. The title bar's `title` and
  `placeholder` are literal text for now.
- **2026-11-12:** Added from VentureOS, which built and tested each of them
  first: `<TextArea>` and `follows`, `font` on `<Style>`, double-clicking a
  selectable list, the title bar's `<ToolbarItem>` and `<TitleField>`, the
  `menus` and `sidebar` modules, and an Events section.
- **2026-11-12:** Marked the format as a draft that changes on `main`, with
  `version` frozen at `1`. Documents use `.uix`. `requires` now names optional
  modules a host may never implement, rather than features newer than the reader.
