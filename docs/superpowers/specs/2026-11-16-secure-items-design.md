# Secure Items: local Mac vault

## Intent and agreed scope

Zach wants to save API keys, links, and short notes and quickly copy them from
ZLaunch, much like snippets. The selected approach is a local Keychain-backed
Secure Items extension with native support. No cloud, server, subscription,
1Password migration, or iPhone app is part of this change.

## Approaches considered

- KeePassXC extension: portable encrypted vault, but adding and editing items
  requires another app, and its Raycast storage assumptions do not hold in ZLaunch.
- Server vault: useful for shared automation, but unnecessary operational work
  for this personal save-and-copy flow.
- Keychain-backed Secure Items: selected in conversation for the simplest local
  experience. Native support must own authentication, persistence, and clipboard
  operations; ordinary extension storage is not a secret store.

## User experience

One Secure Items launcher entry opens a locked view. Unlock with macOS owner
authentication, supporting Touch ID where available and the Mac password fallback.
After unlock, search item names and use Return to copy the selected value. Provide
Add, Edit, Reveal, Delete (with confirmation), and Lock actions. Each item has a
name and a multiline value. Values remain hidden in the list. Creating an item
must not copy it automatically. No expansion keywords or automatic paste in v1.

Proposed defaults: lock after two minutes of inactivity and immediately on system
lock, sleep, or app exit. Clear copied contents after 30 seconds only if no other
clipboard write occurred. Show success only after the Keychain write succeeds.
Failed saves retain the editor in memory for retry; lock discards the draft.

## Security and ownership

- Store names and values in encrypted Keychain item data, with opaque identifiers
  in attributes. Explicitly disable synchronization and isolate Dev/release using
  the bundle identifier. Do not silently fall back to file storage.
- Verify the supported macOS Keychain access-control and authentication design
  against current Apple documentation before implementation. Authentication must
  protect access to stored data, not merely hide a UI with already-loaded values.
- Keep sensitive editing, reveal, and copying in trusted native code. The extension
  must not persist secrets or drafts via LocalStorage, form state, preferences,
  caches, diagnostics, or generated files. A general bridge exposing arbitrary
  Keychain operations to third-party extensions is out of scope.
- Bind access to trusted bundled code; an extension name alone is not an
  authorization boundary. If the runtime cannot provide that boundary, use a
  native Secure Items surface rather than weaken the design.
- AppCore owns long-lived native state. Reuse launcher navigation and presentation
  so every theme has the same actions and keyboard behavior.
- Mark clipboard writes concealed and local-only, verify ZLaunch history ignores
  them, and cancel stale clearing tasks. Other apps can still read a copied value;
  this is not protection from a compromised Mac or all third-party clipboard tools.
- Exclude data from ZLaunch backups and settings mirrors. Do not promise memory
  zeroization for Swift strings or disaster recovery without evidence.

## Boundaries and recovery

No sync, sharing, API access, credential injection, import/export, or custom
cryptography in v1. Explain that items are local and excluded from ZLaunch exports;
retain a recoverable original of irreplaceable secrets elsewhere. App updates must
retain access under the stable signing identity. Do not modify existing Keychain
services or remove Secure Items data during extension uninstall or ordinary updates.

## Validation before delivery

Use synthetic secrets only in the disposable QA VM. Test save/read/edit/delete,
cancelled authentication, failed writes, locking, stale callbacks, clipboard-history
exclusion, conditional clearing, persistence across restart, and Dev/release
separation. Inspect persisted extension/settings artifacts for synthetic secret
leaks. Exercise keyboard flows across themes. Run required repository tests, lint,
Debug build with no new warnings, and model import checks. Verify real Touch ID
and stable signed-update Keychain access separately when hardware/signing permits;
VM checks cannot establish them. No production installation before checks pass.

## Status

Design approved by Zach; implementation and VM verification are underway.
Authentication session mechanics and trusted extension integration are builder
decisions subject to the security boundaries above.
