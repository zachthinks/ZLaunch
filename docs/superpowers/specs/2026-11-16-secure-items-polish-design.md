# Secure Items keyboard, settings and polish

User approved tightening the locked screen, list and editor; adding timeout settings accessible from Actions; and fixing unlock shortcuts, authentication focus and editor Tab. No lock-on-dismiss setting (explicitly declined).

Keep the native feature and shared theme tokens. Keep values hidden, local Keychain storage and protected clipboard copying. Use the existing screen rather than a separate settings window: an inline settings view can return to the item list without changing activation. This avoids a second focus handoff. Timeout preferences use the existing AppSettings/settings.json machinery; secret data never enters it.

Defaults remain idle auto-lock 120 seconds and clipboard clearing 30 seconds. Offer finite practical presets. Show clear units and explain inactivity/clipboard ownership. Classify icons heuristically without changing stored item format. Focus Name on entry; Tab and Shift-Tab move between fields, Command-Return saves. Restore palette key status only when the same authentication operation still owns a visible Secure Items screen.

Tags: optional comma-separated tags stay inside the encrypted payload. Search matches names and tags, never values. Older items load with an empty tag list. Show compact chips on rows and preserve raw commas while editing.

Validation: regressions for authentication completion/cancellation and timing policy; signed guest keyboard flow with another app behind the palette; both themes/light and dark; full suite, lint and Debug build. Preserve user data and existing unrelated worktree edits.
