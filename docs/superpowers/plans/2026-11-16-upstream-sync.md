# Upstream v0.12.15 Integration Plan

**Goal:** Resolve the stable upstream merge while preserving all ZLaunch customizations.
**Architecture:** Keep shared launcher behavior, theme-specific surfaces, and ZLaunch identity.
**Spec:** User request to integrate upstream and validate in the disposable QA VM.

## Constraints

- Recovery source: b58074a46610768e6a07a8afe2ac8b92b0ae1c38.
- No production installation, publication, credential or official app changes.
- All builds, tests and UI checks run in the owned QA VM.

## Tasks

- [x] Inspect and resolve text conflicts, preserve renamed harness coverage and translations.
- [x] Audit automatically merged identity, migration, Store, LaunchDeck and theme code.
- [x] Regenerate the project in the guest, run harnesses, lint, Debug build and fork checks.
- [x] Exercise compact shortcuts and launcher navigation in both themes in the guest.
- [x] Record results and end the owned session.

## Review focus

Classic must avoid glass masks; Glass must retain the upstream shadow fix.
Upstream migration must reject ZLaunch IDs; Dev and stable must remain isolated.
Renamed tests must retain custom layout, Store and AI capture coverage.
Generated project must preserve fork assets and helper identities.
New upstream commands must use shared navigation in both themes.
