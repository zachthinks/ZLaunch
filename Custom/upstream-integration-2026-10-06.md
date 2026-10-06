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

Interactive checks remain required: physical Hyper–Space dispatch, focus restoration, real Store
browsing, screenshot capture permission/UI, and microphone capture/model transcription. This session
has no supported Mac UI control tool. No installed app, permissions, model downloads, or user
configuration were changed for this candidate.

## Before a release

The release metadata still describes the last published upstream base, v0.11.12. This candidate
integrates a pinned main commit beyond that release. Before publishing, assign a new ZLaunch version
and record truthful upstream provenance/release notes; do not reuse the existing 0.1.5 release tag.
Run interactive smoke checks and the custom signing/package checks before installation or publication.
