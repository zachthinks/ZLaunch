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
