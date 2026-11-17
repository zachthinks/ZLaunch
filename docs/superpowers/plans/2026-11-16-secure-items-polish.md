# Secure Items Polish Implementation Plan

**Goal:** Fix keyboard focus and navigation, expose two timeout preferences, and polish the approved surfaces.
**Architecture:** Keep feature UI and logic in SecureItems. Use AppSettings for nonsecret timeout preferences and narrowly scoped palette focus restoration.
**Tech Stack:** Swift 6, SwiftUI, AppKit, LocalAuthentication, Security.
**Spec:** docs/superpowers/specs/2026-11-16-secure-items-polish-design.md

- [x] Reproduce and pin authentication focus, advertised unlock chord, and editor Tab failures.
- [x] Restore focus after current authentication; handle Unlock Command-Return and field navigation.
- [x] Add validated timeout preferences, schema bindings, settings UI and timer integration.
- [x] Polish locked state, list/empty state, editor and feedback using shared tokens; translate new text.
- [x] Add encrypted tags, backward-compatible decoding, and name/tag search.
- [ ] Run focused then full guest checks and signed UI flow without automation forcibly refocusing the palette.
- [ ] Record evidence and deliver the verified correction through the established update route.

Review focus: cancelled/late authentication must not steal focus; Tab must preserve draft; clipboard expiry must not erase replacement clipboard; settings must survive restart with safe invalid-value defaults; appearance must remain legible in Classic and Glass.
