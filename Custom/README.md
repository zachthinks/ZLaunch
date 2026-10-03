# ZLaunch: your launcher, with an upstream safety net

ZLaunch is your separate version of Tinycast. Tinycast remains installed at
`/Applications/Tinycast.app`; nothing here removes it. The working project lives
at `/Users/zlink/DEV/ZLaunch`, and your fork is
https://github.com/zachthinks/ZLaunch. The official source is
https://github.com/abue-ammar/tinycast.

You do not need to learn Git to use this. Ask Codex to change ZLaunch, review the
result, and let the checked workflow prepare updates. Keep this project as the
place where future changes happen.

## Using it today

The first app is **ZLaunch Dev**, a signed development build in
`build/ZLaunchDerivedData/Build/Products/Debug/ZLaunch Dev.app`. It has its own
settings, extension storage, credentials, permissions and link handler. The
release app will be **ZLaunch**, with its own separate settings too. Moving from
Dev to Release needs another native backup/import; it never silently borrows
Tinycast's preferences.

Both apps can stay installed. After importing matching shortcuts, run one at a
time. In particular, Caps Lock/Hyper Key uses a shared macOS keyboard mapping.
Quit ZLaunch before opening Tinycast for rollback; quit Tinycast before returning
to ZLaunch. Keep launch-at-login off until you choose your daily app. Permissions
such as Accessibility are granted separately in System Settings when you want
pasting, text expansion or Hyper Key. The custom app never registers `raycast://`
or `tinycast://`, so it does not take over the other apps' external links.
OAuth callbacks are routed to the current channel. Providers using native
callbacks must register `zlaunch://oauth` or `zlaunch-dev://oauth`, and the
extension must supply that URI. A provider tied only to Raycast callbacks
cannot work unchanged; HTTPS relays must support the custom scheme. Live
provider/relay compatibility remains unverified.

## What is already available in the Store

Tinycast already supplies Raycast Store search, download/install, update checks,
GitHub-source installation, and native List/Detail/Form/Grid/menu-bar rendering.
ZLaunch reuses that implementation. Its first discovery screen adds shortcuts to
Developer Tools, Productivity, Notes and AI searches. Those buttons are search
starting points, not a new category API or a compatibility guarantee.

The store lives in Settings → Extensions. Enable extensions, then open Search.
Extension compatibility varies: Raycast-only AI, browser/window services and the
OAuth proxy are not implemented. The search endpoint is unofficial and could
change; folder/GitHub installation remains an alternative. No third-party code
is run just by showing a search result.

## How future customization stays maintainable

An extension is the first choice for a new command or service that fits the
existing extension API. Keep your own extension source outside the launcher and
install its built folder. Use a native patch only for app-owned capabilities
that extensions cannot provide: Store installation controls, main launcher
layout, global preferences, update identity and host rendering. Keep those
patches narrowly scoped, with one purpose per commit. Do not rebuild the
extension installer or fork all of Raycast's extension collection.

The upstream SwiftUI/AppKit app uses Swift 6 and Xcode 26, targeting macOS 26.
It embeds the clipboard OCR helper and a committed JavaScriptCore runtime.
Building the app does not require Node; changing that runtime does. Its project
file is generated from `project.yml` using XcodeGen. Existing architecture,
performance constraints, AGPL license and attribution remain in place. Shipping
modified binaries should include access to the matching source; releases link
to the exact source commit in this public fork.

## What happens automatically

Once the custom branch is pushed and made the fork's default branch, GitHub
checks for new **stable** upstream releases daily. It merges the released commit
into a candidate branch, keeps your custom changes, increments ZLaunch's own
version, and opens an update proposal. Build, lint, identity-isolation checks
and the complete upstream test suite run against the exact candidate commit.
An existing candidate can be resumed after an interrupted run.

At this initial stage, passing candidates wait for review and merging. They do
not silently replace your working app. Routine updates can later auto-merge
after we trust the tests and add branch protection. Changes to Store/UI,
permissions, the runtime, or the updater need a quick hands-on check as well as
a successful build. AI does not run automatically just because a merge failed.

The Release workflow is implemented and manually triggered for now. After its
one-time signing/notarization setup, it checks the custom branch, builds the
release, signs with your Developer ID, notarizes with Apple, verifies the result,
and publishes a DMG and a signature-preserving ZIP to your GitHub releases.
No Homebrew tap, upstream website or Discord announcement is touched.

The existing Tinycast updater is reused rather than adding Sparkle. Release
ZLaunch checks **your fork's** GitHub releases. A newer valid version can show an
in-app Update prompt. Before replacement, it checks the bundle identifier,
version and complete signed bundle against your Apple signing team. The Dev
app never updates itself. The custom version starts at 0.1.0 and is independent
of Tinycast's version; `Custom/release.json` records both the upstream tag and
commit so we can always identify its base.

## When something conflicts

A textual merge conflict stops the sync. Automation records the upstream tag,
commit and affected files, aborts the merge, and leaves the last working custom
branch and installed app intact. A failed test or build also prevents release.
GitHub retains the failure/report in the run; its normal Actions notifications
apply. This project does not install a separate chat reminder or promise a
notification on every run.

Tell Codex: “Resolve the latest ZLaunch upstream update while preserving my
Store and customization.” Codex should read the failure, compare the official
change with the custom patch, and propose the smallest integration. For a real
product choice—such as upstream redesigning the same screen—it should show you
the alternatives in plain English. AI then runs tests and builds a separate
Dev app for review. It must never solve conflicts by discarding your feature,
weakening signature checks, sharing Tinycast data, or publishing failing tests.

A change can merge cleanly and still behave differently; that is why tests and
hands-on verification remain necessary. No promise that all future conflicts
will be rare or automatically resolvable is made.

## One-time online release setup still needed

A local Developer ID identity exists and has signed the Dev build. Hosted release
signing needs its private certificate placed securely in GitHub Secrets, plus
Apple notarization credentials. No private certificate or password has been
exported or uploaded by this setup. Do not put those in chat or source control.

The hosted workflow expects `ZLAUNCH_SIGNING_P12_BASE64`,
`ZLAUNCH_SIGNING_P12_PASSWORD`, `ZLAUNCH_APPLE_ID`, and `ZLAUNCH_APP_PASSWORD` in
the `zlaunch-release` environment. An operator can instead publish on this Mac
using a notarization Keychain profile and `Custom/publish.sh`. Before activating
release, configure review protection for that environment, verify the full
workflow with a real signed/notarized artifact, and test one in-app update and
rollback using only custom bundles. Until then, online updates are prepared,
not live.

## Settings migration

The native Tinycast backup/import is used, preserving its format and consent
rules. It transfers selected settings, its supported shortcut types, favorites,
clipboard entries, snippets, notes and launcher learning. It deliberately omits
extension payloads/state/sign-ins, AI/MCP configuration and chats, keys, some
feature opt-ins, custom content-folder paths, Quick Actions configuration,
settings-file syncing and some per-extension/snippet/Shortcut bindings.

The separate local extension migration copies payloads and strictly screened
non-secret preferences into ZLaunch's own directories. It never copies OAuth
or Keychain items, executes an extension, or changes the official root. Sign in
again where necessary. Optional capabilities excluded by native import remain
opt-in. Check the migration report for omitted preferences; do not assume a
shortcut counted by import was successfully registered while another app owns it.

Your pre-import backup contains private data and is stored locally outside the
Git repository. Never attach it to a public issue or commit it. Both the native
backup and extension rollback backup should be retained until you are satisfied.

## Operator reference

- `Custom/build.sh`: signed Dev build; `CONFIGURATION=Release` selects Release.
- `Custom/check.sh`: full tests, lint, project regeneration consistency, clean
  unsigned Debug build, and source identity checks.
- `Custom/sync.mjs`: clean `custom/main` only; released upstream commit into an
  isolated candidate, with rollback on conflicts.
- `Custom/package.sh`: verifies release identity, signature and arm64 app/helper,
  then creates DMG/ZIP and checksums. It does not claim notarization on its own.
- `Custom/publish.sh`: requires clean, pushed custom/main and a notarization
  Keychain profile; checks/builds/notarizes before publishing the exact commit.
- `Custom/signature-test.swift`: real custom bundle accepted, official bundle and
  a tampered copy rejected.

The official remote is `upstream` and its push URL is disabled locally. Your
remote is `origin`. Custom work stays on `custom/main`; the upstream main branch
and tags are retained as reference history. Keep new features and maintenance
changes in distinct commits rather than rewriting upstream history.
