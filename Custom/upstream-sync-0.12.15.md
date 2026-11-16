# Tinycast v0.12.15 integration — November 16, 2026

## Source and resolution

- Previous ZLaunch source: `b58074a46610768e6a07a8afe2ac8b92b0ae1c38` (0.1.19).
- Imported stable upstream: `6fa8ba1225be0777ef769f1816bffc7da213f91d` (`v0.12.15`).
- Prepared ZLaunch version: 0.1.20. This integration does not publish or install a release.
- Resolved all 12 conflicts. Kept fork bundle IDs, URL schemes, signer trust, updater feed,
  custom test coverage, LaunchDeck, window layouts, Store and AI window capture.
- Retained upstream harness renames while preserving custom layout helper cases and Store,
  LaunchDeck, window-space and AI capture harness inputs. The extension sign-in test continues
  to compile ZLaunch's `ExtensionOAuthSession.swift`; the removed support reminder stays removed.
- Applied upstream's macOS 26 compact-bar shadow mask only to Original Glass. Classic keeps
  opaque rounded surfaces without the glass scrim. Both use the same commands, selection,
  activation and visibility lifecycle; the shared palette restores its window shadow on settle.
- Merged localization entries by three-way JSON comparison: no competing content edits.
- Kept ZLaunch data paths and helper IDs. Upstream's bundle migration rejects ZLaunch IDs;
  added explicit stable/Dev/beta assertions and official-ID update-channel rejection checks.
  The official Tinycast handoff target is excluded from the fork project.
- Regenerated `Tinycast.xcodeproj` with XcodeGen inside the QA VM.

## Validation

Owned disposable session: `af64a12d`, macOS 26.6.2, Xcode 26.6 (17F113).
Evidence: `/Users/zlink/DEV/.vm-qa/evidence/af64a12d/`.

- Final `Scripts/run-tests.sh`: **116/116 passed**, 94 seconds.
- `Scripts/lint.sh`: passed. **82 warnings**, identical warning messages/counts to the
  pre-merge `b58074a4` baseline; test filenames changed upstream.
- Unsigned Debug build: passed. No Swift compiler warnings. Xcode emitted its non-blocking
  App Intents metadata-extraction notice because the app has no AppIntents dependency.
- `Custom/verify-config.mjs`, all 11 `Custom/tests/*.mjs` suites, generated-project consistency,
  built-bundle/helper identity, architecture and URL isolation checks: passed.
- Model-layer UI-import scan: passed.
- Live guest UI: both Classic and Original Glass opened Clipboard and Emoji using Right/Return,
  returned with Escape, accepted calculator typing after Down (2+2 = 4), found Configure
  LaunchDeck, and loaded Featured/Trending/All Extensions through the Store command.
  LaunchDeck Setup opened with its menu editor. Captured and inspected both compact appearances.

The initial harness run found the stale extension sign-in source path; the final complete run
above includes its correction. An initial policy run lacked a source script in the VM transfer;
all policy suites passed after adding source-only Custom scripts to the project transfer list.
UI checks ran against disposable Dev data; no extension was installed and no personal data
or credentials were transferred. macOS 27 rendering, physical-device permissions, live OAuth,
signing/notarization and production installation are outside this check.

## Recovery

The merge's first parent is the unchanged 0.1.19 source. No installed app, official Tinycast
state or production ZLaunch data was changed. Review/revert the merge to recover source;
publication remains a separate release operation with the existing protected approval.
