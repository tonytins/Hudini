# Hudini Roadmap

Hudini is a Swift interface library for games using raylib. It aims to make
game interfaces easier to describe and compose without hiding raylib or
growing into a general-purpose application UI framework.

The demo is the proving ground for a standalone, XML-based interface
description. The first concrete target is a small chat dialog based on TSO's
UIScript examples; the larger breadth target is a 1024-wide live mode panel
from the same set. These are references for original implementations, not a
goal of reproducing TSO's code or runtime.

The demo's longer-term goal is still a Sims-inspired HUD, based on the fourth
iteration of The Sims' interface. The chat window and live panel are stepping
stones toward it, so components the demo does not currently show remain part of
the library. CityLimits has no separate proof here: TSO's interface is broad
enough that CityLimits is expected to benefit and adopt UIScript later.

Milestones use cat-named Mac OS X releases as inspiration only. They are
ordered stages, not promises to implement every behavior from the legacy
scripts. Stop when the outcomes below are met and Hudini can support both
examples through a small, reusable interface model and renderer. A `.uis`
reader is not required for this stopping point.

## Cheetah — Data-driven chat window

Prove that a standalone document can describe a small window and that the
demo can render it.

- [x] Add the initial typed UIScript model and validation.
- [x] Replace the demo's floating settings window with a chat-window preview
  loaded from a document.
- [x] Render initial history, a scrollbar, scroll buttons, and an entry
  field from document-described bounds and styles.
- [x] Keep the model and preview aligned as the smallest useful field set
  becomes clear.
- [x] Replace the remaining preview-only drawing with a focused reusable
  UIScript rendering path without turning the library into a general view
  framework.

## Puma — Usable chat controls

Turn the chat preview into a usable property-chat interface while keeping
game behavior in the host.

- [x] Draw and update the text field and message list through reusable Hudini
  code driven by the model.
- [x] Support click focus, text editing, and a typed submit event the host can
  handle.
- [x] Support wheel and arrow-button scrolling over host-provided chat content.
- [x] Keep the chat dialog at its declared size; defer resizing controls
  and edge-offset behavior while the host viewport may resize.
- [x] Keep content, actions, and chat-history state owned by the demo host;
  simulate resident replies in the example host.

## Jaguar — Live-panel breadth proof

Use the larger live-panel reference to test whether the same model and
renderer can describe a substantially different game interface.

- [x] Review the `livepanel1024` draft against the corresponding TSO
  live-panel UIScript.
- [x] Add only the reusable control or presentation features needed to render
  the panel's concrete layout: visuals, image-backed buttons with four states,
  disabled buttons, and regions the host draws into.
- [x] Provide representative host-owned data for the live panel in the demo.
- [x] Render the live panel from its document without special-casing its
  composition inside the renderer.
- [x] Compare the chat and live-panel examples to ensure they share the model
  without forcing a single layout or interaction pattern.

## Panther — Consolidate the UIScript foundation

Stop after the two examples validate the useful scope of Hudini's reusable
interface description and rendering support.

- [x] Move the format from JSON to XML, which allows comments, stays compact for
  hand-written interfaces, and sits closer to `.uis` for later conversion.
- [x] Document the format fields that both examples actually use.
- [x] Define clear validation and loading errors for unsupported or malformed
  documents.
- [x] Decide how older readers tell optional additions they may ignore from
  required features they must reject.
- [x] Keep controls, resources, and host data/actions clearly separated.
- [x] Add focused headless tests for decoding, validation, and layout. Rendering
  is exercised through the demo, and runtime checks beyond that belong to hosts.
- [x] Review public APIs and documentation for a small, understandable library
  surface.

### Stopping point

The roadmap is complete when:

1. The chat window and live mode panel both load from XML and render through
   reusable Hudini support.
2. The host can provide data and handle control events without embedding
   game-specific decisions in Hudini.
3. Unsupported or invalid documents fail clearly, and the implemented format is
   documented and tested.

Full TSO runtime compatibility, every control in the full TSO UIScript
collection, and a general-purpose layout engine are explicitly beyond this
stopping point unless real users or host-game needs justify them.

## Tiger — Reading `.uis` files

NSO, the game Hudini grew out of, will load TSO's `.uis` files, so Hudini reads
them into the same model. UIScript XML remains the friendlier format for writing
new interfaces.

The demo proves this without any TSO material. Its debug bar is an original file
in Maxis' format, based on the prototype interface behind NSO's debug bar, and it
needs no game install or assets. The roles are deliberately crossed: the
TSO-derived chat window and live panel are in Hudini's format, and the original
debug bar is in Maxis' format.

- [x] Write the debug bar as an original `.uis` file.
- [x] Read `.uis` syntax, scopes, shared properties, and case-insensitive names
  into the existing model.
- [x] Report what the model cannot represent instead of guessing or failing, and
  fail only on broken syntax.
- [x] Keep both `path` and `assetID` on images, and take missing sizes from images.
- [x] Add what the bar needs: edge-offset anchoring, text alignment, and selected
  buttons.
- [x] Show the bar in the demo, hidden until the pointer reaches the top of the
  screen or a new error arrives, and open a notice panel from its buttons.
- [x] Check the reader against a local copy of TSO's 88 `.uis` files where one
  exists, without committing them.

### Open questions

- **What do `alignment` values mean?** FreeSO confirms only `3`, which centers.
  Values `0`, `1`, `2`, `4`, and `5` appear in real files, so the reader reports
  them and leaves that text left-aligned. FreeSO also centers text with no
  `alignment`, which the reader does not yet follow.
- **What do the last two slices of a six-state image hold?** Six real files use
  `ImageStates=6`. Hudini draws the four known states from them.
- **Do positions in CST tables count from 0 or 1?** Hudini follows FreeSO and counts
  from 0, but the files lean the other way. The credits screen in the original game
  would settle it. See the [specification](CST.md#entries) for this and its other
  unsettled rules.
- **How should sliders draw their images?** Most real sliders name an image, and
  two name a separate thumb image. The view draws a plain track and thumb for now.

## Leopard — Control panels and object interfaces

In every Sims game, the root panel is the control panel, or UCP. It swaps between
modes, and in TSO the live panel also hosts an object's own interface, an
Extended Object Dialog or EOD. Some items in TSO's beta are remembered as opening
theirs in a separate window. TSO's EOD files declare no window size, so nothing in
a file decides this, and Hudini treats it as the host's choice.

Hudini provides the general parts and has no idea what an EOD is. The rules for
TSO's EOD frames belong to the game that uses them.

- [x] Keep `SetControlProperties` entries as settings game code reads by name, and
  draw nothing from them until the host asks.
- [x] Prove panel swapping and panels inside panels in the demo, using existing
  views at different origins. No container type turned out to be needed.
- [x] Draw tooltips, and add slider dragging with values, ranges, and orientation.
- [x] Add a progress bar control.
- [x] Let hosts place what a document leaves to game code with `setBounds(_:named:)`.
- [x] Add an original control panel to the demo with `IconToolbar` as its mode
  switcher, plus an original `.uis` stand shown in the live panel and in a window.

## Snow Leopard — Reading CST text

TSO's interfaces take their text from CST files, and the `.uis` files refer to
them by table and index. Hudini gets its own CST reader that works across TSO's
versions, based on what [swift-cst](https://github.com/tonytins/swift-cst) has
already learned. CST files are not known to appear in any other game.

- [x] Read CST files in the encodings real files use, loading each table once.
- [x] Read values by key, by the line above them, and by position, and follow
  references between tables.
- [x] Write the [format's specification](CST.md), marking what is confirmed.
- [x] Offer a catalog that plugs into `resolveString` and reports missing text.
- [x] Find text in both install layouts.
- [x] Give the demo original CST files in place of its strings in code.
- [x] Check the reader against local copies of TSO's beta, base game, and New &
  Improved text, without committing them. Every string their `.uis` files use is found.
