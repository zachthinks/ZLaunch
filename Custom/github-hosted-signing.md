# GitHub-hosted signing setup (not activated)

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

## Validation and controlled switch

The initial hosted release remains manual:
https://github.com/zachthinks/ZLaunch/actions/workflows/custom-release.yml

The hardened workflow accepts only a manual dispatch from custom/main in this
repository and only with the explicit enable variable. A separate job tests the
exact dispatch commit without release secrets. The signing job waits for success
and the protected environment's approval, then rejects a changed main or any
existing version (including drafts) before importing secrets. It uses a pinned
checkout action and an ephemeral keychain for signing and notarization, with
cleanup on failure too. PR code never receives these signing secrets.

A first real hosted publication requires a separately approved, unused release
version. Do not republish 0.1.9 or bump a version merely to test this setup.
An already-published-version run can validate the guard but cannot validate the
certificate or notarization. A successful real run must verify signed bundle
identity/team, notarization/stapling, assets and checksum agreement.

Keep the current parent-owned publisher schedule unchanged while preparing.
At switch time the parent coordinates a pause of that publisher and confirms no
publication is in flight before enabling hosted publication. A local lock and
GitHub concurrency do not synchronize two different publishers. Keep the required
reviewer gate. Do not enable an automatic hosted trigger in this initial setup.
After a successful release, verify the existing updater; do not replace it.
