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

The regular **ZLaunch 0.1.5 (local build 7)** app is installed at `/Applications/ZLaunch.app`.
Build 7 adds the nested LaunchDeck editor, batch action picker, category search,
stronger setup contrast, and higher floating placement. The public 0.1.5 release
remains build 6; build 7 was installed locally after Apple notarization.
It is signed with Developer ID and notarized by Apple. Its own setup has been
imported: 59 settings, one shortcut, one favorite, 186 clipboard entries, one
note and eight learning records. Its 28 migrated extensions are enabled, and
Accessibility shows Granted in macOS settings.

**ZLaunch Dev** remains a separate development configuration. Its installed copy
and generated app copies were removed after verification of the 0.1.5 release; saved Dev data is retained.
`Custom/build.sh` can recreate it at
`build/ZLaunchDerivedData/Build/Products/Debug/ZLaunch Dev.app`. Regular ZLaunch,
Dev and Tinycast each have their own settings, extension storage, credentials,
permissions and link handler. Moving between them requires an explicit native
backup/import and, for supported extra configuration, the local migration
utility. None silently borrows another app's preferences.

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

## What is available in the Store

Open ZLaunch and search for **Store**, or choose **Browse Store…** in Settings →
Extensions. The native Store follows Raycast v1's launcher layout: a compact
keyboard-selectable list, Featured, Trending and All Extensions sections, and a
searchable category picker beside the search field (⌘P). Those sections come
from Raycast's live catalog; category filters use its actual category search.

Return opens an extension's detail page, with screenshots, its description,
commands, author, contributors, update date, README and source links when the
catalog provides them. Return on that page installs it; ⌘Return installs a
selected listing directly. Installed extensions show a checkmark. Arrow keys
navigate, ⌘K opens actions, and Escape returns to the previous screen. More
results can be loaded without losing the current selection.

Installation reuses Tinycast's prebuilt installer and update tracking. Enable
extensions before installing; the existing consent dialog still applies. No
third-party code runs just from browsing. Compatibility varies: Raycast-only AI,
browser/window services and its OAuth proxy remain unsupported. Raycast's
endpoints are unofficial and may change; folder/GitHub installation remains
available. Dev and release installations stay separate.

This Store revision is included in ZLaunch 0.1.2. Automated checks and manual
verification are recorded in `Custom/store-verification.md`.

ZLaunch also offers **Raycast Classic** under Settings → General →
Appearance → Launcher style. It gives every launcher screen a quieter surface,
smaller corners and search type, and a flat footer. **Original Glass** remains
the default. System/Light/Dark and interface size are independent choices.

## Ask AI About This Window

ZLaunch 0.1.4 adds **Ask AI About This Window** under Settings → AI → Commands.
Enable AI, select an image-capable model, and assign the command a shortcut.
Invoke it over another app to open AI Chat with that window's screenshot staged.
The screenshot stays local until you send your question. macOS may ask for
Screen & System Audio Recording permission for ZLaunch; grant it in System
Settings and relaunch if macOS requests it. AI Chat's ordinary shortcut is unchanged.

## LaunchDeck

ZLaunch 0.1.5 adds LaunchDeck: a global shortcut opens a menu, then letter keys
navigate groups and run existing apps, websites, commands, or workflows. Search
for **Configure LaunchDeck** to arrange the menu. Valid edits autosave; unfinished
edits are protected when closing setup. Menu and Appearance have separate tabs.
List, Grid, and Floating Tiles offer different presentations of the same keys.
See [LaunchDeck](shortcut-palette.md) for behavior and verification details.

## How future customization stays maintainable

User-facing app labels, permission descriptions and status messages identify
ZLaunch. About links distinguish this fork from Tinycast's upstream community
and developer; the Support window explicitly identifies upstream donations.
The `.tinycast` backup format, internal identifiers and license attribution
retain their original names.

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

The fork stays public and uses only GitHub's standard `ubuntu-latest` and
`macos-26` hosted runners. Each custom job is disabled automatically if the
repository becomes private. Custom workflows upload no Actions artifacts and
create no Actions caches. These rules are checked by `Custom/verify-config.mjs`.

GitHub checks for new **stable** upstream releases daily. It merges the released
commit into a candidate branch, keeps the custom changes, increments ZLaunch's
own version, and opens an update proposal. Build, lint, identity-isolation checks
and the complete upstream test suite run against the exact candidate commit.
An existing candidate can be resumed after an interrupted run.

The local Codex update monitor (`zlaunch-update-status`) checks at **10am and
6pm local time**. It stays quiet while nothing needs attention and reports an
actionable change or required action. These checks need this Mac available and
the Codex app open; they are separate from GitHub's daily checks. No LaunchAgent
or separate daily worker is installed.

At this initial stage, passing candidates wait for review and merging. They do
not silently replace your working app. Routine updates can later auto-merge
after we trust the tests and add branch protection. Changes to Store/UI,
permissions, the runtime, or the updater need a quick hands-on check as well as
a successful build. AI does not run automatically just because a merge failed.

Publishing currently happens on this Mac after review. The local workflow checks
the exact custom commit, builds and signs the release, notarizes it with Apple,
verifies the result, and publishes a DMG and a signature-preserving ZIP to the
fork's GitHub releases. This path has produced the published 0.1.0, 0.1.1 and 0.1.2 releases.
No Homebrew tap, upstream website or Discord announcement is touched.

Public release notes explain ZLaunch changes, include the official upstream
fixes with their source links, and link to the exact matching source commits.
A custom patch using the same Tinycast base identifies those upstream fixes as
inherited, rather than claiming them as new changes.

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
GitHub retains the conflict report in the run log and job summary; its normal
Actions notifications apply. The local Codex monitor also reports when update
status needs attention; it does not send a status message for every run.

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

## Publishing and remaining verification

Local signing and notarization are configured. `Custom/publish.sh` uses the
`ZLaunch-Local` notarization profile stored in this Mac's Keychain. No private
certificate, password or notarization credential has been uploaded to GitHub
or committed to source control.

The hosted Release workflow remains an alternative that needs separate signing
and notarization secrets before it can publish. GitHub's free daily sync and
checks already work without those secrets. Passing candidates still require
review and merging, and local publishing still requires action; maintenance is
not fully unattended.

The regular 0.1.1 app is installed and running. The real updater successfully
downloaded, verified, installed and relaunched 0.1.1 from 0.1.0. We then quit
ZLaunch cleanly, restored the retained notarized 0.1.0 app bundle, verified it
ran with the same setup, and used the in-app updater again to return to 0.1.1.
All 78 preference keys remained identical; extension files and settings stayed
intact. Only two SQLite shared-memory bookkeeping files changed during normal
launching. Tinycast remained byte-for-byte unchanged throughout.

Retain the previous signed release and the private backups. Rollback means
quitting ZLaunch and restoring its previous app bundle, while keeping its own
settings in place. The updater intentionally refuses older versions, so it
cannot perform a downgrade. To return to official Tinycast, quit ZLaunch and
open the still-installed Tinycast app; its original settings remain separate.
Older releases may not understand future data formats, so assess that before
rolling back across a major upstream change.

## Settings migration

The native Tinycast backup/import is used, preserving its format and consent
rules. It transfers selected settings, its supported shortcut types, favorites,
clipboard entries, snippets, notes and launcher learning. It deliberately omits
extension payloads/state/sign-ins, AI/MCP configuration and chats, keys, some
feature opt-ins, custom content-folder paths, Quick Actions configuration,
settings-file syncing and some per-extension/snippet/Shortcut bindings.

The separate local extension migration copies payloads and strictly screened
non-secret preferences into ZLaunch's own directories. It never copies OAuth
or Keychain items, executes an extension, or changes the official root. It also
transfers screened AI connection metadata and the saved default model, but
leaves keys and feature consents behind. Sign in again where necessary. Optional
capabilities excluded by native import remain opt-in. Check the migration report
for omitted preferences; do not assume a shortcut counted by import was
successfully registered while another app owns it.

Your pre-import backup contains private data and is stored locally outside the
Git repository. Never attach it to a public issue or commit it. Both the native
backup and extension rollback backup should be retained until you are satisfied.

## Operator reference

- `Custom/migrate-local-setup.py`: preview or apply a local, backed-up copy of
  built extensions and screened preferences between distinct bundle domains.
  Close both apps first. It never copies credentials or feature consents.
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
