# Native Store verification for 0.1.2

Pre-release verification below was performed in the isolated Dev channel.
Release packaging and installation are verified separately.

## Automated checks

- All 84 standalone harnesses passed after the final branding and Escape changes (41 seconds).
- Store model fixtures cover real catalog metadata, owner handles, categories,
  search totals and browse pagination, including delisted entries.
- Palette filter fixtures cover Store category shortcuts and the detail screen.
- Debug built and signed successfully. The existing AppIntents metadata warning
  is unchanged; no new Swift compiler warnings were introduced.
- Lint passed; changed Store sources have no lint warnings.
- Pure models contain no AppKit, SwiftUI or Cocoa imports.
- `git diff --check` passed.

## Manual observations

- Inspected the installed Raycast v1 Store without accepting its v2 upgrade.
- Opened Store from the rebuilt ZLaunch Dev launcher.
- Featured, Trending and All Extensions display live catalog entries.
- Return opens a detail page with screenshots, commands and metadata links.
- Back navigation returns to the Store list.
- Escape is routed through the panel for Store screens, including details with
  no focused text field. Verified Escape returns details → Store → launcher in
  the rebuilt Dev app; the original launcher query is restored.
- Category picker lists the original categories; Developer Tools filters the feed.
- Searching GitHub within Developer Tools returns scoped results.
- Load More appends another page to the same list.
- Installed extensions show a checkmark.
- Screenshots now request original resolution rather than the icon thumbnail.
- The category control now uses the trailing header position.
- Selected Raycast Classic in Dev settings and verified its darker surface,
  smaller corners, flat actions and solid header/footer in the running preview.
- Verified the green Store tile, white bag outline and yellow bolt at launcher
  size and in the Store footer; color artwork is preserved by the icon cache.
- Verified full-resolution detail screenshots in the final running preview.
- The launcher style is persisted per app channel and included in settings.json
  and native backups; backup coverage checks pass.

## Remaining verification

No new third-party extension was installed during this pass. Store installation
reuses the existing prebuilt installer, consent and update tracking. Provider
OAuth and Raycast-only service compatibility remain separate limitations.
The optional Raycast Classic launcher style is a first native styling pass,
not a claim of pixel-perfect parity. Original Glass remains the default.

## Released and installed — 2026-10-03

- Published ZLaunch 0.1.2 (build 3) from commit
  `92a3b1cf6d89256d72e4bb4594342d83bd29a351`.
- Release: https://github.com/zachthinks/ZLaunch/releases/tag/v0.1.2
- Optimized Release build succeeded with no new compiler warnings.
- Apple notarization accepted; ticket stapled; Gatekeeper accepted the app.
- Installed through the existing in-app updater and relaunched successfully.
- `/Applications/ZLaunch.app` reports 0.1.2 (3); strict deep signature verification passed.
- About displays ZLaunch 0.1.2 (3) and the correct fork links.
- Selected Raycast Classic in the regular app; live Store catalog and installed
  extension markers verified. Detail screenshots and metadata loaded.
- Escape returned detail → Store → launcher and restored the Store query.
- Removed the generated Debug/ZLaunch Dev.app. No Dev app remains in
  `/Applications` or `~/Applications`; saved Dev data was preserved.
- Publication log: `/tmp/zlaunch-012-publish.log` (local, temporary).
- Distribution artifacts and checksums: `dist/` (local, ignored).
