# GitHub-hosted signing and publication setup

Prepared against ZLaunch 0.1.9 at 8b47f73852132814356593bc2e6759bac024c1dd.
This setup does not change app behavior, versions, schedules, or the updater.

## Approve the environment settings before changing them

Open https://github.com/zachthinks/ZLaunch/settings/environments while signed in.
Create or inspect `zlaunch-release`. Its existence and current protections must
be verified through authenticated settings; the public page is not evidence.

Proposed settings for explicit owner approval:
- Selected deployment branches: branch `custom/main` only; no tag rules.
- Required reviewer: `zachthinks` for a deliberate manual release approval.
- For a sole maintainer who also dispatches runs, leave Prevent self-review off.
  If independent approval is wanted, choose another trusted reviewer and enable it.
  Never choose or change this silently.
- Disable administrator bypass of protection rules.
- Store the four values below as environment secrets, not source files.
- Keep repository variable `ZLAUNCH_HOSTED_RELEASE_ENABLED` absent or `false`
  until the switch is approved. Repository variable settings:
  https://github.com/zachthinks/ZLaunch/settings/variables/actions

GitHub documents these controls at
https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments .

## User-only credential handoff

The user personally exports and transmits credentials. Do not give private keys,
P12 contents, passwords or Apple tokens to an assistant or put them in chat,
screenshots, PRs, logs, the repository, or clipboard history.

Public identity: `Developer ID Application: Zachary Linquist (FVY9AS28CU)`.
Team: `FVY9AS28CU`. Bundle: `com.zachthinks.zlaunch`.

| Environment secret | User supplies |
| --- | --- |
| ZLAUNCH_SIGNING_P12_BASE64 | Base64 of a password-encrypted P12 containing this existing Developer ID certificate and its private key |
| ZLAUNCH_SIGNING_P12_PASSWORD | The export password chosen for that P12 |
| ZLAUNCH_APPLE_ID | Apple Account email with access to the stated developer team; do not infer it from GitHub email |
| ZLAUNCH_APP_PASSWORD | Existing valid notarization app-specific password if personally available, otherwise a separately approved new app-specific password; never the primary Apple password |

Use Keychain Access > My Certificates to select the existing Developer ID identity
and export its certificate/private-key pair as a password-protected P12, outside
the repository and synced/shared folders. This is a user action. Do not export a
different Apple Development/Apple Distribution identity or create a new certificate.

After the environment/protection setup is approved, the user can send the file
directly from their own Terminal to the authenticated GitHub CLI, without printing
or placing its content on the clipboard. Substitute only the local file path:

```sh
base64 -i "/private/path/ZLaunch.p12" | gh secret set ZLAUNCH_SIGNING_P12_BASE64 --env zlaunch-release --repo zachthinks/ZLaunch
gh secret set ZLAUNCH_SIGNING_P12_PASSWORD --env zlaunch-release --repo zachthinks/ZLaunch
gh secret set ZLAUNCH_APPLE_ID --env zlaunch-release --repo zachthinks/ZLaunch
gh secret set ZLAUNCH_APP_PASSWORD --env zlaunch-release --repo zachthinks/ZLaunch
```

The last three commands prompt for values. Do not add values to command arguments
or share the terminal session while entering them. Only share completion status.
Base64 is encoding, not encryption; GitHub CLI encrypts submitted secrets.
Retain/recoverably dispose of the export yourself according to your credential policy.

Official references:
- https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications
- https://cli.github.com/manual/gh_secret_set
- https://developer.apple.com/documentation/security/customizing-the-notarization-workflow
- https://support.apple.com/en-us/102654

No new PAT, SSH key, provisioning profile or saved runner-keychain password is
required by this workflow. The runner generates its temporary keychain password.

## Signing-only validation (disabled until separately approved)

The manual workflow is `.github/workflows/custom-signing-validation.yml`.
It requires the separate repository variable `ZLAUNCH_HOSTED_VALIDATION_ENABLED`
to equal `true`, an explicit confirmation input, and the full reviewed commit
SHA in `expected_commit`. Keep `ZLAUNCH_HOSTED_RELEASE_ENABLED` absent or false.

Review and merge the amended setup before any validation dispatch. At action
time, separately approve enabling the validation flag and running the reviewed
commit from `custom/main`. Both jobs require that the dispatch SHA matches the
input and the current main commit. If main advances, stop and review the new
commit; do not silently substitute it. The signing job also requires the existing
`zlaunch-release` environment approval after secret-free checks pass.

The validation workflow has only `contents: read` permission. It builds the real
Release app in temporary runner storage with the current marketing version and
without overriding the project's build number. It checks bundle/helper identities,
the Developer ID team and signatures, sends a temporary ZIP to Apple's notary
service, requires Accepted status, staples and validates the ticket, and asks
Gatekeeper to assess the app. It does not run the publisher, create a tag/release,
upload an Actions artifact, or install or launch the app on the user's Mac. Xcode
26.6 still invoked Launch Services registration on the disposable runner during
validation despite the requested disabling build setting. It can validate 0.1.9 without changing its published assets.

This is a real upload to Apple, not a simulation. An Apple submission may remain
in progress after the runner's timeout; a timeout is not success or cancellation
of that server-side submission. The job summary preserves only the validated
Apple submission UUID and an allowlisted status before temporary output cleanup,
on success or failure. If no usable status was returned, it records Unavailable.
Use that ID to inspect its status before authorizing a retry.
The runner deletes the temporary P12, keychain and build, and cleanup errors fail
the job. Runner termination can still interrupt cleanup; no absolute erasure
guarantee is made. Do not print credential values or entire private keychain data.

After the approved run, return the validation flag to false and retain the
nonsecret workflow result. A successful validation proves signing/notarization,
not GitHub publication, updater installation, or user-facing app behavior.
The existing local publisher remains unchanged during this nonpublishing test.

## Publication and controlled switch

Hosted publication entry point (disabled until coordinated cutover):
https://github.com/zachthinks/ZLaunch/actions/workflows/custom-release.yml

The workflow accepts a successful completed stable-sync run on custom/main, or a
manual dispatch naming the exact promoted commit, only with the explicit enable
variable. Both require bot-created exact-commit promotion evidence linked to a
completed successful sync run. See [stable delivery](automatic-delivery.md) for
trigger verification and the coordinated activation sequence. A separate job tests the
exact dispatch commit without release secrets. The signing job waits for success
and the protected environment's approval, then rejects a changed main or any
existing version (including drafts), non-increasing stable version, or conflicting
remote tag before importing secrets. It uses a pinned
checkout action and an ephemeral keychain for signing and notarization, with
cleanup on failure too. PR code never receives these signing secrets.

A first real hosted publication requires an approved, unused release version.
The completed Window Layouts update is approved for this purpose; finalize its
source and real stable version before invoking the custom-update promotion path. Do not republish 0.1.9 or bump a version merely to test this setup.
The release workflow rejects an already-published version; use the separate
signing-only workflow above for credential validation. A successful real run must verify signed bundle
identity/team, notarization/stapling, assets and checksum agreement.

Keep the current parent-owned publisher schedule unchanged while preparing.
At switch time the parent coordinates a pause of that publisher and confirms no
publication is in flight before enabling hosted publication. A local lock and
GitHub concurrency do not synchronize two different publishers. Keep the required
reviewer gate unless Zach separately approves unattended publication. Merging the
automatic trigger does not activate it while the release flag is disabled.
After a successful release, verify the existing updater; do not replace it.

The publisher repeats the shared release-state check immediately before creating
a release, including draft existence, monotonic stable version and remote tag
target. This reduces races but is not an atomic lock across independent publishers;
the coordinated cutover remains required. It never edits an existing release or
force-updates a tag.

Hosted publication uses `github.run_number` as its build number. That number is
local to this workflow and is not globally monotonic across the local and hosted
publishers. The updater compares marketing versions; the shared release-state
guard requires those to increase. Do not describe the build number as a global
release sequence.
