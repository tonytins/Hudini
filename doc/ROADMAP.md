# Hudini Roadmap

Hudini is a Swift-friendly interface library for games using raylib. Its
direction is guided by Apple's and GNOME's human interface guidelines, while
leaving room for game-specific interaction and Hudini's own visual language.
The goal is to help a game build a clear, cohesive interface without hiding
raylib or growing a general-purpose application UI framework.

Milestones use names from Apple's cat-named Mac OS X releases. The names are
inspiration only; this project is independent and is not affiliated with Apple.
Only Cheetah has planned work. Future milestones will be added when their scope
is clear.

## Cheetah — Simplifying the API

Cheetah focuses on making common interface work take less code while keeping
the library small, Swift-like, and easy to customize.

### Completed

- [x] Give the extracted library its own Hudini package, module, and demo names.
- [x] Replace project-specific interface colors with a per-interface
  `InterfaceTheme`, while keeping the original palette as the standard theme.
- [x] Add an initial `FormLayout` for vertically stacked, labeled controls, and
  update the demo to use it.
- [x] Bind form fields directly to controls so layout assigns their bounds and
  callers can draw them without repeating frame lookups.
- [x] Let a selected toolbar item also serve as a window drag area.

### Still to explore

- [ ] Try the current API in its intended host game and note which call sites
  still need repetitive setup or geometry calculations.
- [ ] Simplify the remaining common window and control setup where a focused
  Hudini helper improves the call site. Keep direct raylib drawing available
  for custom layouts and visuals.
- [ ] Refine the layout API based on real forms: sizing, spacing, and how
  callers place controls and action rows.
- [ ] Review the public API and demo together for consistent Swift naming,
  argument labels, and clear update/draw responsibilities.

These are investigation and design tasks, not commitments to add a view tree,
custom geometry system, or replacement for raylib.

## Cat-named Mac OS X releases

Reference list of Apple's Mac OS X releases named after cats:

| Version | Release name |
| --- | --- |
| Mac OS X 10.0 | Cheetah |
| Mac OS X 10.1 | Puma |
| Mac OS X 10.2 | Jaguar |
| Mac OS X 10.3 | Panther |
| Mac OS X 10.4 | Tiger |
| Mac OS X 10.5 | Leopard |
| Mac OS X 10.6 | Snow Leopard |
