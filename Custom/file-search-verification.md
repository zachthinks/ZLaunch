# File search improvements — 0.1.12

Useful Files is the default and includes documents, media, folders, source files
and project configuration. Everything restores unknown types and generated file
types while retaining the existing scope, hidden-path and explicit-ignore rules.
The selected filter persists across reopening, relaunch, settings-file mirroring
and backup. Exact names rank ahead of prefixes, with everyday folders breaking
otherwise equal ties. Result actions can exclude a folder's contents or extension;
remove the resulting ignore rule in File Search settings to undo it.

## Validation

The original change passed all 95 Swift harnesses, unsigned Debug compilation
without new compiler warnings, lint and model-layer import checks in an isolated
macOS QA guest. Interactive checks observed Useful Files showing synthetic text
and Swift source while hiding object/unknown files, Everything showing all four,
immediate extension exclusion and persisted filter selection after relaunch.
Dev preferences were restored after testing.

The release integrates the current 0.1.11 base so existing layout improvements
are retained. The exact final release commit must pass Custom/check.sh through
the established hosted verification and release preflight before publication.
Private VM diagnostics and machine-specific evidence remain local.
