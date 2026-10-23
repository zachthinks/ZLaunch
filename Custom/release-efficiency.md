# Testing and release efficiency

## One full check for the final commit

Push and PR checks remain automatic. During development, use focused tests and
interactive checks in the configured guest. Before shipping a custom update,
bring forward current main, finalize the source and version, and push once.
Dispatch custom-sync.yml with verify_current_release=true and the full reviewed
commit. Its reusable checks wait for the matching push verification instead of
starting a second macOS suite. The full suite, lint, model purity, project
consistency, unsigned Debug build and bundle checks remain in Custom/check.sh.

Reuse verifies repository and head repository, exact SHA, custom/main branch,
push event, custom-checks.yml path, successful latest run and attempt, successful
verify job, pinned checkout identity and the actual full check step. A rerun
starting during inspection invalidates the old attempt. Failed/skipped checks
stop promotion. Waiting is bounded at 20 minutes. If no push run appears within
60 seconds, the reusable workflow runs the full checks itself; upstream candidate
branches continue using that path directly. API errors fail closed.

Release preflight now verifies existing successful promotion on a standard Linux
runner. It does not install Xcode tools or repeat the Swift suite/Debug build.
The protected macOS job still rechecks current main, provenance, version/tag and
release state before loading secrets. It builds the signed Release app, notarizes
it, staples and verifies it, packages and publishes, then cleans signing material.
Reviewer approval, secret isolation and the no-overwrite rules are unchanged.
No Actions artifacts, persistent caches or additional publisher were introduced.

## Reuse evidence deliberately

- Use targeted guest tests while changing a feature. Do not add a fresh guest full
  suite merely because the final hosted suite is about to run. A full guest run is
  useful when it resolves a failure or guest-specific uncertainty.
- Record the source revision/digest, relevant toolchain, check result and observed
  UI behavior. Reuse evidence only when the inputs that affect it are unchanged.
  A changed app source, integration base, test definition or relevant environment
  can invalidate that evidence. Never treat a test launch as a passing result.
- A version-only edit does not justify replaying the entire interactive feature
  sweep. Verify the final artifact's identity/signature and perform one focused
  installed-app smoke check after updating, with a consistent rollback checkpoint.
- One failed unchanged test warrants inspection. An explicit rerun can confirm an
  intermittent failure; do not add automatic test retries or keep rerunning until
  green. Preserve failures and fix recurring defects.
- Use one bounded CLI workflow watcher. Avoid repeated log downloads, parallel
  watches of the same job, redundant status calls and large UI-tree dumps. Polling
  belongs in deterministic code rather than repeated model-driven calls.

## Measured opportunity

### Next real release timing

Keep the separate Linux eligibility gate. On the next actual release, use existing
GitHub run/job/step timestamps and publication logs to record a concise timing
receipt alongside that release's validation evidence. Do not launch a release,
extra build, test suite, or monitoring job just to collect these measurements.

- Record the exact commit, release version, workflow run IDs and attempts.
- Separate full source checks, check-reuse waiting, promotion, Linux preflight,
  Mac checkout/setup, signed Release compilation, signing, Apple notarization,
  stapling/verification, packaging/upload and final publication where logs permit.
- Distinguish active execution from dependency waiting, reviewer approval and
  runner queue/startup. Mark timing that cannot be separated as unknown rather
  than attributing it to Linux, macOS or GitHub queues without evidence.
- Report end-to-end elapsed time and the critical path separately from summed
  runner time; overlapping jobs are not additive wall-clock savings. Confirm that
  the full source checks executed once for the final commit.
- Standard hosted runners are free for this public repository under the current
  policy; verify billing policy if discussing monetary savings. Do not infer cost
  savings merely from using Linux.
- Identify the largest actionable delay and recommend a change only if the
  expected benefit warrants its complexity. One release is an initial observation,
  not proof of typical queue times. Preserve approval and signing safeguards.

Retrieve completed metadata/logs once after publication, using the normal bounded
watcher during the release. Use existing log timestamps; add instrumentation only
if a meaningful bottleneck cannot otherwise be resolved. Carry these instructions
with the next source push rather than creating an extra CI run for timing docs.

The 0.1.12 promotion checks ran from 00:14:43 to approximately 00:22 UTC; release
preflight ran from 00:22:29 to approximately 00:28 UTC. Push checks also ran the
same suite and Debug build, including an explicit retry after a streamed-command
assertion failure. The guest full suite separately took 76 seconds.

The new design removes two normal duplicate hosted full-check jobs for a custom
release and avoids an unnecessary guest full rerun. It does not remove the signed
Release build or Apple's processing time. Actual elapsed savings depend on queue
and toolchain timing; validate the reuse path in CI before calling them measured.
