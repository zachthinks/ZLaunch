# Stable delivery and release approval

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

## Current delivery configuration

Verified against GitHub settings on November 2, 2026:

- `ZLAUNCH_HOSTED_RELEASE_ENABLED=true`: hosted publication is enabled.
- `ZLAUNCH_HOSTED_VALIDATION_ENABLED=false`: signing-only validation is disabled.
- `zlaunch-release` allows branch `custom/main` and requires reviewer `zachthinks`.
- Prevent self-review is off, so the owner can approve a manually dispatched run.

Successful candidate checks automatically permit promotion into `custom/main`;
publication still waits for environment approval. Approval is not permission to
install or restart the production app. A completed release becomes available
through the existing updater, whose Update button remains the user's action.

## Notifications and approval

The cloud scheduled task **ZLaunch update status** checks at 10 a.m. and 6 p.m.
America/New_York time, including daylight-saving changes. It continues in the
[same monitoring chat](https://chatgpt.com/c/6ae8d274-1c68-83ea-a052-1226ceaed213),
available through ChatGPT's Scheduled view. It does not require this Mac or the
desktop app to be running. Cloud task ID: `6ae8d27f64688191a8642fb7c2fcd5e3`.

Its instructions request alerts only for candidates needing human review, pending
release approvals, actionable merge/build/test/release blockages, new releases,
or persistent access failures. Alerts include direct GitHub links and the next
action, with deduplication by candidate/run/attempt/release identity. Unchanged,
healthy states should stay quiet. Notification delivery depends on the user's
ChatGPT notification settings; the migration did not change those preferences.

Migration was verified on November 2, 2026, using the actual task's Run now action.
The GitHub connector's general `fetch` action accepts repository REST API URLs,
including workflow-run collections and per-run `pending_deployments`. The prompt
specifies that route, pagination, a dedicated waiting-run query, active-run
inspection, and release/open-candidate checks. Do not substitute the PR-only
`fetch_commit_workflow_runs` action or mistake blocked web/shell access for a
connector failure. The first unsuccessful setup check missed the general fetch
capability; the corrected run retrieved current results successfully. It found
no waiting workflows or open sync candidates, with v0.1.14 unchanged and the
latest sync, checks, and release runs successful. This verifies current read
access, not delivery of a future approval notification or the installed app.

The former local heartbeat `zlaunch-update-status` is paused, with its prompt and
schedule retained for recovery. Do not enable both as the normal configuration.

For a waiting release, open the linked [ZLaunch release workflow](https://github.com/zachthinks/ZLaunch/actions/workflows/custom-release.yml)
run and approve the pending `zlaunch-release` deployment as `zachthinks` after
reviewing the checks and any required hands-on evidence. GitHub email and other
notification delivery depend on the account's notification settings; this
repository does not configure or verify those personal preferences.

For a merge conflict, the sync run records the upstream tag, commit, and affected
files in its log and summary. Promotion stops; the installed app and published
release are unchanged. Resolve the conflict while preserving custom features,
then run checks on the exact new candidate before promotion. A failed check or
release likewise needs inspection; the monitor does not resolve, merge, publish,
or install anything itself.

## Publisher ownership and recovery

Hosted GitHub publication is the configured delivery path. Do not enable or run
the former local publisher in parallel. Before changing ownership, disable and
drain the active publisher, inspect in-flight publication and unresolved locks,
and explicitly coordinate activation of the replacement. A local filesystem
lock and GitHub concurrency do not lock one another. Do not reclaim a stale lock
automatically or use a local publisher as an automatic fallback.

Keep reviewer `zachthinks` unless the user explicitly authorizes changing that
protection. Fully unattended publication requires separate approval to remove
the reviewer requirement. Keep signing-only validation disabled except for an
explicitly approved diagnostic run. No new release version should be created
merely to test signing; use the separate validation workflow for that purpose.
