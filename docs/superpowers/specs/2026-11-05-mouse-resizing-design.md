# SwiftShift-style mouse moving and resizing

Status: approved by the user November 5; implementation and verification in progress.

## Intent and scope

Add SwiftShift's pointer-relative resizing, mouse-driven window movement, and
related controls to ZLaunch's Window Management settings. The user requested
behavioral parity with SwiftShift and explicitly added movement to the scope.
Do not create a separate app.

Reference: pablopunk/SwiftShift commit
`7108f43d75ecd69d72537c007cee2618c04cd3d4`, especially
`Swift Shift/src/Manager/MouseTracker.swift`, `ShortcutsManager.swift`,
`WindowManager.swift`, `AXWindowWriter.swift`, and the preferences/shortcut views.
Use this immutable revision for parity fixtures and attribution.

## Behavior

- Select the window under the pointer when the gesture begins, retaining it for
  the gesture rather than following focus changes or pointer crossings.
- Moving preserves the initial window size and offsets its origin by the pointer
  displacement. Match SwiftShift's movement snapping when enabled.
- Match SwiftShift's nine zones: four corners, four edges, and center. The center
  band is 25% of each dimension; the outer bands are 37.5% each. Preserve exact
  boundary comparisons and freeze the zone at gesture start.
- Corners resize two axes, edges one axis, and center changes both sides
  symmetrically, using SwiftShift's delta directions and geometry formulas.
- Support SwiftShift's alternative bottom-right resizing when quadrants are off.
- Match its optional snapping to visible neighboring windows, including the
  10-point threshold, overlapping-span filtering, and active-edge selection.
- Match move and resize trigger modes: keyboard-only, keyboard with mouse buttons, and
  both mouse buttons without a keyboard shortcut. Include modifier-only chords
  and supported key-plus-modifier chords. Preserve input suppression and release
  semantics; ordinary clicks must pass through when no gesture is claimed.
- Give move and resize separate triggers and reject conflicting assignments.
- Focus the target on the first movement or resizing update when configured. Respect excluded
  applications and windows that cannot be resized.
- Inspect and test the writer and shortcut state machines before implementation;
  cancellation, minimum-size behavior and app-specific AX behavior are part of
  parity, not just the rectangle calculation.

## Settings

Add a native section under Settings > Window Management:

1. Enable mouse controls (off by default; explicit local activation).
2. Separate move and resize shortcuts, with keyboard/mouse trigger controls and left/right/both buttons.
3. Use quadrants (proposed default on, because this is the requested feature).
4. Focus on window (default on, matching SwiftShift).
5. Snap to nearby windows (default on, matching SwiftShift).
6. Excluded apps, with add/remove controls and protected system exclusions.

No default move or resize shortcut is assigned, matching SwiftShift's fresh configuration.
The overall Window Management switch also disables this feature. Disabling it,
quitting, losing permission, or changing relevant configuration tears down active
tracking. Stop listening while recording a shortcut.

Persist in the appropriate Dev/release namespace. Non-capability configuration
gets settings-file bindings and backup coverage. The enable flag is treated as an
input-listening capability and cannot be enabled through backup/settings import.
Localize new strings in all eight supported languages.

## Approaches

Recommended: adapt the move/resize algorithms and interaction semantics into the
existing native WindowManagement feature. AppCore owns the lifecycle; pure models
own geometry and trigger decisions; services own event listening and AX writes.
This permits behavioral parity while following Swift 6 isolation, ownership and
permission rules. Preserve the MIT notice for adapted SwiftShift code.

Copying the entire SwiftShift app would import unrelated update,
singleton and dependency machinery. An extension does not have the existing host
capabilities required for continuous global mouse interception and AX resizing.
Neither is a good fit for this request.

Reuse ZLaunch's AX access and coordinate conventions where suitable. Do not drive
continuous resizing through the one-shot tiling command funnel. Coalesce stale
pointer updates and bound AX work so an unresponsive external app cannot stall
the launcher. Preserve VoiceOver safeguards and avoid inheriting obsolete code
or migration scaffolding from SwiftShift.

## Verification

Use source-derived fixtures for all nine zones, boundaries, delta directions,
center symmetry, movement deltas, snapping and trigger transitions. Test cancellation, disabled
state, exclusions, shortcut conflicts and persistence boundaries. Record any
intentional differences from the reference.

Follow the configured GhostVM runner and lifecycle guard for harnesses, lint and
the warning-free Debug build. Complete repository-required checks, including
model import boundaries and localization sync. Verify interactive behavior in
the guest where supported. Real pointer feel, mixed physical displays and apps
whose AX behavior cannot be reproduced in the guest remain explicitly identified
manual checks; do not claim exact live parity from unit tests alone.

Preserve existing unrelated modifications in Custom documentation and the prior
agent-control design. No publishing or installation is included in this design.
