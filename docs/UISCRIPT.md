# UIScript in Hudini

A UIScript document is an XML file (`.uix`) describing one interface: its window
size, resources, styles, decorative images, and controls. `UIScript` reads it and
`UIView` builds, updates, and draws it. The host game owns live data, actions,
images, and localized text.

**The format's spec is
[VentureOS's](https://github.com/tonytins/VentureOS/blob/main/docs/uiscript/README.md).**
Hudini kept it until 2026-11-20, then handed it over: VentureOS is an operating
system and needs more from its interfaces than a game does, such as menus a global
menu bar merges, sidebars, and panes. Hudini reads a **subset** of the format, the
parts a game needs, and follows the spec's rules for everything else, so a document
it can't draw is refused rather than drawn wrong.

This page says what that subset is, and how a Swift host uses it. Hudini also reads
Maxis' `.uis` files into the same model; see [Reading `.uis` files](#reading-uis-files).

## What Hudini reads

| Part of the spec | Hudini |
| --- | --- |
| Document rules, the root, `version` | Yes. Version 1. |
| `<Window>`, with `minWidth`, `minHeight`, and `resizable` | Yes |
| `<Panel>` | Yes |
| `<Image>`, `<String>` | Yes |
| `<Style>`, with color roles, size roles, `dark` twins, and `font` | Yes |
| `<Visual>` | Yes |
| Controls: `<Text>`, `<FormattedText>`, `<Button>`, `<TextField>`, `<TextArea>`, `<List>`, `<Slider>`, `<ProgressBar>`, `<Region>` | Yes |
| Scroll bars on lists and text areas | Yes: the classic style, drawn by the control itself. See [Scroll bars and sliders](#scroll-bars-and-sliders). |
| `<Slider>`'s `step`, and the `committed` event | Yes |
| `alignment` on `<TextField>` and `<TextArea>` | Yes |
| `scrolls` and `direction` | Refused, as the spec says, since nothing scrolls by hand |
| `orientation` | Skipped and listed, as the spec says: a slider runs along its longer side |
| `<Shelf>`, `<Grid>`, `<StatusItem>` | No: refused as unknown elements |
| Title bar: `<ToolbarItem>` and `<TitleField>` | Yes |
| `<Tab>`, and `tab` on toolbar items | Yes |
| A window's `subtitle`, and toolbar items' `image` and `placement` | Skipped and listed, as unknown attributes: no subtitle, and every item is a text item at the right end |
| Menus: `<Menu>`, `<MenuItem>`, `<MenuSeparator>` | No: refused as unknown elements |
| `<Sidebar>` of panes | Yes |
| `<Sidebar>` with rows the host fills, or holding controls | No: refused (`UIScriptError.unsupportedSidebar`) |
| `edge` on `<Sidebar>` | Skipped and listed, as the spec says: the sidebar is on the left |
| `<Pane>`, nested or named by `pane` on controls | Yes |
| `requires` | Accepts `menus`, `sidebar`, `shelf`, and `panes`, the names of the old modules, which mean nothing (`UIScript.retiredFeatures`). Any other name refuses the document. |

An element outside the subset throws `UIScriptError.unknownElement`, whose message
says it's part of UIScript but outside what Hudini reads
(`UIScript.elementsOutsideSubset` lists them). Everything else, from the document
rules to which values refuse a document, is as the spec says.

An unknown attribute, such as a misspelled one or one outside the subset, lands in
`ignoredAttributes` rather than failing, so hosts should log that list during
development:

```swift
let script = try UIScript(contentsOf: url)
for ignored in script.ignoredAttributes {
    print("Line \(ignored.line): \(ignored.element) ignores '\(ignored.attribute)'.")
}
```

See [`chatdialog.uix`](../Demo/Sources/hudini-demo/Resources/chatdialog.uix) and
[`livepanel1024.uix`](../Demo/Sources/hudini-demo/Resources/livepanel1024.uix) for
complete examples. VentureOS's tests read copies of the demo's documents, so every
document Hudini reads reads the same there, except one with tabs: VentureOS refuses
`<Tab>` until it shows tabs. Leave a tabbed document out of those copies until then.

## Using a document

```swift
let view = UIView(
    script: script,
    resolveString: { resource in text(for: resource) }, // See "Reading CST text".
    loadImage: { loadTexture(for: $0) }
)
guard let history = view.list(named: "history") else { /* report it */ }
history.items = messages

// Each frame:
for event in view.update(at: origin) { /* handle .pressed, .submitted, .changed, .committed, and .selected */ }
view.draw(at: origin) { name, bounds in /* draw into regions */ }
view.drawTooltip(at: origin) // After every view, so nothing covers it.
```

- Create the view after `InitWindow` when passing `loadImage`, and keep it. The
  `loadImage` closure receives each `<Image>` and decides whether to use its `path`
  or its `assetID`.
- Own the textures, and unload them before `CloseWindow`.
- Check `view.missingImages` and `view.missingStrings` to find what could not be
  supplied. A missing string shows its table and index instead, and a missing image
  a 24-pixel stand-in with a red outline.
- Show and hide controls with `setHidden(_:named:)`, disable buttons and toolbar
  items with `setDisabled(_:named:)`, and mark toggles or choices with
  `setSelected(_:named:)`.
- A document's tabs switch themselves: pressing a toolbar item that names a tab
  shows that tab's controls in place of the others', and still reports `.pressed`.
  `selectedTab` says which is showing, and `setSelected(true, named:)` on a tab's
  item switches to it without an event. One tab is always selected, so deselecting
  its item does nothing. Hiding a control with `setHidden(_:named:)` is separate:
  switching tabs never shows what the host hid, and `isHidden(named:)` only reports
  what the host hid.
- Panes switch the same way from a `WindowFrame`'s sidebar: clicking a row shows
  that pane and reports `.selected` with the sidebar's name and the row's index.
  `selectedPane` says which is showing, and `setSelected(_:named:)` with a pane's
  name selects it, or, deselecting it, leaves no row selected, which shows only
  what's in no pane. Neither reports an event.
- Call `setWindowSize(_:)` when the space around anchored controls changes, then
  size the window around the view from `windowSize`. A size below the document's
  minimum uses the minimum on that axis.
- Slide or move a whole view by changing the `origin` passed to `update(at:)` and
  `draw(at:)`.
- Read or set a selectable list's choice through its `selectedIndex`. The host's
  own `items` are the source of what the index means, and setting it reports no
  event.
- Change text at runtime with `setText(_:named:)`, and the value of a slider or
  progress bar with `setValue(_:named:)`. Both are cheap enough to call every frame.
  A slider's value is kept in its range and on its `step`.
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
  theme's `monospaceFont` with `font="monospace"`, but can't name a font file. An
  [appearance](#fonts) can: it names font files, fills the theme's fonts, and gives
  shared styles fonts of their own.

### Scroll bars and sliders

A list or text area draws a classic scroll bar down its right edge once its content
doesn't fit, taking 15 pixels from the text while it shows. Its arrows scroll a line
and its track a page, both repeating while held, and its thumb drags. A press on a
bar belongs to it alone: it selects nothing, presses nothing, and leaves keyboard
focus where it was. The host scrolls one itself with `scroll(byLines:)` or
`scroll(toFraction:)` on the control from `list(named:)` or `textArea(named:)`.

A `<Slider>` chooses a value only. It runs along its longer side, so a tall one runs
bottom to top, and it snaps to its `step` when it has one. It reports `.changed` as
it moves, and `.committed` once when a drag ends, even unchanged, or after a key
moves it, so a game that wants only the final value, such as to recompute a budget,
listens for that.

A press on a slider gives it the keyboard, outlined in the accent: the arrows move
it a step, or a tenth of its range without one, and Home and End move it to its
ends. A press elsewhere, or `clearFocus()`, takes the keyboard away. Hudini can't
keep the game from seeing those keys too, so a game that uses them, such as to pan
its map, checks `focusedSlider` first:

```swift
if view.focusedSlider == nil {
    panCamera(with: arrowKeys)
}
```

### Styles

Roles resolve against the `InterfaceTheme` a view draws with: `text`,
`secondaryText`, `accent`, `panel`, `inputBackground`, and `border` are the theme's
properties of those names, `disabledText` is `secondaryText`, `highlightedText` is
`text`, and `selection` is `selectedItem`. The size roles are the theme's `tooltip`,
`body`, `title`, and `largeTitle` sizes (12, 14, 16, and 22 by default). A theme is
dark when its `isDark` says so, or, unless told, when its `panel` is dark; Hudini's
standard theme is dark. A `UIView` resolves its document's styles again whenever its
theme changes. A game reading colors out of its own document gets what was written
as hex from `Style`'s plain properties, and everything, roles included, from
`Style.resolved(in:)`.

### Panels

A panel's `UIScript` has a `panelEdge`, which is `nil` for a window, and its size is
in `window`. Stretch the view with `setWindowSize(_:)`, then
`panelOrigin(onScreen:x:)` gives where to update and draw it against its edge. A
panel's view isn't wrapped in a `WindowFrame`.

### Title bars

A `WindowFrame` made with `WindowFrame(view:)` draws the title bar's elements. It
wraps the view: `updateWindow(in:)` handles dragging, the bar, and the view, and
returns one list of events, and `draw(in:)` draws the frame and the view. A toolbar
item or the title field reports as the view's own event, wrapped in `.view`, and the
close and minimize buttons report `.closeRequested` and `.minimizeRequested`, leaving
the host to decide what they mean. Toolbar items report on the press. The minimize
button is off until `showsMinimizeButton` is set. Set the frame's `drawRegion` to
draw into the view's regions, since the frame, not the host, calls
`draw(at:drawRegion:)`. The frame also draws a resizable window's grip and resizes
the view by it, and `isResizing` says while it's being dragged. A `UIView` drawn on
its own ignores the title bar's elements and the grip.

A document's sidebar is the frame's too. The frame draws it down the window's left,
under the bar, makes the window wider by its width, and draws the view beside it,
at `viewBounds(in:)`; `WindowFrame.content(in:)` is still the whole area under the
bar. Resizing keeps the sidebar's width, and the view takes the rest. A view drawn
on its own doesn't draw its sidebar.

### Panels inside panels

A view has no opinion about where it goes, so hosts compose them without a container
type. To swap a control panel between modes, keep one view per mode and update and
draw only the active one, calling `clearFocus()` on the one going away. To put one
interface inside another, hide the parent's controls it replaces and draw the child
at a position inside the parent. To give the same interface its own window, wrap it
in `WindowFrame(view:)` instead, and give several such windows to a `WindowManager`
to stack them. The host decides which view gets the pointer when they overlap, and
`drawTooltip(at:)` shows nothing for a view that was not updated that frame.

## Appearances

A game's windows usually share a look: the same scroll bar art, the same text styles.
An **appearance** is one document holding what they share, which the game loads once
and reads every window with. It's a Hudini feature, not part of the UIScript spec; the
[design note](design/2026-11-25-appearance.md) explains why and how.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Appearance version="1">
  <Image name="scrollUp" path="scroll/up.png" stateCount="4"/>
  <Image name="scrollDown" path="scroll/down.png" stateCount="4"/>
  <Image name="scrollThumb" path="scroll/thumb.png"/>
  <ScrollBar width="15" up="scrollUp" down="scrollDown" thumb="scrollThumb" thumbCap="6"/>
  <Style name="chatText" textColor="#FFF99D" fontSize="body"/>
</Appearance>
```

```swift
let appearance = try Appearance(contentsOf: appearanceURL)
let chat = try UIScript(contentsOf: chatURL, appearance: appearance)
let view = UIView(script: chat, loadImage: textures.load) // Cache: windows share images.
```

- It holds UIScript's own `<Image>`, with `path`, `assetID`, or both, and `<Style>`,
  and at most one `<ScrollBar>`. Its rules are a window's: no text, no `DOCTYPE`,
  elements directly under the root, unknown attributes listed in
  `ignoredAttributes`, and a newer `version` refused.
- A window's `style` and `image` references it doesn't define itself come from the
  appearance, and a window with a list or text area takes its `<ScrollBar>` as
  `UIScript.scrollBar`. Only what a window uses is copied into it, and `UIView`
  loads those images through `loadImage` like its own.
- **A window overrides by name.** Its own `<Image>` or `<Style>` replaces the
  appearance's of that name, whole. To give one window its own scroll bar art,
  define an `<Image>` with the name the `<ScrollBar>` uses.
- A window that leans on shared names doesn't read without the appearance, in
  Hudini or in VentureOS, which refuses the names it can't find.

`<ScrollBar>` takes these attributes, all optional:

| Attribute | Value |
| --- | --- |
| `width` | The bar's width in pixels, above 0, which defaults to 15. The arrows are as tall as the bar is wide. |
| `up`, `down` | The arrows' images. With four states, they show normal, pressed, hovered, and disabled; an arrow shows disabled at its end. |
| `thumb` | The thumb's image, stretched to the thumb's length. |
| `thumbCap` | Pixels at the thumb image's top and bottom that keep their height while its middle stretches. Defaults to 0, which stretches it whole. |
| `track` | An image stretched behind the thumb, between the arrows. |

A part with no image, or whose image couldn't be loaded, is drawn as the classic bar
draws it, from the theme. The demo's Sims windows read with
[`appearance.xml`](../Demo/Sources/hudini-demo/Resources/appearance.xml), and Move
Lot overrides its thumb.

### Fonts

An appearance names the font files a game draws with, so they live beside its other
design values instead of in Swift. The
[design note](design/2026-11-25-fonts.md) explains the choices.

```xml
<Appearance version="1">
  <Font name="text" path="fonts/ComicNeue-Regular.ttf" size="32"/>
  <Font name="tiles" path="fonts/B612Mono-Bold.ttf" size="48"/>
  <Fonts default="text"/>
  <Style name="tile" font="tiles" fontSize="title"/>
</Appearance>
```

- `<Font>` takes a `name`, a `path` the game's `loadFont` interprets, and a `size`,
  the whole number of pixels the glyphs are made at when loaded. Text draws at its
  own size, scaled from that one, so load near the largest size you draw. The names
  `interface` and `monospace` are taken, since a style's `font` means the theme's
  fonts by them.
- `<Fonts>`, at most one, puts fonts in place of the theme's: `default` for
  `InterfaceTheme.font`, which text uses without a `font` or with
  `font="interface"`, and `monospace` for `monospaceFont`. Either can be left out
  to keep the theme's.
- An appearance's `<Style>` can name one of its fonts in `font`. A window's style
  can't, so a window uses a named font through a shared style, such as
  `style="tile"`. A window that defines a style of the same name replaces it whole,
  font and all.
- Only appearances hold `<Font>` and `<Fonts>`. An older Hudini refuses an
  appearance with them, naming the element.

The game loads the fonts, as it loads images:

```swift
let theme = InterfaceTheme.standard.withFonts(from: appearance, loadFont: fonts.load)
let chat = try UIScript(contentsOf: chatURL, appearance: appearance)
let view = UIView(script: chat, theme: theme, loadImage: textures.load, loadFont: fonts.load)
```

- `loadFont` gets a `UIScript.FontResource`, with the `path` and `size`, after
  `InitWindow`, and returns a raylib `Font` or `nil`. Cache what it loads, since
  the theme and every view ask for the same fonts, and unload them before
  `CloseWindow`. Mipmaps and trilinear filtering keep thin strokes from dropping out
  when text is drawn smaller than the font was loaded; see the demo's
  `loadAppearanceFont`.
- `withFonts(from:loadFont:)` returns the theme with the appearance's `<Fonts>` in
  place of its own. The appearance wins; a font it leaves out, or that doesn't load,
  keeps the theme's. Pass the result to everything you draw, `WindowFrame`,
  `ButtonRow`, and `NoticePanel` included, and call it again on a new theme, such as
  when switching to dark mode.
- `UIView` loads the fonts its shared styles name and draws and measures each
  styled control in its font. A font it couldn't load is listed in `missingFonts`,
  and that text draws in the theme's font.

## Errors

`UIScript(data:)` and `UIScript(contentsOf:)` throw `UIScriptError`, whose
`localizedDescription` explains the problem and includes the line number when it
relates to one element. Loading either returns a complete, valid document or throws.
There is no partial result. `Appearance` throws the same errors. Messages either
kind of document can cause don't name the kind, so say which file failed when you
show one, as the demo does.

## Platform requirements

On Linux, `XMLParser` comes from `FoundationXML`, which links the system's
`libxml2.so.2` at runtime. Games shipping on Linux need that library installed or
bundled.

## Reading `.uis` files

`UIScript(uisData:)` and `UIScript(uisContentsOf:)` read Maxis' `.uis` format into
the same model, so `UIView` draws the result like any other document. See
[`debugbar.uis`](../Demo/Sources/hudini-demo/Resources/debugbar.uis) for an original
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

Lists and text areas show their own scroll bars, so a `.uis` slider or scroll
button placed beside one, which TSO's game code connected to it, reads as an
ordinary slider or button that scrolls nothing. Hide it by name with
`setHidden(_:named:)`. A slider runs along its longer side, so `orientation` is
listed in `ignoredAttributes`. Only `alignment=3`, which centers, is understood. See
the [roadmap's open questions](ROADMAP.md#open-questions) for what remains unknown.

## Reading CST text

The Sims Online keeps its interface text in `.cst` tables, which `.uis` files refer
to by table and index. Hudini leaves text to the host, so read them with
[SwiftCST](https://github.com/tonytins/swift-cst), which reads every version of the
game, and pass its lookup to the view:

```swift
import SwiftCST

let text = UIText(gameData: installURL.appendingPathComponent("gamedata"))
let view = UIView(script: script, resolveString: { resource in
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

Hudini's `CSTCatalog` did this before, and was removed on 2026-11-25. A game that
still uses it creates a `UIText` the same way, and calls `textIfPresent` where it
called `text`; it finds the same text. Hudini doesn't depend on SwiftCST: add it to
the game's own package.

## Not yet supported

A sidebar shows the rows that fit and has no scroll bar, so a pane whose row
doesn't fit can only be selected by the host. A long title ends in an ellipsis.

Within its subset, a text area's caret stays at the end of its text. Clicking to
place it, moving it with the arrow keys, selection, and the clipboard aren't
supported yet. Typing in a text area reports no event.

Hudini doesn't draw slider images, which `.uis` sliders name and the view replaces
with a plain track and thumb.

## Change log

The spec's change log is in
[VentureOS's spec](https://github.com/tonytins/VentureOS/blob/main/docs/uiscript/README.md#change-log),
including the changes made while Hudini kept it. Changes to Hudini's reader:

- **2026-11-25:** Tabs and a sidebar of panes. `UIScript` reads `<Tab>`, `tab` on
  `<ToolbarItem>`, `<Sidebar>`, and `<Pane>` in both its forms, into `tabs` and
  `sidebar`. Pressing a tab's toolbar item switches tabs, and `selectedTab` says
  which is showing. A `WindowFrame` draws a sidebar of panes beside the view, at
  `viewBounds(in:)`, and its rows switch panes, reporting `.selected`; `selectedPane`
  says which is showing. Other sidebars are refused
  with `unsupportedSidebar`. A nested `<Menu>` is now refused as outside the subset,
  rather than as nesting.
- **2026-11-25:** Appearances hold fonts: `<Font>` files, `<Fonts>` in place of
  the theme's, and shared styles naming a font. `UIView` takes `loadFont` and
  reports `missingFonts`, and `InterfaceTheme.withFonts(from:loadFont:)` fills the
  theme. Error messages an appearance can cause too no longer begin "UIScript".
- **2026-11-25:** `CSTCatalog` and `CSTError` are gone, and Hudini no longer depends
  on SwiftCST. Games read `.cst` text with SwiftCST's `UIText` themselves.
- **2026-11-25:** Appearances: `Appearance`, read from `<Appearance>` documents,
  and `UIScript(contentsOf:appearance:)`, so windows share images, styles, and
  scroll bar art. A Hudini feature; the spec is unchanged.
- **2026-11-25:** Hudini follows the spec's changes of 2026-11-24 and 2026-11-25.
  Lists and text areas draw their own scroll bars, and a control with `scrolls` or
  `direction` refuses the document (`UIScriptError.retiredScrolling`), where it used
  to scroll a list by hand. `orientation` is skipped and listed. `<Slider>` takes
  `step` and reports `committed`, takes the keyboard when pressed, and runs bottom
  to top when it's tall. `<TextField>` and `<TextArea>` follow `alignment`. A
  document that scrolled a list with a slider or buttons drops them and widens the
  list into their room.

- **2026-11-20:** The spec moves to VentureOS, and Hudini reads a subset of it.
  `requires` accepts the old module names `menus`, `sidebar`, `shelf`, and `panes`,
  which mean nothing, so documents that name them read as before; the elements they
  named are refused as unknown elements, with a message saying they're outside the
  subset.
