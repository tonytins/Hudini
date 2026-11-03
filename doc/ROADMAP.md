# Hudini Roadmap

Hudini is a Swift interface library for games using raylib. It aims to make
game interfaces easier to describe and compose without hiding raylib or
growing into a general-purpose application UI framework.

The demo is the proving ground for a standalone, JSON-driven interface
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
examples through a small, reusable JSON interface model and renderer. A `.uis`
compatibility adapter is not required for this stopping point.

## Cheetah — JSON chat window

Prove that a standalone JSON document can describe a small window and that the
demo can render it.

- [x] Add the initial typed UIScript JSON model and decoding validation.
- [x] Replace the demo's floating settings window with a chat-window preview
  loaded from JSON.
- [x] Render initial history, a scrollbar, scroll buttons, and an entry
  field from JSON-described bounds and styles.
- [ ] Keep the model and preview aligned as the smallest useful field set
  becomes clear.
- [ ] Replace the remaining preview-only drawing with a focused reusable
  UIScript rendering path without turning the library into a general view
  framework.

## Puma — Usable chat controls

Turn the chat preview into a usable property-chat interface while keeping
game behavior in the host.

- [x] Draw and update the text field and message list through reusable Hudini
  controls, configured by the demo from the JSON model.
- [x] Support click focus, text editing, and a typed submit event the host can
  handle.
- [x] Support wheel and arrow-button scrolling over host-provided chat content.
- [x] Keep the chat dialog at its JSON-declared size; defer resizing controls
  and edge-offset behavior while the host viewport may resize.
- [x] Keep content, actions, and chat-history state owned by the demo host;
  simulate resident replies in the example host.

## Jaguar — Live-panel breadth proof

Use the larger live-panel reference to test whether the same JSON model and
renderer can describe a substantially different game interface.

- [ ] Review the unwired `livepanel1024.json` draft against
  the corresponding TSO live-panel UIScript.
- [ ] Add only the reusable control or presentation features needed to render
  the panel's concrete layout, such as list presentation and image-backed
  controls.
- [ ] Provide representative host-owned data for the live panel in the demo.
- [ ] Render the live panel from JSON without special-casing its composition
  inside the renderer.
- [ ] Compare the chat and live-panel examples to ensure they share the model
  without forcing a single layout or interaction pattern.

## Panther — Consolidate the UIScript foundation

Stop after the two examples validate the useful scope of Hudini's reusable
interface description and rendering support.

- [ ] Document the JSON format fields that both examples actually use.
- [ ] Define clear validation and loading errors for unsupported or malformed
  documents.
- [ ] Decide how older readers tell optional additions they may ignore from
  required features they must reject.
- [ ] Keep controls, resources, and host data/actions clearly separated.
- [ ] Add focused headless tests for decoding, validation, and layout, plus
  runtime checks for rendering that needs raylib.
- [ ] Review public APIs and documentation for a small, understandable library
  surface.

### Stopping point

The roadmap is complete when:

1. The chat window and live mode panel both load from JSON and render through
   reusable Hudini support.
2. The host can provide data and handle control events without embedding
   game-specific decisions in Hudini.
3. Unsupported or invalid JSON fails clearly, and the implemented format is
   documented and tested.

The `.uis` adapter, full TSO runtime compatibility, every control in the full
TSO UIScript collection, and a general-purpose layout engine are explicitly
beyond this stopping point unless real users or host-game needs justify them.

## Later cat-named Mac OS X releases

These are available as inspiration if the project later needs another
roadmap; they are not planned milestones:

| Version | Release name |
| --- | --- |
| Mac OS X 10.4 | Tiger |
| Mac OS X 10.5 | Leopard |
| Mac OS X 10.6 | Snow Leopard |
