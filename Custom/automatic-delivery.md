# Stable delivery and hosted cutover

Daily GitHub sync runs at 13:17 UTC. It selects official stable Tinycast releases,
merges into a candidate while preserving custom changes, and increments ZLaunch's
patch version only for a new upstream release. Conflicts abort and are reported;
drafts and prereleases are rejected. Exact-candidate reusable checks must pass
before a normal fast-forward promotion. A changed base blocks promotion. The
promotion records `zlaunch/stable-verified` with the successful sync run's URL.

## Hosted publication wiring

`custom-release.yml` listens for completion of `ZLaunch upstream sync` on
`custom/main`. GitHub's `workflow_run` event runs the downstream workflow from the
default branch; a push made using `GITHUB_TOKEN` alone is not the delivery trigger.
The source run must have completed successfully. The release preflight uses its
own exact main SHA, not the sync run's starting SHA, which predates promotion.
It requires the current commit's bot-created promotion status to name that exact
source run, then checks the source run's repository, workflow path, event and
successful terminal result. It verifies clean source, remote-main equality,
stable metadata, upstream ancestry, monotonic version and remote tag target.

Preflight checks the release list before requesting commit statuses or promotion
run details. An already complete release is an automatic no-op, including a
successful sync that reported “Already current” and skipped promotion. A draft or
incomplete release blocks for inspection even when there is no matching promotion.
For an unpublished version, no matching promotion is an automatic no-op; it does
not fetch unrelated run details. An explicit manual retry requires the full `expected_commit` input and valid
promotion evidence; it cannot bypass those checks or overwrite an existing release.

A completed custom feature update can use the same pipeline without waiting for
new upstream code: merge its reviewed, genuinely increasing stable version to
`custom/main`, then manually run `custom-sync.yml` with `verify_current_release=true`
and the exact full `expected_commit`. This path verifies an unused increasing
version, stable metadata, upstream ancestry and current-main equality, then runs
the same reusable checks and promotion job. It does not manufacture a version or
attestation. Scheduled runs retain the upstream-only selection path.

Full source checks run once for the exact final commit. Custom-update promotion
waits for and reuses successful push checks; upstream candidates without a push run
still run the full reusable check job. Reuse requires the same repository, SHA,
workflow, branch, run attempt, pinned checkout and successful full check step.
Failed or pending checks are never converted into a pass or hidden by a duplicate.
Secret-free release preflight runs on Linux and verifies the successful promotion
instead of repeating tests, lint and Debug compilation. Only an
eligible successful preflight may enter `zlaunch-release`. After its required
reviewer approves, fresh main/provenance/release checks repeat before importing
signing secrets. Preflight retains `contents: read`; only the protected release job has
`contents: write`. Both verifier invocations use the existing temporary
`github.token` as `GH_TOKEN` for GitHub API reads; no token permissions are added. The repository and read
endpoints remain public. The client sends the token only to the fixed GitHub API
origin and refuses redirects. It retries transport failures, transient server
errors and short rate limits at most three times, with a 20-second request timeout
and at most 10 seconds between attempts. Longer rate-limit delays stop for later
inspection rather than repeatedly hitting the API. Diagnostics name the endpoint,
HTTP status, authentication mode, rate-limit headers and GitHub request ID without
printing tokens or response bodies. API, authentication and malformed-response
errors fail closed in both preflight and the protected verifier; they never become
an eligibility skip. A permission denial is reported, never resolved by silently
broadening permissions or dropping authentication.
The existing four environment secrets and temporary keychain are used. The app is
signed, notarized, stapled and checked by Gatekeeper; stapling validation is also
explicit. DMG, signature-preserving ZIP and SHA256SUMS become GitHub release assets.
No Actions artifacts or caches are uploaded. Temporary signing material cleanup
runs on success and failure and fails the job if cleanup fails.

All hosted release and signing-validation invocations share `zlaunch-release`
concurrency with cancellation disabled. The publisher also keeps its Git-directory
lock and repeats current-main/release-state checks immediately before creating a
release. It never edits an existing release or force-updates a tag. A failed or
interrupted attempt requires inspection of the existing release, tag and Apple
submission before retrying; a timeout does not cancel Apple's remote submission.

## Activation remains a separate decision

Signing-only validation succeeded on commit `3703f0e40a3851242e052ba710bbb2864944cad5`
in run https://github.com/zachthinks/ZLaunch/actions/runs/38679039596.
This is signing evidence, not a hosted publication. Validation is off again.
Hosted release remains absent/disabled. The hourly local automation **Publish
verified ZLaunch updates** remains enabled until an approved coordinated cutover.

1. Review and merge the wiring with CI passing on the final commit; do not change
   marketing versions merely to test publication.
2. Approve pausing local automation `6acdd873bc7c819181f245984c88ef82`. Confirm its
   publisher task is idle and its dedicated checkout has no in-flight publication
   or unresolved lock. A local filesystem lock and GitHub concurrency do not lock
   one another. Do not reclaim a stale lock automatically.
3. Separately approve `ZLAUNCH_HOSTED_RELEASE_ENABLED=true`. Keep validation false,
   the branch restriction `custom/main`, and the existing reviewer unless the user
   explicitly approves changing that security setting. Keep one publisher owner.
4. Retaining reviewer `zachthinks` permits release approval from GitHub on any
   device; compilation/publication no longer needs the Mac. Fully unattended
   publication additionally requires explicit approval to remove that reviewer
   gate. It is not part of merging the trigger code or enabling the release flag.
5. Prepare a legitimate unused stable version. The completed/tested Window
   Layouts feature update is approved as the first hosted release; its actual
   release commit can use the explicit custom-update path above. At preparation
   time it is unfinished, upstream remains `v0.11.19`, and current `0.1.9` is
   published. `0.1.10` is the next unused numerical version, subject to fresh
   release/tag checks. Never republish `0.1.9` or bump for a test.
6. Verify the first hosted release's exact source, Apple acceptance, stapling,
   Gatekeeper, assets/checksums and updater offer. Installation remains the user's
   updater-button action; this automation never installs or restarts production.

The separate notification monitor remains unchanged. If hosted delivery is
blocked, preserve the published release and report the specific blocker. Rollback
of publisher ownership requires disabling and draining hosted publication before
re-enabling the sole local owner; do not run both publishers as a fallback.
