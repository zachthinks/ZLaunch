# Secure Items Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a local authenticated save/search/copy vault inside ZLaunch.

**Architecture:** Use a native palette surface because extension identifiers and JSON form persistence do not provide the required trusted boundary. A dedicated Keychain service stores one encoded vault with user-presence access control; a coordinator owns its short-lived authenticated session and clipboard lease.

**Tech Stack:** Swift 6, SwiftUI/AppKit, Security, LocalAuthentication.

**Spec:** docs/superpowers/specs/2026-11-16-secure-items-design.md

## Global Constraints

Mac only; no sync, exports, plaintext persistence, third-party dependencies, or generic extension Keychain bridge. Two-minute idle lock; 30-second conditional clipboard clearing. All builds/tests in QA VM. Existing user changes in AGENTS.md and Custom/README.md are untouched.

## Review Focus

- Cancelled/late authentication cannot reopen a locked session.
- Failed writes preserve the editor and last committed snapshot.
- Clipboard replacement must survive an older secret's timeout.
- Empty, duplicate-name, multiline, and Unicode values round-trip without trimming secrets.
- Lock/sleep/navigation must clear editor and revealed content; copied text must bypass history.

### Task 1: Vault model and protected storage

Files: Features/SecureItems/Model/SecureItem.swift; Service/SecureItemsKeychain.swift; Tests/SecureItemsTests.swift; Scripts/run-tests.sh.
Interfaces: SecureItem(id:name:value:); SecureItemsKeychain.read(context:) async throws -> [SecureItem]; write(_:context:) async throws.
- [x] Add and run failing round-trip/validation tests in the VM.
- [x] Implement pure item validation and storage with a local-only, device-only user-presence ACL and explicit errors.
- [x] Verify model tests and compile storage against the guest SDK.

### Task 2: Session and clipboard ownership

Files: Service/SecureItemsClipboard.swift; UI/SecureItemsCoordinator.swift; App/AppCore.swift.
Interfaces: coordinator.unlock(), lock(), edit(_:), save(), copy(_:), delete(_:); clipboard.copy(_:), clearIfOwned().
- [x] Test conditional clearing on a private pasteboard and stale completion/session policy.
- [x] Implement owned authentication, cancellable operations, idle lock, sleep/session notifications, and transactional writes.
- [x] Verify failures never publish a success or overwrite the committed snapshot.

### Task 3: Palette integration and delivery checks

Files: UI/SecureItemsScreen.swift; UI/SecureItemEditor.swift; Palette/PaletteMode.swift; Palette/RootPaletteView.swift; Launcher/Model/CommandID.swift; Launcher/UI/LauncherCoordinator.swift; Resources/Localizable.xcstrings; docs/features/secure-items.md.
Interfaces: SecureItemsScreen(coordinator:vm:); native editor mode uses Command-Return for save.
- [x] Add launcher command, protected list, editor, reveal/delete/lock actions, and keyboard navigation.
- [x] Localize added text in all eight translations and regenerate Xcode project in guest.
- [x] Run focused tests then full harness suite, lint, model import check, and Debug build.
- [x] Verify signed synthetic-secret create/read/edit/delete/copy flows in VM and inspect app persistence for plaintext; record remaining release/theme/hardware gates in the validation report.
- [x] Obtain independent security/code review, resolve material findings, and record remaining hardware/signing limits.
