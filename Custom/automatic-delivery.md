# Stable delivery draft — not activated

These changes are an unpushed draft. The existing notification-only Codex monitor
has not been modified. No local publisher schedule or new credentials exist.

## Proposed path

1. The existing daily GitHub sync (13:17 UTC) selects only official stable
   Tinycast releases, merges into a candidate and increments ZLaunch's patch
   version. Conflicts abort safely and appear in the run summary. Beta tags and
   prereleases are rejected.
2. The existing reusable checks run against the exact candidate commit. A new
   promotion job requires success, verifies the original base still matches
   custom/main, and performs a normal fast-forward push. It never force-pushes.
   It records a commit status linking the candidate to this workflow run.
3. A future local scheduled publisher uses a separate clean checkout, the existing
   gh login, Developer ID identity FVY9AS28CU and ZLaunch-Local notary profile.
   `node Custom/publish-verified.mjs` only inspects eligibility. Actual publication
   additionally requires `--publish`, `ZLAUNCH_AUTOPUBLISH=1` and
   `NOTARY_PROFILE=ZLaunch-Local`. Do not enable these until validation completes.
4. Publication requires exact remote-main equality, the GitHub Actions promotion
   status, a completed successful sync run, stable metadata, the correct team and
   repository, an increasing custom version and no existing release or draft for
   that version. The existing publisher rechecks main, signs, notarizes, verifies,
   packages and creates the release. No signing material is uploaded to GitHub.
5. ZLaunch's existing updater offers the published update. Clicking its install
   action remains user-triggered. This automation neither replaces a running app
   nor copies production preferences into its checkout. Direct installs requested
   in a conversation retain the separately documented rollback workflow.

## Duplicate and failure handling

The local publisher must have one dedicated checkout and one scheduled owner.
Its Git-common-directory lock prevents concurrent invocations in that checkout;
an existing lock blocks rather than being reclaimed automatically. GitHub tag and
release uniqueness provide an additional guard across publishers. Existing drafts
also block; never overwrite a release or use upload clobber flags. Keep the manual
CI release workflow disabled in practice unless deliberately coordinating a move
to hosted signing. Do not create a second periodic publisher in another checkout.

A failed merge/check does not promote. A changed base blocks promotion and needs
a refreshed candidate. A failure recording status after promotion leaves local
publication blocked; a maintainer must rerun checks and restore provenance, never
invent a passing status. Failed signing/notarization never creates a public release.
Failed or interrupted publication requires inspection of the exact version/tag,
local lock and logs before retrying. No automatic deletion or rollback of remote
branches/tags/releases is allowed. Existing production remains untouched.

The existing monitor continues reporting new failed runs/releases. The future local
publisher should report a failed attempt once per commit and error identity, retain
its log locally, and stay quiet on an already published version. It requires this
Mac to be awake and the existing credentials usable. It is polling, not an upstream
release webhook. Do not claim instantaneous or unattended conflict resolution.

## Required validation and activation

Run publication-policy and workflow-policy fixtures, plus mocked end-to-end
promotion/publication checks covering failed checks, stale base, existing release,
remote movement, concurrent/stale locks, and failed notarization. Inspect the actual
GitHub check result on the finalized candidate. The ordinary Swift/runtime suite
and relevant UI behavior must also pass before releasing this stable integration.
Then separately activate one local schedule, preserving the notification monitor.

Repository secret-name listing currently returns no names. The zlaunch-release
environment secret endpoint returned 404, which does not establish an available
hosted signing setup. Local Developer ID identity is confirmed; ZLaunch-Local was
successfully used for build21 notarization. No credential values were inspected.
The proposed local path needs no new persistent credentials. Hosted publication
would instead require explicit approval to export/store the signing P12/password
and Apple notarization credentials; that route is not being configured.
