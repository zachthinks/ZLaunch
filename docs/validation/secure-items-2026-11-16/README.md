# Secure Items validation — 2026-11-16

## Scope and status

Implements the approved local Mac Secure Items design with a native launcher
surface. The extension alternative was rejected because extension identity and
plaintext form/LocalStorage persistence are not a security boundary. No production
installation, release, real secrets, or existing user Keychain items were changed.

QA session: `4763bcae`, owned by this chat. Evidence lives at
`/Users/zlink/DEV/.vm-qa/evidence/4763bcae/` (runner retention: 30 days).

## Evidence

- Initial `SecureItemsTests` failed because implementation types did not exist;
  model/clipboard checks then passed with shipped sources.
- `SecureItemsCoordinatorTests` passed: cancellation, late authentication, failed
  write retaining the draft/committed snapshot, lock clearing, and edit blocking.
- `DeepLinkTests` passed after classifying the new open-screen command.
- Unsigned Debug build `zlaunch-build-20261116-154640` passed with no compiler
  warnings. It compiles the full feature; unsigned builds cannot
  establish data-protection Keychain access.
- Lint job `zlaunch-lint-20261116-154025` passed with no Secure Items warnings;
  pre-existing warnings remain. The migration script reports missing `.git` in
  the VM source snapshot; this is not evidence of a successful migration audit.
- `sync-strings.sh` was run in the VM. It discovered 117 unrelated new catalog keys
  and pre-existing missing translations. Only this feature's extracted entries
  were reconciled into the committed catalog; its text has all eight translations.
- XcodeGen ran in the VM; generated project changes were pulled back.
- Real Debug UI in the VM displayed the locked screen and owner-authentication
  password dialog. Authentication did not dismiss the palette. Screenshots are
  `pulled/secure-items-locked.png` and `pulled/secure-items-auth.png`.
  Returning to the launcher during authentication and reopening restored the
  locked screen (`pulled/secure-items-cancelled.png`).

- Full suite passed: all 118 harnesses, 195 seconds, with two compile workers.
  Evidence: `pulled/secure-items-suite-quiet.log`. A previous concurrent-build run
  timed out in the unrelated ClipboardText harness; the isolated rerun passed it.
- Model import check passed; no AppKit, SwiftUI, or Cocoa imports in feature models.
- `git diff --check` passed.

## Review and fixes

Independent review identified missing provisioning, editable native text during
save, and ordinary clipboard copying from the Name field. Both native text fields
now honor disabled state and use the protected clipboard; coordinator setters also
reject edits during saves. Entitlements now declare separate app-specific access
groups; provisioning and signed runtime verification are recorded below.

## Signed runtime verification

Follow-up QA session: `28d6de47`. Both explicit app identifiers and Developer ID
profiles were created with Zach's per-action approval. Profiles were downloaded
and installed in Xcode's private local profile directory. They were not committed
or uploaded to GitHub. Both authorize the expected application identifier.

- Release compiled in the guest (`pulled/secure-items-release-build.log`). Debug
  job `zlaunch-build-20261116-162620` passed after profile selection was added to
  the main app target; the generated Xcode project was pulled back. Helpers do not
  inherit the main app's profile selector.
- Both guest-built app bundles were signed on the host with the existing Developer
  ID identity and their respective embedded profiles, then copied back to the VM.
  Strict recursive signature verification passed. No host app was launched or
  installed, no private signing key was copied to the guest, and no notarization
  or publication was attempted.
- Production: owner-password authentication, empty vault read, synthetic Unicode
  item creation, app restart, fresh authentication, exact value retrieval/copy,
  and edit/save/reopen all succeeded.
- Actual clipboard contents matched the restored synthetic value immediately after
  copy and were empty after a 35-second observation interval (30-second timeout).
- A targeted plaintext scan of the production app's Application Support, Caches,
  and preferences locations found neither the synthetic value nor its item name.
  This is a scoped scan, not a general forensic guarantee.
- Dev authenticated and opened an empty vault while production's test item existed.
  A separate disposable Dev item saved successfully and was deleted through the
  native confirmation dialog; the list then showed no items.
- UI evidence: `pulled/secure-items-restored.png`,
  `pulled/secure-items-dev-isolated.png`, and `pulled/secure-items-deleted.png`.
- Lint job `zlaunch-lint-20261116-162110` passed with existing unrelated warnings.
  Its migration check still lacks Git history in the VM source snapshot.

The UI automation occasionally returned indeterminate action receipts; subsequent
fresh observations established outcomes before proceeding. A stale editor/action
snapshot encountered the idle lock, which correctly cleared the session. No claim
is made for the attempted keyboard deletion; the menu-driven deletion was verified.

## Remaining release gates

Before publishing, install the production profile privately in hosted signing and
verify a signed update preserves vault access. The current app was manually signed
for isolated runtime QA; the full provisioned Xcode/release pipeline has not run.
Real Touch ID and hardware sleep behavior remain unverified. All appearance/theme
variants still require a visual pass; the feature uses a shared native surface and
has no theme-specific behavior. Dev/release UI isolation was observed, but no
adversarial cross-group read probe was run. No production update was installed.
