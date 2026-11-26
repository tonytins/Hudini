# An appearance windows share

**Status:** approved 2026-11-25; being built in phases. **Date:** 2026-11-25.

A game's windows share a look: the same scroll bar art, the same text styles. Today every UIScript document has to
repeat them, and a scroll bar can't take art at all; it draws from the `InterfaceTheme`. This design gives a game one
**appearance** document that every window inherits from, and lets any window differ from it by defining the same
name itself.

## Why

- **The Sims Online shares its art this way.** About 30 of its 88 `.uis` files define the same "gizmo" scroll bar
  set, by the same asset IDs: `gizmo_scrollbarimg`, `gizmo_scrollupbtn`, and `gizmo_scrolldownbtn`. A few windows,
  such as person selection, use art of their own instead. Simburbia needs that shared base, and needs some windows
  to differ, as property chat and private chat do.
- **Lists and text areas draw their own scroll bars** since Hudini followed the spec's 2026-11-24 change, so the
  scroll bar's art can no longer come from a slider a document places beside a list. It needs a home.
- **Styles repeat.** A game whose chat window and message log both use the same text color writes that `<Style>`
  twice, and the copies drift.

We don't know how TSO's game code connected the gizmo art to its lists, so this design picks its own way.

## Goals

- One file, loaded by the game, holding the images, styles, and scroll bar art its windows share.
- A window uses a shared name as if it had defined it, and overrides one by defining it.
- Window documents stay plain UIScript: nothing new appears in them.
- Without an appearance, everything reads and draws exactly as it does now.

## Non-goals

- **A change to the UIScript spec.** This is a Hudini host feature built from elements the spec already has. VentureOS
  keeps the spec, and nothing here asks it to change.
- **Theme values** such as colors, corners, and fonts. They stay in `InterfaceTheme` until a game wants them in a file.
- **`<String>`** in the appearance, and **`.uis` files** contributing to one. Neither has a game asking yet.
- **Several named appearances** a window picks between. A window that differs defines what differs.

## How it works

### The file

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Appearance version="1">
  <Image name="scrollThumb" path="scroll/thumb.png"/>
  <Image name="scrollUp" path="scroll/up.png" stateCount="4"/>
  <Image name="scrollDown" path="scroll/down.png" stateCount="4"/>
  <ScrollBar width="15" thumb="scrollThumb" thumbCap="6" up="scrollUp" down="scrollDown"/>

  <Style name="chatText" textColor="#FFF99D" fontSize="body"/>
</Appearance>
```

- The root is `<Appearance>`, with `version="1"`. A newer version refuses the file, as UIScript's root does.
- It holds `<Image>`, `<Style>`, and at most one `<ScrollBar>`, as direct children, in any order.
- **`<Image>` is UIScript's**: `name`, then `path`, `assetID`, or both, and `stateCount`. The game's `loadImage`
  decides which to use, as it does for a window. Most games use `path`; `assetID` is there for games like TSO that
  find art by ID.
- **`<Style>` is UIScript's**, with every attribute it has: colors, color roles, `dark` twins, size roles, and `font`.
- Names are unique within each kind, as in a window.
- The document rules are UIScript's: no text in elements, no `DOCTYPE`, an unknown element refuses the file, and an
  unknown attribute is skipped and listed in `ignoredAttributes`.

### The scroll bar

`<ScrollBar>` names the images a list's or text area's scroll bar draws with. Every attribute is optional.

| Attribute | Value |
| --- | --- |
| `width` | The bar's width in pixels, above 0. Defaults to 15. The arrows are as tall as the bar is wide. |
| `up`, `down` | The arrows' images. With four states, they show normal, hovered, pressed, and disabled, as a button's do. |
| `thumb` | The thumb's image, stretched to the thumb's length. |
| `thumbCap` | Pixels at the thumb image's top and bottom that keep their size while its middle stretches, 0 or more. Defaults to 0, which stretches the whole image. |
| `track` | An image stretched behind the thumb, between the arrows. |

- Each image is drawn at the bar's width.
- A part with no image, or whose image the game couldn't load, draws as the classic bar does from the theme. A bar can
  take art for its arrows and keep the theme's thumb.
- An image name that's in neither the appearance nor the window refuses the appearance or the window, with the name.
- `<ScrollBar>` exists only in an appearance. A window can't hold one.

### Inheriting

The game reads its appearance once and hands it to the reader of each window:

```swift
let appearance = try Appearance(contentsOf: appearanceURL)
let chat = try UIScript(contentsOf: chatURL, appearance: appearance)
let view = UIView(script: chat, loadImage: textures.load)
```

- A window's `style` and `image` references, its controls' and visuals', resolve against the window's own resources
  first, then the appearance's.
- **A window overrides by name.** A window's `<Image>` or `<Style>` replaces the appearance's of the same name, whole:
  a window's `chatText` style with only a `fontSize` has no `textColor` from the appearance's. To give one window its
  own scroll bar art, define an `<Image>` with the same name the `<ScrollBar>` uses, such as `scrollThumb`.
- The resulting `UIScript` holds the window's resources and styles plus the shared ones it uses, and the scroll bar,
  so `UIView` needs no new parameter: it calls `loadImage` for those images as it does for its own. A game with
  many windows caches textures in `loadImage` so each file loads once.
- Shared images and styles a window doesn't use aren't copied into it.
- `UIScript(data:)` and `UIScript(contentsOf:)` without an appearance read exactly as they do now.

A `.uis` file reads without an appearance.

### What other readers see

A window that leans on shared names doesn't load on its own: the reader can't find what it names.

- **Depot** draws documents through `depot-render`, which takes `--appearance <file>`, and Depot can choose one for
  a document, so it draws what the game draws.
- **VentureOS** refuses such a window, naming the missing style or image. That's expected: an appearance is a Hudini
  host feature. The copies of Hudini's examples VentureOS tests against stay standalone.
- **An older Hudini** refuses `UIScript(contentsOf:appearance:)` at compile time, since the parameter doesn't exist.
  A game moves to a Hudini that has it, then adopts it.

### Errors

`Appearance` throws the same `UIScriptError` a window does, with line numbers: a newer version, an unknown element, a
second `<ScrollBar>`, a duplicate name, a `width` that isn't above 0, a negative `thumbCap`, and a reference to an
image that isn't there. Reading an appearance returns a complete, valid one or throws.

## Compatibility

The appearance has its own `version`. It starts at 1, and follows UIScript's rules: an unknown attribute is skipped
and listed, an unknown element refuses the file, and a newer version refuses it before anything else is read. A
later addition that an older Hudini can safely skip is an attribute; one it can't is an element or a new version.

Nothing changes for a game that doesn't load an appearance.

## Phases

1. **Design note:** this document.
2. **Scaffolding:** `Appearance` and its reader, with tests. Nothing uses it yet.
3. **Inheritance:** `UIScript(…, appearance:)` resolves shared names, a window overrides by name, and the merged
   document reaches `UIView`.
4. **Scroll bar art:** the bar draws from its images, falling back to the theme. The demo gets an `appearance.xml`
   with shared scroll bar art, and Move Lot overrides its thumb. The demo's art is plain placeholder art, marked as
   such. The demo doesn't share styles: its documents are VentureOS's and Depot's test fixtures, which must read
   alone, so they keep their own. Tests cover shared styles.
5. **Docs and Depot:** `UISCRIPT.md` and the README; `depot-render --appearance`, and Depot choosing one.
6. **Cleanup:** remove `CSTCatalog` and Hudini's swift-cst dependency, since Simburbia reads text with swift-cst's
   `UIText` now.

## Calls made in writing it

The owner decided: a Hudini host feature reusing `<Image>` and `<Style>`; override by name, whole; the game loads it
and hands it over, and a document doesn't name it; `<Image>` takes `path`, `assetID`, or both, as UIScript's does;
four-state arrows and a three-sliced thumb; Depot gets `--appearance` and VentureOS's copies stay standalone;
placeholder art in the demo; no strings and no `.uis` input yet; and `CSTCatalog` leaves at the end.

These were the writer's calls:

- The appearance goes to the reader, not the view, so references are checked once and `UIView` gains no parameter.
- `<ScrollBar>` is the only new element, and only in an appearance.
- `thumbCap` is one number for both caps, defaulting to a thumb that stretches whole.
- Every image is drawn at the bar's width, and a missing part falls back to the theme's drawing.
- Only the shared names a window uses are copied into it.
