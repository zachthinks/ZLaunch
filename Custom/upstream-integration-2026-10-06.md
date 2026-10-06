# Upstream integration candidate — October 6, 2026

This candidate integrates Tinycast main `c048b316c4802d57ca5558df15238c12cd04f883`
into ZLaunch `eb173d0784923ed427ed0d1e37bb2ad21bd42c33`, from common ancestor
`fa1c2bb2849dd826abc43b9343abad835607bdcf`: 24 upstream commits across 177 files.
It is an integration candidate, not an installed or published release.

## Resolutions

- Keep extension-store and Dictation shutdown in AppCore.
- Use upstream's shared shortcut/alias settings implementation, with ZLaunch error wording.
- Keep ZLaunch permission descriptions and include Dictation's microphone description and entitlement.
- Retain custom Escape navigation and upstream calculator answer refocusing. Split the combined
  observer chain into two functions to avoid a Swift compiler type-check timeout.
- Preserve ZLaunch/Dev identities, signer, icons and URL schemes. Give the new helper the matching
  `com.zachthinks.zlaunch[.dev].dictation` identity and ZLaunch/Dev Dictation executable name.
- Regenerate the Xcode project from project.yml instead of hand-merging generated entries.
- Extend custom built-bundle and packaging validation to check the embedded Dictation helper.

LaunchDeck feature sources and the screenshot capture service are unchanged from the fork parent.
The existing picker focus handoff and protected setup close callback remain present.

## Verification

- All 94 standalone harnesses passed, including LaunchDeck, palette Escape, extension Store,
  AI window-capture target/staging policy, Dictation worker lifecycle, and hotkey models.
- Added explicit regressions for the persisted LaunchDeck Hyper–Space JSON and preference key,
  settings spelling, and rejecting a Dictation binding that would take Hyper–Space while restoring
  Dictation's previous binding. These use isolated fixtures, not personal settings.
- Debug and signed Release compilation passed after the observer split; both built app/helper
  identity checks passed. Deep/strict signature, hardened runtime, microphone entitlement, signer
  trust, and helper identity checks passed. Local test DMG/ZIP packaging succeeded; no notarization
  request, publication, or installation was performed.
- Lint passes with pre-existing warnings; comparison against both parent snapshots found no new
  integration-only SwiftLint warnings. Xcode emits its standard no-AppIntents metadata warning.

## Interactive QA follow-up

A separate native UI QA session verified nested navigation, invalid keys, Escape back, Settings,
Emoji focus, calculator command-Return, and Store search/details/back. The user confirmed physical
shortcut/root-close/focus checks. Screenshot capture passed using signed Dev build 16 after the
approved Screen Recording grant and reopen: a harmless System Settings window was staged, no message
was sent, and removing the attachment disabled Send. Dictation runtime/model download testing was
explicitly waived because the user uses Spokenly; its runtime behavior remains untested.

Glass tile contrast was strengthened in commit 1d723784 with a neutral adaptive scrim, edge and shadow.
Its signed Dev build 17 awaits final visual QA over white/light/dark backgrounds. Production remains
unchanged until that release gate is cleared.

## Release preparation

Release metadata now targets ZLaunch 0.1.6 with the exact upstream tag v0.11.14-beta.112 and commit
c048b316. The beta channel is explicit; release-note generation rejects mismatched channel metadata
and checks the tag resolves to the pinned commit. Automatic upstream sync still selects stable releases
and clears the beta flag for a newer stable base. If the latest stable commit is already an ancestor,
sync leaves the newer beta provenance intact. No existing ZLaunch release tag is reused.
