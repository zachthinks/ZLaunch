# Rooms, Terminal ownership, and Window Layout Spaces

Prepared October 13, 2026, on `custom/main`. No production installation or release was performed.

## Implemented behavior

- A layout entry chooses a preferred monitor and a regular macOS Desktop number on that monitor.
- Each entry can enable a fallback monitor and Desktop. An unavailable fallback monitor uses the
  built-in display, or the first available display on a desktop Mac. Geometry uses the selected
  display's visible frame; the preferred destination remains saved for reconnection.
- Missing Desktops skip the affected entry with an explicit report. No Desktop is created silently.
- The bridged SkyLight move operation verifies membership before correcting geometry. It requires
  no SIP change, Dock injection, external window manager or scripting addition.
- Rooms and layouts identify Terminal windows by window number plus Terminal launch date, rather
  than arbitrary matching titles or proximity. Missing members request individually created windows.
- Other terminals stay in place; Rooms do not park or hide them. Captured minimized terminals can
  be restored by layouts. Duplicated layouts do not inherit the original's Terminal ownership.
- Destinations round-trip through backups and settings.json. Session-specific Terminal identities
  stay out of settings.json and matching entries retain their local binding after file edits.

Rooms still tile together on the launcher display. The multi-monitor/Space controls are in
Window Layouts' entry inspector. Terminal layout arguments currently accept an existing folder path.

## Guest verification

The existing `ZLaunch-QA` GhostVM guest was used through the shared runner and its filtered source
selection. SIP was verified enabled on macOS 26.3.2. No host shares, clipboard sync, forwarding,
credentials, production preferences or private documents were added to the guest.

- Full suite: job `45926b90b864`, source `d5ac1779604dddc7d457`, exit 0, all 95 harnesses passed.
  A prior rerun had an unrelated `mcp-oauth-test` listenerUnavailable failure; the complete rerun
  passed without changing that test. The final source differs only in the two dropdown views and
  their generated project registration; the tested model, services, and test files are unchanged.
- Final Debug build: job `f8f444b69953`, source `42b03f87a7bc963d5af8`, exit 0. No new Swift warnings.
  The pre-existing AppIntents metadata-extraction warning remains.
- Final lint: guest `QA-Projects/zlaunch/tools/lint-final.exit` is 0 and the log ends `lint-clean`.
  Official SwiftLint 0.65.1 was placed in this guest project's tools directory; the host was not changed.
- A disposable AppKit window moved from native Space ID 1 to Space ID 13 (Desktop 2), then back
  to ID 1. Membership was confirmed in both directions; the probe exited 0 and closed its window.
- Native API availability and regular Desktop enumeration were verified in the guest.
- The actual final destination views rendered with a synthetic disconnected external monitor,
  preferred Space 2, and built-in-screen fallback Space 3. The image is
  [room-space-controls.png](QA/room-space-controls.png). This is a standalone render, not a
  screenshot of a fully exercised application editor.
- The Terminal automation probe initially received error -1743 and emitted the intended permission
  guidance. After the user opened the disposable guest TerminalQA app and allowed Automation,
  the shipped service created two distinct Terminal windows (273 and 274). The second moved to
  Space ID 13, returned to ID 1, and confirmed membership in both directions. The probe logged
  PASS and exited 0. Its two blank guest Terminal windows remain available for inspection.

## Limits and follow-up

The pinned Peekaboo bridge's interactive requests were refused as runtime_incompatible, despite
successful handshake and permission reads. No host GUI fallback was used after adopting the VM workflow.
The user created extra guest Desktops and granted the disposable test app Terminal Automation manually.
Full editor clicks/keyboard/save/reopen behavior was not verified through that bridge. The guest has one virtual display;
disconnected/reconnected multi-monitor behavior is covered by injected display fixtures, not physical
monitor removal. Creating absent Desktops is outside the feature's scope.

Before the VM-first correction, the host ran tests/build/lint and a disposable native-window API probe.
The temporary host window returned and closed. A stalled host Terminal test helper was stopped; its
result was not used as evidence. The attempted host Dev launch was cleaned up. Subsequent checks used
the QA VM. The existing production ZLaunch installation was not replaced.

Guest logs remain in `~/QA-Projects/zlaunch/jobs/`, and the native probes/render remain in
`~/QA-Projects/zlaunch/space-probe/`. The VM is left running with the user-created Desktops.

## Local production installation

On October 13, 2026, source `84ed43c1` was built from a clean committed snapshot as ZLaunch
0.1.6 (20), signed with the established Developer ID, notarized by Apple, and installed at
`/Applications/ZLaunch.app`. Gatekeeper and deep/strict signature verification passed.
Unrelated uncommitted workspace changes were excluded. No public release was published.

The running production About screen confirmed 0.1.6 (20). The existing Codex layout editor
displayed preferred screen and Space controls. Its picker enumerated three available Desktops
and marked absent Desktops unavailable. Enabling fallback in an unsaved draft displayed its
screen and Space controls; Cancel discarded the draft. No production Room/layout was run.

The prior build 19 bundle, rollback ZIP, build/notarization logs, and installation receipt remain
in ignored `build/room-spaces-install-receipt/`. The complete preference-file hash changed during
relaunch and UI inspection; that hash alone does not establish which runtime preferences changed.
The installation replaced only the app bundle, and no saved layout edits were submitted.
