# Upstream v0.12.1 integration

Integrated stable Tinycast `v0.12.1` (`ead1f770401b34f69065e279704a119d04609986`)
onto ZLaunch `5a5f20af`, preparing custom version 0.1.13. The October 22 scheduled
sync (`39827797466`) stopped on merge conflicts. Unreleased upstream main is not
part of this integration.

## Preserved custom behavior

- Store browsing, detail pages and screenshot previews remain in the palette.
- LaunchDeck, window arrangements, Spaces and fallback geometry remain intact.
- Original Glass and Raycast Classic remain separate appearance choices.
- Extension OAuth retains channel-specific callback validation and Keychain token
  storage. Upstream's Raycast callback registration and JSON token storage are
  intentionally not adopted.
- Useful Files remains the default persisted filter, including project source and
  configuration files. Everything restores unknown/generated files while obeying
  explicit ignores. Exclusion actions remain available.
- Release/Dev identity, update feed and signer checks remain isolated.

## Upstream behavior change

File Search now uses upstream's private disk index and helper rather than
Spotlight. Full Disk Access is required before indexing. The default scope is
home, and ignore defaults can be edited. No permission was granted on the host.
Useful Files filtering happens before the result cap in both snapshot and live
index searches. Recent Files excludes source churn. The new helper is included
in bundle, packaging and hardened-runtime verification.

## Validation

All execution uses the configured GhostVM guest, with filtered source snapshots.
Debug build `4efda8329f66` passed for source `d2da5b8bd897e21a321d`: no Swift
compiler warnings; two existing AppIntents metadata-extraction warnings.
Lint `c381257a2c51` passed, including settings-search and localization checks.
The one warning in the newly edited session test was subsequently corrected.

Initial failures were retained in guest logs: a fixed-sleep Recent test,
a privacy-string assertion expecting the upstream brand, and a new index fixture
using a folder that an earlier case renamed. Tests now wait for completion,
assert the ZLaunch identity, and use the current fixture path.

Final suite: **107/107 harnesses passed**, job `4930fba11f79`, source
`32cbbad2713de4438905`. App source is unchanged from the successful Debug build.
All custom policy tests, generated-project consistency, bundle identity/helper
checks and lint passed in `jobs/upstream-v0121-extra` after the manifest-listed
custom sources were transferred and hash-verified.

Runtime fixtures also pass. Their final overlay hashes are in `results.json`:
merged OAuth fixtures now have distinct names, and the test host passes failed
calls as raw messages, matching Swift rather than adding JSON quotation marks.
No production runtime code changed for that fixture correction.

The guest desktop unlocked with one click, as requested. Using the pinned guest
Peekaboo bridge, launcher search, Store catalog, Return-to-detail navigation,
in-palette screenshot preview and Escape back-navigation passed. Dismissal and
reopening via the Dev URL restored an empty focused search; entering `x` produced
Xcode results. The preview capture was inspected visually (`store-preview.png`).
Compact accessibility evidence is saved in `ui-evidence.json`.

Peekaboo's multi-character background typing stopped after `St` when a dynamic
AX receipt became stale. Fresh observation confirmed the partial input; direct
AX replacement completed the Store query. Single-character input after reopening
was confirmed by a fresh observation, despite the CLI's unverified dispatch result.
Global shortcut, keypad Enter, permission-gated real file indexing and extension
installation were not exercised. No permissions or extension enablement changed.

No host production installation, signing, notarization, publication or upstream
push is part of this validation. The pre-existing release-efficiency documentation
edit is preserved outside the integration commit.
