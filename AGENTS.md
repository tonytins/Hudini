# Project Guidelines

## Project structure

Hudini is a Swift library for game interfaces built with raylib-swift. Reusable
components belong in `Sources/Hudini`, and `Tests/HudiniTests` covers their
behavior. The demo that shows how to use them is a package of its own in `Demo`,
which depends on this checkout by path. Keep it out of the root `Package.swift`, so
games that depend on Hudini never see or build it.

The demo (`Demo/Sources/hudini-demo`) opens on a menu (`Menu.swift`) with two
demos. The Sims Online-style one is the rest of `main.swift`, with its documents in
`Resources`. The CityLimits-style one is `CityDemo.swift`, with its documents in
`Resources/city`. It's the reference for how a Swift port of CityLimits could use
Hudini: HUD panels outside a `WindowManager`, and windows as small classes with
their own handlers.

## Build and test

- Build with `swift build`.
- Run the test suite with `swift test`. Some tests read the demo's documents from
  `Demo/Sources/hudini-demo/Resources`.
- Build the demo with `swift build --package-path Demo`, and run it with
  `swift run --package-path Demo hudini-demo`.
- Keep tests that do not need a graphics context headless. Text measurement and
  drawing that depend on an initialized raylib window need a separate runtime
  check.

## Swift and raylib

- Match the package's Swift 6 language mode and existing naming and formatting.
- Keep public APIs clear at the call site and document public behavior where
  names alone are not sufficient.
- Use the resolved raylib-swift API and existing component patterns. raylib
  functions are generally global; do not assume C names or documentation for a
  different resolved version match the Swift interface.
- Keep interface state updates separate from drawing where practical, and
  preserve existing behavior when changing public components.
- Add or update focused tests and the demo when a behavior change affects how
  callers use a component.

See [REVIEW.md](REVIEW.md) for the project's review checklist.

## Personal Configuration

Keep personal preferences and machine-specific guidance in git-ignored
`*.local` (such as ``AGENTS.local.md``) files or directories, rather than in shared project instructions.
Check for relevant local guidance before environment-specific work. You can
create or update these files for details such as:

- Coding preferences
- Local build and development environment
- Personal shortcuts or workflows
