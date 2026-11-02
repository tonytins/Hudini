# Project Guidelines

## Project structure

Hudini is a Swift library for game interfaces built with raylib-swift. Reusable
components belong in `Sources/Hudini`; `Sources/hudini-demo` shows how to use
them, and `Tests/HudiniTests` covers their behavior.

## Build and test

- Build with `swift build`.
- Run the test suite with `swift test`.
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
