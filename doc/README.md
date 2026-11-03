# Hudini Documentation

This directory holds Hudini's design notes and roadmap.

- [UIScript format](UISCRIPT.md) describes the XML interface format, reading
  `.uis` files, and what hosts are responsible for.
- [CST format](CST.md) specifies The Sims Online's text tables, and how sure each
  rule is.
- [Roadmap](ROADMAP.md) tracks the milestones so far and the questions still open.

## Where Hudini came from

Hudini started as part of [CityLimits](https://github.com/tonytins/citylimits),
an open source city simulation based on Micropolis and written in C#. CityLimits
needed its windows, text fields, and dialogs to work the same way across the
game's different modes, so those pieces became reusable components rather than
being rebuilt for each one.

Those components were then ported to Swift for NewSO (NSO), an open source
reimplementation of The Sims Online that was itself ported from CityLimits' C#
code, where they lived in [SimsCraft](https://github.com/tonytins/SimsCraft) as a
package named NSOInterface. The port kept the original window frames, text
controls, panels, and button rows, and it is why the default colors match NSO's.

It became clear the library was useful beyond one game, so it was split out as
Hudini for use across raylib projects. Separating it also gave it room to grow in
a new direction: UIScript, an interface description inspired by the `.uis` files
The Sims Online shipped with. Hudini now reads those files as well as its own
friendlier [XML format](UISCRIPT.md).

## Design influences

Hudini takes inspiration from Apple's Human Interface Guidelines and GNOME's
Human Interface Guidelines, while developing its own approach for game
interfaces built with raylib. These references are starting points, not rules
Hudini needs to reproduce.
