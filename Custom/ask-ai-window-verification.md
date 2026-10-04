# Ask AI About This Window verification

Verified 2026-10-04 for the 0.1.4 release.

- All 84 harnesses passed, including capture-target selection and chat staging regressions.
- Debug compilation passed; the only build warning was the existing App Intents metadata
  extraction notice. Lint passed with existing repository warnings, and Model purity passed.
- A live ScreenCaptureKit test using temporary AppKit windows captured only the selected
  window despite another window overlapping it. PNG encoding, attachment preview and image
  limits passed. A closed-window test exposed cached ScreenCaptureKit content; fresh window
  server visibility checks now refuse that content, and the live test passed on retry.
- The signed Dev app showed the command under AI settings, accepted a separate shortcut,
  retained it across restart, and found the command in launcher search. Running it through
  the launcher displayed actionable Screen & System Audio Recording guidance when the Dev
  app lacked permission. Temporary Dev AI enablement and shortcut binding were restored.
- Screen capture permission was not granted to the Dev app. Full-app successful attachment
  presentation, physical global-shortcut dispatch and multi-display/fullscreen behavior
  remain hands-on checks; the capture service itself was verified live. No provider prompt
  or screenshot was sent during verification.

## Release and installation

- Source `121c671c204b6796e3d2ee7002bd4c7a590fe216` was pushed to `custom/main`.
- The full `Custom/check.sh` passed for 0.1.4 build 5 before publishing.
- Apple notarization was accepted; stapling, signature verification and Gatekeeper passed.
- The public GitHub release contains the DMG, updater ZIP and matching SHA256SUMS:
  https://github.com/zachthinks/ZLaunch/releases/tag/v0.1.4
- The real 0.1.3 updater offered 0.1.4, downloaded it, reported installed, and relaunched.
  The running `/Applications/ZLaunch.app` and About UI both confirm 0.1.4 (5). Its installed
  signature and Gatekeeper checks pass. The AI settings show the new command with a separate
  Record Hotkey control; the existing enabled AI provider selection is preserved.
- Official Tinycast's code-signature identity and hash are unchanged. The Dev test process
  was stopped and its generated app removed. Its saved preferences remain, with the temporary
  test shortcut removed and AI restored to its previous disabled state.
- Local logs, artifact paths and rollback ZIP are recorded in the ignored
  `build/releases/0.1.4/receipt.json`. No chat question or screenshot was sent to a provider.
