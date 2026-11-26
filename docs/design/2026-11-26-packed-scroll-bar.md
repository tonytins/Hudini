# Packed scroll bar art

**Status:** approved and built 2026-11-26. **Date:** 2026-11-26.

The Sims Online draws its scroll bars from one image that holds both the track and the thumb, with arrows narrower
in height and wider than the bar. An [appearance](2026-11-25-appearance.md)'s `<ScrollBar>` can't take art shaped
that way. This design adds a `slider` attribute that names such an image, and draws every part of the bar at its
own size.

## Why

- **TSO's art doesn't fit `<ScrollBar>`.** Measured from TSO 1.1097.1.0's `uigraphics`, and from how FreeSO's
  `UISlider` (`FSO.UI/Controls/UISlider.cs`) draws it:

  | Graphic | Asset ID | Size | What it is |
  | --- | --- | --- | --- |
  | `gizmo_scrollupbtn.bmp` | `0x0000031200000001` | 84×8 | Four states of 21×8: wide, flat arrows |
  | `gizmo_scrolldownbtn.bmp` | `0x0000031100000001` | 84×8 | The same, pointing down |
  | `gizmo_scrollbarimg.bmp` | `0x0000031000000001` | 13×96 | Track and thumb in one image |

  `<ScrollBar>` draws arrows as tall as the bar is wide, so a 21×8 arrow comes out 13×13. It takes the thumb and
  track as whole images, so the packed graphic can't be named. And it stretches both: the thumb to show how much of
  the content is visible, the track whole, so the track's rounded ends distort.
- **Simburbia is waiting on it.** Its client step E3, the gizmo scroll bars on every list, needs this. About 30 of
  TSO's 88 `.uis` files define the same three images by these IDs.
- **The roadmap asks how sliders draw their images.** The same packing answers it for `.uis` `AddSlider`s, which
  name one image.

## Goals

- An appearance names TSO's three images and gets TSO's bar: wide arrows, a track whose ends keep their shape, and a
  thumb of its own size.
- Window documents stay plain UIScript, and a window still overrides the art by defining an `<Image>` of the same
  name.
- An appearance without `slider` reads and draws exactly as it does now.

## Non-goals

- **`<Slider>` drawing packed art.** Lists and text areas are the only bars that draw from an appearance. This note
  records how a slider's image is packed, so `<Slider>` can follow when a game needs it, but nothing draws one yet.
- **Horizontal scroll bars.** Lists and text areas only scroll up and down.
- **A general way to cut part of an image**, such as `x`, `y`, `width`, and `height` on `<Image>`. It's more
  flexible, but more to design, and nothing else needs it.
- **TSO's gaps.** `budget.uis` leaves two pixels between each arrow and the slider. Those come from where each
  screen places its buttons, not from the art, and Hudini's bar keeps its parts touching.

## How it works

```xml
<Appearance version="1">
  <Image name="scrollUp" assetID="0x0000031200000001" stateCount="4"/>
  <Image name="scrollDown" assetID="0x0000031100000001" stateCount="4"/>
  <Image name="scrollBar" assetID="0x0000031000000001"/>
  <ScrollBar up="scrollUp" down="scrollDown" slider="scrollBar"/>
</Appearance>
```

### The attribute

| Attribute | Value |
| --- | --- |
| `slider` | An image holding the track and the thumb, packed as TSO packs them. |

- `slider` can't be combined with `thumb`, `track`, `thumbCap`, or `width`. Each pair refuses the appearance with
  `conflictingAttributes`, so there's one way to draw the track and thumb, and the bar's width comes from its art.
- `up` and `down` combine with it as they do now.
- A `slider` name that's in neither the appearance nor the window refuses it, with the name, as the other parts do.

### How the image is packed

Read top to bottom, as FreeSO reads TSO's:

- **The track** is the top three-quarters. For TSO's 96-pixel image, that's rows 0 to 71.
- **The thumb** is the bottom quarter, rows 72 to 95. TSO's art fills rows 75 to 92 and is 11 pixels wide; the rest
  is transparent, and is drawn as it is.
- An image whose height doesn't divide by four gives the thumb its height divided by four, rounded down, and the
  track the rest.

A horizontal slider, when one draws packed art, reads the same across: the track is the left three-quarters and the
thumb the right quarter.

### How the bar is drawn

With `slider`, every part is drawn at its own size:

- **The bar's column** is as wide as its widest part: the slider image, or one state of an arrow image. TSO's is 21
  pixels, from its arrows. The content narrows by that much while the bar shows, as it does now.
- **The arrows** are one state's width by the image's height, centered across the column, at its top and bottom.
- **The track** fills the column's height between the arrows, as wide as the slider image and centered. It's cut in
  three: its top and bottom thirds keep their height and its middle third stretches, as the thumb's caps do now.
  The thirds are the track's height divided by three, rounded down, with the middle taking what's left. A track too
  short for both ends shrinks them evenly.
- **The thumb** is drawn at its own size, centered across the column, and never stretched. It moves down the track by
  how far the content is scrolled, over the track's height less its own. It doesn't show how much of the content is
  visible, and the 18-pixel minimum doesn't apply. A track shorter than the thumb shrinks the thumb to fit.

That matches TSO's own screens: `budget.uis` puts the 21-pixel arrows at x 460 and the 13-pixel slider image at x
464, so the slider sits centered under them.

### Clicks

- Each arrow's click area is the box it's drawn in, and the thumb's is its own.
- Anywhere else in the column pages toward the pointer, even beside a track that's narrower than the column. The
  column belongs to the bar, as it does now.
- Dragging the thumb, holding an arrow or the track, and the repeat timings work as they do now.

### When an image doesn't load

As now, a part whose image the game couldn't load draws from the theme:

- A slider image that doesn't load draws the theme's classic track and thumb, 15 pixels wide, and the column is as
  wide as that or the widest arrow.
- An arrow image that doesn't load, or that's left out, draws the theme's classic arrow across the column, 15 pixels
  tall.

### Without `slider`

Nothing changes: arrows are as tall as the bar is wide, and the thumb and track stretch, as the
[appearance note](2026-11-25-appearance.md) describes. The demo's current appearance draws exactly as it does today.

## Compatibility

`slider` is a new attribute, and the appearance's rules say an unknown attribute is skipped and listed in
`ignoredAttributes`. An older Hudini reading an appearance with `slider` draws squashed arrows and the theme's thumb
and track: a usable bar that looks wrong, not a refusal. That's acceptable, since the games that would use it track
Hudini's `main`.

- **Simburbia** adopts it in step E3: three `<Image>` lines and a `<ScrollBar>` in `Interface/appearance.xml`.
- **depot-render** is pinned, so it sees `slider` only after it moves past the pin, and then draws it with no change of
  its own. Depot's C# reader (`HudiniAppearance.cs` at Depot `460de5b`) refuses appearance elements it doesn't
  know, but only counts `<ScrollBar>` elements and reads none of their attributes, so `slider` passes.
- **VentureOS** doesn't read appearances, so nothing changes there.
- No public Swift API is removed or renamed. `Appearance.ScrollBar` gains a `slider` property.

## Phases

1. **Design note:** this document.
2. **Reader:** `Appearance` reads `slider`, refuses it alongside `thumb`, `track`, `thumbCap`, or `width`, and
   resolves its name as the other parts do. Tests. Nothing draws it yet.
3. **Layout and drawing:** the bar's geometry and drawing for packed art: the column, arrows at their own size, the
   track cut in thirds, and the fixed thumb. Geometry tests that need no window, and screenshots on a virtual
   display.
4. **Demo and docs:** the Sims demo's appearance moves to packed placeholder art, and Move Lot overrides the slider
   image. `UISCRIPT.md`, the appearance note, and the roadmap's slider question. Check Depot skips `slider`. Mark
   Simburbia's report fixed.

## Calls made in writing it

The owner decided: a `slider` attribute naming one packed image (option A in Simburbia's report); a fixed thumb with
packed art only; a column as wide as the widest part, with parts centered and the rest of the column paging; `slider`
refused alongside `thumb`, `track`, `thumbCap`, and `width`; arrows at their own size only with `slider`; and only
vertical bars now, with the horizontal packing recorded for sliders.

These were the writer's calls:

- Parts touch, with no gaps like `budget.uis`'s.
- Heights that don't divide evenly round the thumb's quarter and the track's thirds down.
- A track shorter than the thumb shrinks the thumb, and one too short for both ends shrinks them evenly.
- A slider image that doesn't load falls back to the classic track and thumb at 15 pixels.
- The Sims demo moves to packed art, since it's the TSO-style demo. Tests keep covering `thumb` and `track`.
