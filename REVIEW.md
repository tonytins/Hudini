# Review Guide

Use this checklist when reviewing a change to Hudini. It is adapted from the
contributor and review practices in [NVIDIA FLARE's contribution guide](https://github.com/NVIDIA/NVFlare/blob/main/CONTRIBUTING.md),
with checks tailored to this Swift and raylib-swift package.

## Before reviewing

- Read the change description and the relevant code and tests.
- Identify the user-visible behavior or problem the change is intended to address.
  If it refers to an issue or design discussion, check that the change addresses
  that context.
- Check available build, test, and CI results. Run `swift build` or `swift test`
  when the change or its verification warrants it; report checks that could not
  be run.

## Review checklist

- Does the behavior match the stated intent, including boundary cases such as
  empty or short bounds, maximum lengths, disabled controls, and pointer input?
- Are public API names, defaults, and behavior clear and consistent with
  existing components? Could the change break existing callers?
- Does interaction state update correctly without making drawing responsible for
  unrelated state changes?
- Are raylib calls compatible with the resolved dependency and used only when
  the required window or graphics context is available?
- Do focused tests cover the changed behavior? Are runtime or visual checks
  needed in addition to headless tests?
- Are the demo and documentation updated when they are affected?

## Writing review comments

- Report concrete correctness, compatibility, reliability, or missing-test
  concerns; do not block changes on personal style preferences.
- Make each comment specific, constructive, and actionable. Point to the
  smallest relevant location and explain the impact and a useful next step.
- Prioritize findings by impact:
  - **Blocking**: prevents the package from building or causes severe,
    unavoidable failure in normal use.
  - **High**: breaks an existing public behavior or a common interaction.
  - **Medium**: causes a limited but meaningful behavior or reliability issue.
  - **Low**: a small edge case or non-blocking improvement.
- If no actionable issues remain, say so and note any important checks that
  were not run.
