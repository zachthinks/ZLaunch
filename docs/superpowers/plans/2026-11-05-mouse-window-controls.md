# Mouse Window Controls Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement task-by-task.

**Goal:** Reproduce SwiftShift moving, nine-zone resizing, snapping and related settings in ZLaunch.

**Architecture:** Pure geometry and trigger models feed a native event tap and serial AX worker.
AppCore owns a coordinator; AppSettings owns configuration and the local enable flag.

**Tech Stack:** Swift 6, AppKit, SwiftUI, CoreGraphics, Accessibility; no added dependencies.

**Spec:** ../specs/2026-11-05-mouse-resizing-design.md (approved November 5).

## Global Constraints

- macOS 26+, Swift 6 strict concurrency; no new singleton or actor.
- Source edits in this checkout; configured GhostVM runner for builds/tests/lint.
- Preserve unrelated Custom edits and installed apps; no publishing or installation.
- Explicit local activation; backup/settings files cannot enable input interception.
- Localize all settings in the eight supported translations.
- No additional gesture overlay: reference gesture paths provide live-window feedback.

## Review Focus

- Normal clicks and releases must survive failed targeting and cancellation.
- Hung AX clients must not stall the launcher or apply stale updates to a new gesture.
- Modifier changes, Space changes, permission loss and recording must cancel tracking.
- Background windows and mixed displays use pointer targeting and global AX coordinates.
- Imports must reject invalid/conflicting triggers and cannot activate listening.

## Task 1: Geometry and trigger policy

Files: WindowManagement/Model/MouseWindowGeometry.swift, MouseWindowTrigger.swift,
MouseWindowInput.swift; Tests/mouse-window-test.swift; Scripts/run-tests.sh.

Interfaces: `MouseWindowGeometry.frame(initial:pointerStart:pointer:action:zone:neighbors:)`
returns CGRect; `zone(at:in:)` returns Zone. Trigger validates a keyboard chord and
mouse-button mask; input state returns ordered begin/update/end effects and consumption.

- [x] Add fixtures for nine zones/boundaries, center symmetry, movement and 10pt snapping.
- [x] Add trigger/release/cancellation tests; observe missing-feature failure in guest.
- [x] Implement models and pass fixtures in guest.

## Task 2: Native runtime

Files: WindowManagement/Service/MouseWindowMonitor.swift, MouseWindowSession.swift;
WindowManagement/UI/MouseWindowCoordinator.swift; App/AppCore.swift.

Interfaces: coordinator applies settings and stops; monitor configures Sendable options;
session owns target lookup and ordered/coalesced AX writes off-main.

- [x] Implement pointer hit-testing, excluded apps and bounded AX writes.
- [x] Implement event suppression/replay, modifier/button/key transitions and teardown.
- [x] Wire recording, permissions, wake/session/display changes and explicit local enable.
- [x] Build in the guest; verify no new warnings.

## Task 3: Settings and persistence

Files: AppSettings.swift, AppSettingsKey.swift, SettingsFileKey.swift,
SettingsFileSchema.swift, SettingsBackup.swift, SettingsBackupCoverage.swift,
WindowManagement/Settings/MouseWindowSettingsSection.swift, MouseWindowShortcutRecorder.swift,
WindowManagementSettingsView.swift, SettingsAnchor.swift, SettingsSearchCatalog.swift,
SettingsEditorPresenter.swift, Localizable.xcstrings.

- [x] Add separate move/resize trigger controls, quadrants, focus, snap and exclusions.
- [x] Validate persisted configurations and conflicts; exclude enable from imports.
- [x] Add settings search anchors and eight translations; run string extraction in guest.
  Extraction exposed 118 unrelated absent keys; preserve those as a pre-existing localization backlog.
- [x] Test persistence and search/localization integrity.

## Task 4: Verification and review

- [x] Run full harness suite, warning-free Debug build, lint and model purity check.
- [x] Inspect the guest settings UI; live gesture and physical-display validation remain unverified.
- [x] Update feature docs and SwiftShift MIT attribution.
- [x] Obtain fresh final code review and address material findings.
- [x] End task-owned VM lease; guest suspended and manager closed.

## Verification evidence

Full suite: job `96d51ace11c6`, snapshot `833150535e42bd5d7b10`, 108/108 passed.
Debug build: `e2de6f3111c1`, same snapshot, passed with only existing AppIntents metadata warnings.
Lint: `599733f10491`, snapshot `2a4b7c1e0b41889ca888`, passed including settings search and translations.
Model import and whitespace checks passed. Independent review findings on cancellation, replay,
atomic imports, modifier conflicts and minimum-size anchoring were addressed. Guest AX inspection
verified the controls and disabled default. A screenshot exposed compressed trigger labels;
the local picker layout was corrected, rebuilt, and visually verified in the guest.

The first full suite also hit the existing file-search timing fixture; it passed unchanged
in the complete rerun. The relaunch stub now covers mouse teardown before other cleanup.

No host app was launched, installed, signed or released. Synthetic cancellation fixtures
compile the shipped session against an AX stand-in; they do not establish real-app gesture parity.

Final UI build `e5fb4be6b0d6` (`a9ab1af4e9e094bd767c`) passed; final lint
`691787c4557b` (`66eb48d7fc56ca506e06`) passed. Changes since the full suite
were layout, translations, generated project entries and whitespace only.
Guest screenshots: `QA-Projects/zlaunch/jobs/mouse-settings-final.png`.
